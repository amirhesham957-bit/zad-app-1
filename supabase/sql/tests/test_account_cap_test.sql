-- سقف حساب الاختبار (migration 20261025041500, ZAD_PLAN 3.7), on a scratch database:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/migrations/20261025041500_test_account_cap.sql
--   psql < supabase/sql/tests/test_account_cap_test.sql

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

\set QUIET 1
create or replace function pg_temp.check(cond boolean, label text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAIL: %', label; end if; raise notice 'ok: %', label; end $$;
\set QUIET 0

select pg_temp.check((select bool_and(public.zad_test_turn_take(3)) from generate_series(1, 3)), 'the first three of a cap of three go through');
select pg_temp.check(not public.zad_test_turn_take(3), 'the fourth does not');
select pg_temp.check((select used from public.zad_test_turn_budget where day = (now() at time zone 'utc')::date) = 3, 'and is not counted');
select pg_temp.check(public.zad_test_turn_take(5), 'a higher cap the same day lets more through');
select pg_temp.check(not public.zad_test_turn_take(0) and not public.zad_test_turn_take(null), 'a zero or missing cap refuses');
update public.zad_test_turn_budget set day = day - 1;
select pg_temp.check(public.zad_test_turn_take(3), 'a new UTC day starts again');
select pg_temp.check(not has_function_privilege('authenticated', 'public.zad_test_turn_take(int)', 'execute'), 'customers cannot take from it');
