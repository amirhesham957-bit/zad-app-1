-- دوال العرض zad_view_* (migration 20261127140000), on a scratch database:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/view_rpcs_scaffold.sql
--   psql < supabase/migrations/20261001130000_family_shares_by_consent.sql
--   psql < supabase/migrations/20261127140000_view_rpcs.sql
--   psql < supabase/migrations/20261127150000_view_family_meds.sql
--   psql < supabase/sql/tests/view_rpcs_test.sql
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
\set fam '''00000000-0000-0000-0000-0000000000f1'''
\set ma '''00000000-0000-0000-0000-00000000aa01'''
\set mkid '''00000000-0000-0000-0000-00000000aa02'''
\set mb '''00000000-0000-0000-0000-00000000bb01'''
\set mnolink '''00000000-0000-0000-0000-00000000aa03'''

insert into auth.users values (:a), (:b), (:c);
insert into public.family_groups (id) values (:fam);
insert into public.family_members (family_id, user_id, role) values (:fam, :a, 'admin'), (:fam, :b, 'member'), (:fam, :c, 'member');
-- a = the guardian (owns a child, an adult without an account, and herself). b = an adult with an account. c = outsider to the share.
insert into public.zad_household_members (id, user_id, display_name, kind, linked_user_id) values
  (:ma, :a, 'أنا', 'self', null), (:mkid, :a, 'سلمى', 'child', null), (:mnolink, :a, 'جدو', 'elder', null),
  (:mb, :b, 'بابا', 'self', null);
insert into public.zad_transactions (user_id, amount, txn_kind, category) values
  (:a, 5000, 'income', null), (:a, 1200.5, 'expense', 'أكل'), (:a, 300, 'expense', 'مواصلات'),
  (:b, 900, 'expense', 'أكل'), (:b, 100, 'income', null);
insert into public.zad_debts (user_id, remaining_balance, is_active) values (:a, 4000, true), (:a, 1000, true), (:a, 777, false), (:b, 50, true);
insert into public.zad_subscriptions (user_id, amount, is_active) values (:a, 99, true), (:a, 50, true), (:a, 70, false), (:b, 10, true);
insert into public.zad_inventory (user_id, item_name, quantity, low_stock_threshold, expiry_date, member_id) values
  (:a, 'لبن', 1, 2, to_char(current_date + 3, 'YYYY-MM-DD'), :mkid), (:a, 'رز', 9, 2, null, :ma), (:a, 'سكر', 2, 2, to_char(current_date - 5, 'YYYY-MM-DD'), :mkid),
  (:b, 'زيت', 0, 1, null, :mb);
insert into public.zad_pharmacy_items (user_id, name, remaining_quantity) values (:a, 'بنادول', 10), (:a, 'خلص', 0), (:b, 'ضغط', 5), (:b, 'سكر', 3);
insert into public.zad_appointments (user_id, title, starts_at) values
  (:a, 'دكتور', now() + interval '2 days'), (:a, 'بعيد', now() + interval '20 days'), (:b, 'عيادة', now() + interval '1 day');
insert into public.agent_goals (user_id, title, status, member_id) values (:a, 'رحلة', 'active', :mkid), (:a, 'قديم', 'done', :mkid), (:a, 'هدفي', 'active', :ma), (:b, 'هدف ب', 'active', :mb);
\set QUIET 0

-- ── الأرقام = الجداول مباشرة، لنفس العميل ──
select pg_temp.who(:a);
select pg_temp.check((public.zad_view_money() -> 'numbers' -> 'spent' ->> 'value')::numeric
  = (select sum(amount) from public.zad_transactions where user_id = :a and txn_kind = 'expense'), 'money.spent = the transactions table');
select pg_temp.check((public.zad_view_money() -> 'numbers' -> 'available' ->> 'value')::numeric = 3499.5, 'money.available is the budget state''s number');
select pg_temp.check((public.zad_view_money() -> 'numbers' -> 'debts_remaining' ->> 'value')::numeric
  = (select sum(remaining_balance) from public.zad_debts where user_id = :a and is_active), 'debts = active debts of this client only');
