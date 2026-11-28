-- مصفوفة الرؤية (P2.5/P2.8، migration 20261128180000), on a scratch database:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/view_rpcs_scaffold.sql
--   psql < supabase/sql/tests/visibility_matrix_scaffold.sql
--   psql < supabase/migrations/20261001130000_family_shares_by_consent.sql
--   psql < supabase/migrations/20261127140000_view_rpcs.sql
--   psql < supabase/migrations/20261127150000_view_family_meds.sql
--   psql < supabase/migrations/20261128180000_visibility_matrix.sql
--   psql < supabase/sql/tests/visibility_matrix_test.sql
--
-- Raises on the first failed check; each passing one prints "ok:".

\set ON_ERROR_STOP on
do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

\set QUIET 1
create or replace function pg_temp.check(cond boolean, label text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAIL: %', label; end if; raise notice 'ok: %', label; end $$;
create or replace function pg_temp.who(p uuid) returns void language plpgsql as $$
begin reset role; perform set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, false); set role authenticated; end $$;
grant execute on function pg_temp.who(uuid) to authenticated;
grant execute on function pg_temp.check(boolean, text) to authenticated;
\set a '''00000000-0000-0000-0000-0000000000a1'''
\set b '''00000000-0000-0000-0000-0000000000b1'''
\set c '''00000000-0000-0000-0000-0000000000c1'''
\set k '''00000000-0000-0000-0000-0000000000d1'''
\set o '''00000000-0000-0000-0000-0000000000e1'''
\set fam '''00000000-0000-0000-0000-0000000000f1'''
\set fam2 '''00000000-0000-0000-0000-0000000000f2'''
\set ma '''00000000-0000-0000-0000-00000000aa01'''
\set mb '''00000000-0000-0000-0000-00000000bb01'''
\set mk '''00000000-0000-0000-0000-00000000dd01'''
\set fmk '''00000000-0000-0000-0000-00000000ee01'''
\set fmb '''00000000-0000-0000-0000-00000000ee02'''

-- a = parent/admin. b, c = adults. k = a child account. o = in another family.
insert into auth.users values (:a), (:b), (:c), (:k), (:o);
insert into public.family_groups (id) values (:fam), (:fam2);
insert into public.family_members (id, family_id, user_id, role) values
  (gen_random_uuid(), :fam, :a, 'admin'), (:fmb, :fam, :b, 'member'), (gen_random_uuid(), :fam, :c, 'member'), (:fmk, :fam, :k, 'child'),
  (gen_random_uuid(), :fam2, :o, 'admin');
insert into public.zad_household_members (id, user_id, display_name, kind) values (:ma, :a, 'أنا', 'self'), (:mb, :b, 'ب', 'self'), (:mk, :k, 'سلمى', 'self');
insert into public.zad_users (id, monthly_limit) values (:a, 5000), (:b, 3000), (:c, 1000), (:k, 50), (:o, 777);
insert into public.zad_transactions (user_id, amount, txn_kind) values (:a, 9000, 'income'), (:k, 40, 'expense'), (:k, 100, 'income');
insert into public.zad_debts (user_id, remaining_balance) values (:k, 10), (:a, 20);
insert into public.zad_obligations (user_id, amount) values (:k, 5), (:a, 6);
insert into public.zad_pharmacy_items (user_id, name, remaining_quantity, is_private) values
  (:a, 'بنادول', 10, false), (:b, 'ضغط', 5, false), (:b, 'خاص', 3, true), (:k, 'فيتامين', 4, false), (:o, 'غريب', 2, false);
insert into public.zad_pharmacy_doses (user_id, item_id, status, scheduled_at)
  select user_id, id, 'missed', now() from public.zad_pharmacy_items where name = 'فيتامين';
insert into public.agent_goals (user_id, title, status) values (:a, 'هدف الأب', 'active'), (:b, 'هدف ب', 'active'), (:k, 'هدف سلمى', 'active');
insert into public.agent_tasks (user_id, task_description) values (:a, 'مهمة الأب'), (:b, 'مهمة ب'), (:k, 'مهمة سلمى');
insert into public.family_chores (family_id, assigned_to, title) values (:fam, :fmk, 'ترتيب أوضتي'), (:fam, :fmb, 'مهمة ب في البيت');
insert into public.zad_inventory (user_id, item_name, quantity, family_id) values (:a, 'لبن', 1, :fam), (:b, 'رز', 3, :fam);
\set QUIET 0

