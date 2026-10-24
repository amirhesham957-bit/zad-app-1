-- المرتب يفتح الدورة (migration 20261025001500, ZAD_PLAN 2.4), on a scratch database:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/salary_opens_cycle_scaffold.sql
--   psql < supabase/migrations/20261025001500_salary_opens_cycle.sql
--   psql < supabase/sql/tests/salary_opens_cycle_test.sql
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
create or replace function pg_temp.moments(p_user uuid) returns bigint language sql as $$
  select count(*) from public.zad_voice_moments where user_id = p_user and moment = 'salary_cycle' $$;
\set a '''00000000-0000-0000-0000-0000000000a1'''
\set b '''00000000-0000-0000-0000-0000000000b1'''
insert into auth.users values (:a), (:b) on conflict do nothing;
insert into public.zad_users (id, currency, country, cycle_start_day) values (:a, 'EGP', 'EG', 25), (:b, 'SAR', 'SA', null);
-- A: salaries of 12,000 in the last three months.
insert into public.zad_transactions (user_id, amount, txn_kind, source_type, created_at) values
  (:a, 12000, 'income', 'notification_listener', now() - interval '35 days'),
  (:a, 11800, 'income', 'notification_listener', now() - interval '65 days'),
  (:a, 12100, 'income', 'notification_listener', now() - interval '95 days'),
  (:a, 300, 'expense', 'notification_listener', now() - interval '3 days');
-- A's pantry: rice for 14 days, oil for 10, milk for 2 (too little to mention), salt unknown rate.
insert into public.zad_inventory (user_id, item_name, quantity) values (:a, 'رز', 7), (:a, 'زيت', 2), (:a, 'لبن', 1), (:a, 'ملح', 5);
insert into public.zad_consumption (user_id, item_name, avg_daily_qty, rate_known) values
  (:a, 'رز', 0.5, true), (:a, 'زيت', 0.2, true), (:a, 'لبن', 0.5, true), (:a, 'ملح', 0.01, false);
-- The cycle day is never today, whatever day the test runs on.
update public.zad_users set cycle_start_day = (extract(day from now() at time zone 'Africa/Cairo')::int % 28) + 1 where id = :a;
\set QUIET 0

-- 0. History typed in with old dates never asks.
select pg_temp.check(pg_temp.moments(:a) = 0, 'old-dated deposits ask nothing');

-- 1. A transfer from a friend (2,000) is not the salary.
insert into public.zad_transactions (user_id, amount, txn_kind, source_type) values (:a, 2000, 'income', 'notification_listener');
select pg_temp.check(pg_temp.moments(:a) = 0, 'an income far from the usual salary asks nothing');

-- 2. 12,000 lands on a day that is not the cycle day: one question, with the pantry.
insert into public.zad_transactions (user_id, amount, txn_kind, source_type) values (:a, 12050, 'income', 'notification_listener');
select pg_temp.check(pg_temp.moments(:a) = 1, 'a salary-sized deposit asks once');
select pg_temp.check((select (facts ->> 'day')::int = extract(day from now() at time zone 'Africa/Cairo')::int
                             and (facts ->> 'pay_day')::int = (extract(day from now() at time zone 'Africa/Cairo')::int % 28) + 1
                             and jsonb_array_length(facts -> 'pantry') = 2
                             and facts -> 'pantry' -> 0 ->> 'name' = 'رز'
                        from public.zad_voice_moments where user_id = :a and moment = 'salary_cycle'),
  'the question carries today, the old pay day, and what lasts a week or more');

-- 3. A second one inside 20 days asks nothing.
insert into public.zad_transactions (user_id, amount, txn_kind, source_type) values (:a, 12000, 'income', 'notification_listener');
select pg_temp.check(pg_temp.moments(:a) = 1, 'one question every 20 days at most');

-- 4. Typed by hand, not from the bank: nothing.
delete from public.zad_voice_moments;
insert into public.zad_transactions (user_id, amount, txn_kind, source_type) values (:a, 12000, 'income', null);
select pg_temp.check(pg_temp.moments(:a) = 0, 'only bank deposits ask');

-- 5. «Yes» moves the cycle; the answer is kept; a second tap changes nothing.
insert into public.zad_transactions (user_id, amount, txn_kind, source_type) values (:a, 12000, 'income', 'notification_listener');
select pg_temp.check((select public.zad_salary_cycle_service(:a, id, true) ->> 'answer' = 'yes'
                        from public.zad_voice_moments where user_id = :a and moment = 'salary_cycle'), 'yes is recorded');
select pg_temp.check((select cycle_start_day = extract(day from now() at time zone 'Africa/Cairo')::int from public.zad_users where id = :a),
  'the cycle now starts today');
select pg_temp.check((select (public.zad_salary_cycle_service(:a, id, false) ->> 'already')::boolean
                        from public.zad_voice_moments where user_id = :a and moment = 'salary_cycle'), 'a second tap is already answered');

-- 6. Another account's moment cannot be answered.
select pg_temp.check((select public.zad_salary_cycle_service(:b, id, true) ->> 'reason' = 'not_found'
                        from public.zad_voice_moments where user_id = :a and moment = 'salary_cycle'), 'ownership comes from the moment');

-- 7. No history: half of last month's spending or more counts; less does not.
insert into public.zad_transactions (user_id, amount, txn_kind, source_type) values (:b, 1000, 'expense', 'notification_listener');
insert into public.zad_transactions (user_id, amount, txn_kind, source_type) values (:b, 400, 'income', 'notification_listener');
select pg_temp.check(pg_temp.moments(:b) = 0, 'no history: a small income asks nothing');
insert into public.zad_transactions (user_id, amount, txn_kind, source_type) values (:b, 9000, 'income', 'notification_listener');
select pg_temp.check(pg_temp.moments(:b) = 1, 'no history: a large income asks');

-- 8. The customers cannot call the service.
select pg_temp.check(not has_function_privilege('authenticated', 'public.zad_salary_cycle_service(uuid, uuid, boolean)', 'execute'),
  'customers cannot move a cycle through the bot''s door');