select pg_temp.check((public.zad_view_money() -> 'numbers' -> 'subscriptions_amount' ->> 'value')::numeric = 149, 'subscriptions = active ones only');
select pg_temp.check(public.zad_view_money() -> 'numbers' -> 'spent' ->> 'source' = 'zad_budget_state.spent', 'every number names its source');
select pg_temp.check((select bool_and(v ? 'source' and v ? 'value') from jsonb_each(public.zad_view_money() -> 'numbers') e(k, v)), 'all money numbers are {value, source}');
select pg_temp.check((public.zad_view_house() -> 'numbers' -> 'inventory_items' ->> 'value')::int = (select count(*) from public.zad_inventory where user_id = :a), 'house.inventory = table count');
select pg_temp.check((public.zad_view_house() -> 'numbers' -> 'low_stock' ->> 'value')::int = 2, 'house.low_stock counts quantity <= threshold (لبن، سكر)');
select pg_temp.check((public.zad_view_house() -> 'numbers' -> 'expiring_7d' ->> 'value')::int = 1, 'house.expiring_7d counts the next 7 days, not the past');
select pg_temp.check((public.zad_view_house() -> 'numbers' -> 'medicines_active' ->> 'value')::int = 1, 'house.medicines ignores the finished one');
select pg_temp.check((public.zad_view_house() -> 'numbers' -> 'appointments_7d' ->> 'value')::int = 1, 'house.appointments_7d');
select pg_temp.check((public.zad_view_home() -> 'numbers' -> 'available') = (public.zad_view_money() -> 'numbers' -> 'available'), 'home shows the same number as money');
select pg_temp.check((public.zad_view_home() -> 'numbers' -> 'low_stock') = (public.zad_view_house() -> 'numbers' -> 'low_stock'), 'home shows the same number as house');
select pg_temp.check((public.zad_view_home() -> 'numbers' -> 'goals_active' ->> 'value')::int = 2, 'home.goals_active');
select pg_temp.check((public.zad_view_home() -> 'numbers' -> 'household_members' ->> 'value')::int = 3, 'home.household_members');
select pg_temp.check(jsonb_array_length(public.zad_view_home() -> 'available_actions') >= 2
  and public.zad_view_home() -> 'available_actions' @> '[{"id": "restock"}]', 'home carries available_actions (restock when stock is low)');

-- ── عميل تاني مايشوفش بيانات الأول ──
select pg_temp.who(:b);
select pg_temp.check((public.zad_view_money() -> 'numbers' -> 'spent' ->> 'value')::numeric = 900, 'b sees b''s spending only');
select pg_temp.check((public.zad_view_money() -> 'numbers' -> 'debts_remaining' ->> 'value')::numeric = 50, 'b sees b''s debts only');
select pg_temp.check((public.zad_view_house() -> 'numbers' -> 'inventory_items' ->> 'value')::int = 1, 'b sees b''s pantry only');
select pg_temp.check((public.zad_view_house() -> 'next_appointment' ->> 'title') = 'عيادة', 'b sees b''s appointment only');
select pg_temp.check((public.zad_view_home() -> 'numbers' -> 'household_members' ->> 'value')::int = 1, 'b counts b''s household only');
select pg_temp.who(:c);
select pg_temp.check((public.zad_view_money() -> 'numbers' -> 'spent' ->> 'value')::numeric = 0, 'c with no data sees zero, not a''s numbers');

