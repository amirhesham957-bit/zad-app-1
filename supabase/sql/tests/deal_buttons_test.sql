-- عرض الصبح بزرارين (migration 20261026183500, ZAD_PLAN 4.20), on a scratch database:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/deal_buttons_scaffold.sql
--   psql < supabase/migrations/20261026183500_deal_buttons.sql
--   psql < supabase/sql/tests/deal_buttons_test.sql
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
create or replace function pg_temp.listed(p_user uuid, p_name text) returns bigint language sql as $$
  select count(*) from public.zad_shopping_list where user_id = p_user and item_name = p_name and not is_purchased $$;
\set a '''00000000-0000-0000-0000-0000000000a1'''
\set b '''00000000-0000-0000-0000-0000000000b1'''
\set m1 '''00000000-0000-0000-0000-00000000d001'''
\set m2 '''00000000-0000-0000-0000-00000000d002'''
\set m3 '''00000000-0000-0000-0000-00000000d003'''
insert into auth.users values (:a), (:b) on conflict do nothing;
insert into public.zad_voice_moments (id, user_id, moment, facts) values
  (:m1, :a, 'morning_greeting', '{"taste_deal": {"item": "زيت عافية ١.٥ لتر", "store": "كارفور", "key": "deal:زيت:كارفور"}}'),
  (:m2, :a, 'morning_greeting', '{"taste_deal": {"item": "الرز المصري", "store": "بنده", "key": "deal:رز:بنده"}}'),
  (:m3, :a, 'morning_greeting', '{"weather": {}}');

-- 1. «ضيفه لقايمتي» adds the item once and keeps the answer.
select pg_temp.check((public.zad_deal_answer_service(:a, :m1, true) ->> 'answer') = 'add', 'add is recorded');
select pg_temp.check(pg_temp.listed(:a, 'زيت عافية ١.٥ لتر') = 1, 'the item is on the list');
select pg_temp.check((select facts -> 'taste_deal' ->> 'answer' = 'add' from public.zad_voice_moments where id = :m1), 'the answer is on the moment');

-- 2. A second tap (either button) changes nothing.
select pg_temp.check((public.zad_deal_answer_service(:a, :m1, false) ->> 'already')::boolean, 'a second tap is already answered');
select pg_temp.check(pg_temp.listed(:a, 'زيت عافية ١.٥ لتر') = 1, 'a second tap does not add twice');

-- 3. Already on the list under the same name key («رز المصري» = «الرز المصري»): no duplicate.
insert into public.zad_shopping_list (user_id, item_name) values (:a, 'رز المصرى');
select pg_temp.check((public.zad_deal_answer_service(:a, :m2, true) ->> 'already_listed')::boolean, 'already listed is said');
select pg_temp.check((select count(*) from public.zad_shopping_list where user_id = :a) = 2, 'no duplicate row');

-- 4. «مش مهتم» writes nothing to the list.
update public.zad_voice_moments set facts = '{"taste_deal": {"item": "شاي بروك", "store": "العثيم"}}' where id = :m3;
select pg_temp.check((public.zad_deal_answer_service(:a, :m3, false) ->> 'answer') = 'no', 'no is recorded');
select pg_temp.check(pg_temp.listed(:a, 'شاي بروك') = 0, 'no adds nothing');

-- 5. Another account's moment cannot be answered; a moment without a deal is not found.
insert into public.zad_voice_moments (id, user_id, moment, facts) values
  ('00000000-0000-0000-0000-00000000d004', :a, 'morning_greeting', '{"taste_deal": {"item": "سكر", "store": "كيو"}}');
select pg_temp.check((public.zad_deal_answer_service(:b, '00000000-0000-0000-0000-00000000d004', true) ->> 'reason') = 'not_found',
  'ownership comes from the moment');
select pg_temp.check((select count(*) from public.zad_shopping_list where item_name = 'سكر') = 0, 'nothing added for a stranger');

-- 6. The customers cannot call the service.
select pg_temp.check(not has_function_privilege('authenticated', 'public.zad_deal_answer_service(uuid, uuid, boolean)', 'execute'),
  'customers cannot answer through the bot''s door');