-- ── ١. الطفل (حساب): مهامه وأهدافه بس. صفر ميزانية، صفر صيدلية، RLS والـRPC ──
select pg_temp.who(:k);
select pg_temp.check((select count(*) from public.zad_transactions) = 0, 'child: own transactions are invisible (RLS)');
select pg_temp.check((select count(*) from public.zad_debts) = 0, 'child: own debts invisible');
select pg_temp.check((select count(*) from public.zad_obligations) = 0, 'child: a second budget table is invisible too');
select pg_temp.check((select count(*) from public.zad_pharmacy_items) = 0, 'child: own medicines invisible');
select pg_temp.check((select count(*) from public.zad_pharmacy_doses) = 0, 'child: own doses invisible');
select pg_temp.check(coalesce((public.zad_budget_state(:k) ->> 'spent')::numeric, 0) = 0, 'child: zad_budget_state sees no rows, so no numbers');
select pg_temp.check(public.zad_view_money() ->> 'reason' = 'minor_no_budget' and (public.zad_view_money() ->> 'ok')::boolean = false, 'child: zad_view_money refuses');
select pg_temp.check(public.zad_view_house() -> 'numbers' -> 'medicines_active' -> 'value' = 'null'::jsonb, 'child: zad_view_house hides the medicine count (null, not 0)');
select pg_temp.check(not (public.zad_view_home() -> 'numbers' ? 'available') and not (public.zad_view_home() -> 'numbers' ? 'medicines_active'), 'child: zad_view_home has no budget number');
select pg_temp.check((public.zad_view_home() -> 'numbers' -> 'goals_active' ->> 'value')::int = 1 and (public.zad_view_home() -> 'numbers' -> 'chores_open' ->> 'value')::int = 1, 'child: home shows own goal and own chore');
select pg_temp.check(public.zad_view_family(:mb) ->> 'reason' = 'minor_no_access', 'child: cannot open another member via zad_view_family');
select pg_temp.check((public.zad_view_family(:mk) -> 'numbers' ? 'goals_active') and not (public.zad_view_family(:mk) -> 'numbers' ? 'medicines_active'), 'child: own family view = goals only');
select pg_temp.check((select count(*) from public.agent_goals) = 1 and (select count(*) from public.agent_tasks) = 1, 'child: sees only own goals and tasks');
select pg_temp.check((select count(*) from public.family_chores) = 1, 'child: sees only the chores assigned to them');
select pg_temp.check(public.zad_view_family_home() ->> 'relation' = 'minor' and not (public.zad_view_family_home() -> 'numbers' ? 'budget_total'), 'child: family home has no budget total');
do $$ begin
  begin
    insert into public.zad_pharmacy_items (user_id, name) values ('00000000-0000-0000-0000-0000000000d1', 'مش مسموح');
    raise exception 'FAIL: child inserted a medicine';
  exception when insufficient_privilege then null; end;
  raise notice 'ok: child cannot write the pharmacy table';
end $$;

-- ── ٢. ولي الأمر: مهام وأهداف الطفل ──
select pg_temp.who(:a);
select pg_temp.check((select count(*) from public.agent_goals where user_id = :k) = 1, 'guardian: sees the child''s goals');
select pg_temp.check((select count(*) from public.agent_tasks where user_id = :k) = 1, 'guardian: sees the child''s tasks');
select pg_temp.check((select count(*) from public.agent_goals where user_id = :b) = 0 and (select count(*) from public.agent_tasks where user_id = :b) = 0, 'guardian: does not see an adult''s goals or tasks without consent');
select pg_temp.check((select count(*) from public.zad_pharmacy_items where user_id = :k) = 0, 'guardian: child medicines still need the (auto) consent');

-- ── ٣. بالغ ← بالغ: تفاصيل بالموافقة، الصيدلية مفتوحة إلا الخاص ──
select pg_temp.who(:c);
select pg_temp.check((select count(*) from public.agent_goals where user_id = :b) = 0, 'adult: another adult''s goals are hidden without consent');
select pg_temp.check((select count(*) from public.agent_tasks where user_id = :b) = 0, 'adult: another adult''s tasks are hidden without consent');
select pg_temp.check((select count(*) from public.zad_transactions where user_id = :a) = 0, 'adult: another adult''s spending is hidden');
select pg_temp.check((select array_agg(name order by name) from public.zad_pharmacy_items where user_id = :b) = array['ضغط'], 'adult: sees the open medicine, not the private one');
select pg_temp.check((select count(*) from public.zad_pharmacy_items where user_id = :k) = 0, 'adult: cannot read a child''s medicines without consent');
select pg_temp.check((select count(*) from public.zad_pharmacy_items where user_id = :o) = 0, 'adult: nothing from another family');
select pg_temp.check((public.zad_view_family(:mb) -> 'numbers' -> 'medicines_active' ->> 'value')::int = 1, 'adult: zad_view_family counts only the open medicine');
select pg_temp.check(public.zad_view_family(:mb) -> 'numbers' ? 'spent_30d' = false, 'adult: zad_view_family gives no spending without consent');
select pg_temp.check((public.zad_view_family_home() -> 'numbers' -> 'budget_total' ->> 'value')::numeric = 9000 and (public.zad_view_family_home() -> 'numbers' -> 'budget_total' ->> 'adults')::int = 3, 'adult: family budget total counts adults only (not the child)');
select pg_temp.check((public.zad_view_family_home() -> 'numbers' -> 'inventory_items' ->> 'value')::int = 2, 'adult: shared inventory is the family''s');