-- ── العائلة والخصوصية ──
select pg_temp.who(:a);
select pg_temp.check((public.zad_view_family(:mkid) ->> 'ok')::boolean and public.zad_view_family(:mkid) ->> 'relation' = 'guardian', 'the guardian sees her child');
select pg_temp.check((public.zad_view_family(:mkid) -> 'numbers' -> 'goals_active' ->> 'value')::int = 1, 'child goals = active ones with that member_id');
select pg_temp.check((public.zad_view_family(:mkid) -> 'numbers' -> 'low_stock' ->> 'value')::int = 2, 'child pantry low stock');
select pg_temp.check((public.zad_view_family(:mnolink) ->> 'ok')::boolean, 'the guardian sees an elder without an account');
select pg_temp.check(public.zad_view_family(:mb) ->> 'reason' = 'consent_required', 'an adult with an account is not shown to the admin without consent');
select pg_temp.who(:b);
select pg_temp.check(public.zad_view_family(:mkid) ->> 'reason' = 'child_requires_guardian', 'a child is not shown to anyone but the guardian');
select pg_temp.check(public.zad_view_family(:mnolink) ->> 'reason' = 'member_not_found', 'a member without an account is not shown to a non-owner');
select pg_temp.who(:c);
select pg_temp.check(public.zad_view_family(:mkid) ->> 'reason' = 'child_requires_guardian', 'an outsider cannot see the child either');
select pg_temp.check(public.zad_view_family('00000000-0000-0000-0000-00000000dead') ->> 'reason' = 'member_not_found', 'unknown member');

-- b grants spending only to a (admin): a sees b's spending, nothing else.
select pg_temp.who(:a);
select public.zad_family_request_share(:b, array['spending', 'medicines']);
select pg_temp.who(:b);
select public.zad_family_answer_share(id, true) from public.zad_family_shares where owner_id = :b and scope = 'spending';
select pg_temp.who(:a);
select pg_temp.check((public.zad_view_family(:mb) ->> 'ok')::boolean and public.zad_view_family(:mb) ->> 'relation' = 'consented', 'consented adult is shown');
select pg_temp.check(public.zad_view_family(:mb) -> 'sections' = '["spending"]'::jsonb, 'only the granted scope is in sections');
select pg_temp.check((public.zad_view_family(:mb) -> 'numbers' -> 'spent_30d' ->> 'value')::numeric = 900, 'spent_30d = the table for b');
select pg_temp.check(not (public.zad_view_family(:mb) -> 'numbers' ? 'medicines_active'), 'the pending (not granted) medicines scope shows nothing');
-- Revoked: gone again.
select pg_temp.who(:b);
select public.zad_family_revoke_share(id) from public.zad_family_shares where owner_id = :b and scope = 'spending';
select pg_temp.who(:a);
select pg_temp.check(public.zad_view_family(:mb) ->> 'reason' = 'consent_required', 'a revoked consent closes the view');

-- Only medicines granted now: spending (revoked) must stay out, medicines in.
select pg_temp.who(:b);
select public.zad_family_answer_share(id, true) from public.zad_family_shares where owner_id = :b and scope = 'medicines';
select pg_temp.who(:a);
select pg_temp.check(public.zad_view_family(:mb) -> 'sections' = '["medicines"]'::jsonb, 'a different single scope: only it is in sections');
select pg_temp.check(not (public.zad_view_family(:mb) -> 'numbers' ? 'spent_30d') and (public.zad_view_family(:mb) -> 'numbers' -> 'medicines_active' ->> 'value')::int = 2,
  'spending stays out when only medicines is granted; medicines = the table for b');

-- ── P1.3b: الولي يشوف أدوية الفرد وجرعاته الفايتة (الربط بـfor_person، مش family_member_id) ──
reset role;
insert into public.zad_pharmacy_items (id, user_id, name, remaining_quantity, for_person) values
  ('00000000-0000-0000-0000-0000000d0001', :a, 'فيتامين', 5, 'سلمى'), ('00000000-0000-0000-0000-0000000d0002', :a, 'مضاد', 0, 'سلمى'),
  ('00000000-0000-0000-0000-0000000d0003', :a, 'ضغط جدو', 7, ' جدو '), ('00000000-0000-0000-0000-0000000d0004', :a, 'غريب', 4, 'حد تاني');
insert into public.zad_pharmacy_doses (user_id, item_id, status, scheduled_at) values
  (:a, '00000000-0000-0000-0000-0000000d0001', 'missed', now() - interval '1 day'),
  (:a, '00000000-0000-0000-0000-0000000d0001', 'missed', now() - interval '30 days'),
  (:a, '00000000-0000-0000-0000-0000000d0001', 'skipped', now() - interval '1 day'),
  (:a, '00000000-0000-0000-0000-0000000d0001', 'taken', now() - interval '2 days'),
  (:a, '00000000-0000-0000-0000-0000000d0003', 'missed', now() - interval '2 days'),
  (:a, (select id from public.zad_pharmacy_items where user_id = :a and name = 'بنادول'), 'missed', now() - interval '3 days');
select pg_temp.who(:a);
select pg_temp.check((public.zad_view_family(:mkid) -> 'numbers' -> 'medicines_active' ->> 'value')::int = 1, 'guardian: the child''s active medicines (finished one and other people''s excluded)');
select pg_temp.check(public.zad_view_family(:mkid) -> 'numbers' -> 'medicines_active' ->> 'source' = 'zad_pharmacy_items.for_person', 'child medicines number names its source');
select pg_temp.check((public.zad_view_family(:mkid) -> 'numbers' -> 'missed_doses_7d' ->> 'value')::int = 1, 'guardian: the child''s missed dose (only status missed, last 7 days, only her items)');
select pg_temp.check(public.zad_view_family(:mkid) -> 'sections' @> '["medicines"]'::jsonb, 'medicines is in the guardian''s sections');
select pg_temp.check((public.zad_view_family(:mnolink) -> 'numbers' -> 'medicines_active' ->> 'value')::int = 1
  and (public.zad_view_family(:mnolink) -> 'numbers' -> 'missed_doses_7d' ->> 'value')::int = 1, 'the elder without an account: name match ignores spaces');
select pg_temp.check((public.zad_view_family(:ma) -> 'numbers' -> 'medicines_active' ->> 'value')::int = 1
  and (public.zad_view_family(:ma) -> 'numbers' -> 'missed_doses_7d' ->> 'value')::int = 1, 'self member = items with no for_person');
select pg_temp.check((select bool_and(v ? 'source' and v ? 'value') from jsonb_each(public.zad_view_family(:mkid) -> 'numbers') e(k, v)), 'all family numbers are {value, source}');
-- Not the guardian: no child medicines; a consented adult still sees only the consented scope.
select pg_temp.who(:b);
select pg_temp.check(not (public.zad_view_family(:mkid) ? 'numbers'), 'non-guardian gets no numbers for the child');
select pg_temp.check(not (public.zad_view_family(:mnolink) ? 'numbers'), 'non-guardian gets no numbers for an account-less member');
select pg_temp.who(:c);
select pg_temp.check(not (public.zad_view_family(:mkid) ? 'numbers'), 'outsider gets no medicines of the child');
select pg_temp.who(:a);
select pg_temp.check(not (public.zad_view_family(:mb) -> 'numbers' ? 'missed_doses_7d'), 'consented view of b never shows missed_doses_7d (guardian-only)');

-- ── مفيش كتابة، ومفيش وصول لـanon ──
select pg_temp.check(not has_function_privilege('anon', 'public.zad_view_family(uuid)', 'execute'), 'anon cannot execute zad_view_family');
select pg_temp.check(not has_function_privilege('anon', 'public.zad_view_money()', 'execute'), 'anon cannot execute zad_view_money');
select pg_temp.check(has_function_privilege('authenticated', 'public.zad_view_home()', 'execute'), 'authenticated can execute zad_view_home');
select pg_temp.who(null);
do $$ begin
  begin perform public.zad_view_home(); raise exception 'FAIL: unauthenticated call worked';
  exception when sqlstate '42501' then raise notice 'ok: no auth.uid() = refused'; end;
end $$;