-- outsider
select pg_temp.who(:o);
select pg_temp.check((select count(*) from public.zad_pharmacy_items where user_id in (:a, :b, :k)) = 0, 'outsider: sees no medicine of another family');
select pg_temp.check(public.zad_view_family(:mb) ->> 'reason' = 'consent_required', 'outsider: zad_view_family refuses');

-- explicit consent opens the details (and the private medicines) for that viewer only
reset role;
insert into public.zad_family_shares (family_id, owner_id, viewer_id, scope, status, decided_at) values
  (:fam, :b, :c, 'medicines', 'granted', now()), (:fam, :b, :c, 'tasks', 'granted', now()), (:fam, :b, :c, 'spending', 'granted', now()),
  (:fam, :k, :a, 'medicines', 'granted', now());
select pg_temp.who(:c);
select pg_temp.check((select count(*) from public.zad_pharmacy_items where user_id = :b) = 2, 'consent: explicit medicines share shows the private one too');
select pg_temp.check((select count(*) from public.agent_goals where user_id = :b) = 1 and (select count(*) from public.agent_tasks where user_id = :b) = 1, 'consent: tasks share shows goals and tasks');
select pg_temp.check((public.zad_view_family(:mb) -> 'numbers' -> 'medicines_active' ->> 'value')::int = 2, 'consent: view counts all medicines');
select pg_temp.who(:a);
select pg_temp.check((select count(*) from public.zad_pharmacy_items where user_id = :k) = 1, 'guardian: child medicines visible once the (auto) share exists');

-- ── ٤. الباب الوحيد: القاصر مايكتبش صيدلية، is_private من الباب ──
reset role;
select pg_temp.check(public.zad_intent_pharmacy(:k, 'pharmacy.added', '{"name":"دوا قاصر"}'::jsonb, now()) ->> 'reason' = 'member_not_granted', 'door: a minor cannot add a medicine');
select pg_temp.check((public.zad_intent_pharmacy(:c, 'pharmacy.added', '{"name":"دوا خاص","is_private":true}'::jsonb, now()) ->> 'ok')::boolean, 'door: add with is_private = true is accepted');
select pg_temp.check((select is_private from public.zad_pharmacy_items where user_id = :c and name = 'دوا خاص') is true
  and not (select is_private from public.zad_pharmacy_items where name = 'بنادول'), 'door: the flag is stored, and a row added without it is open');
select pg_temp.check((public.zad_intent_pharmacy(:c, 'pharmacy.updated',
  jsonb_build_object('item_id', (select id from public.zad_pharmacy_items where name = 'دوا خاص'), 'patch', '{"is_private":false}'::jsonb), now()) ->> 'ok')::boolean, 'door: patch.is_private is accepted');
select pg_temp.check(not (select is_private from public.zad_pharmacy_items where name = 'دوا خاص'), 'door: patch.is_private flipped it');
select pg_temp.check(public.zad_intent_pharmacy(:c, 'pharmacy.updated',
  jsonb_build_object('item_id', (select id from public.zad_pharmacy_items where name = 'دوا خاص'), 'patch', '{"is_private":"yes"}'::jsonb), now()) ->> 'reason' = 'bad_payload', 'door: is_private must be a boolean');
select pg_temp.check(public.zad_intent_pharmacy(:c, 'pharmacy.updated',
  jsonb_build_object('item_id', (select id from public.zad_pharmacy_items where name = 'دوا خاص'), 'patch', '{"name":"x"}'::jsonb), now()) ->> 'reason' = 'patch_field_unknown', 'door: other fields still refused');
select pg_temp.check(not public.zad_is_minor_user(:a) and public.zad_is_minor_user(:k) and not public.zad_is_minor_user(null), 'minor helper');

-- the client roles cannot call the internal helper or the door pieces
select pg_temp.who(:k);
do $$ begin
  begin perform public.zad_is_minor_user('00000000-0000-0000-0000-0000000000a1'); raise exception 'FAIL: client called zad_is_minor_user';
  exception when insufficient_privilege then null; end;
  begin perform public.zad_intent_pharmacy_can_write('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000d1'); raise exception 'FAIL: client called the door piece';
  exception when insufficient_privilege then null; end;
  raise notice 'ok: internal helpers are not callable by clients';
end $$;
reset role;
\echo visibility_matrix: all checks passed
