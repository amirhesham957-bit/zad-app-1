-- رقم التكلفة (migration 20261025050500, ZAD_PLAN 3.8), on a scratch database:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/brain_cost_scaffold.sql
--   psql < supabase/migrations/20261025050500_brain_cost.sql
--   psql < supabase/sql/tests/brain_cost_test.sql

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

\set QUIET 1
create or replace function pg_temp.check(cond boolean, label text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAIL: %', label; end if; raise notice 'ok: %', label; end $$;
\set a '''00000000-0000-0000-0000-0000000000a1'''
\set day '''2026-10-20'''
-- Four runs on one day: two lite runs (2s, 4s), one mixed with 3.6-flash (8s), one on an unpriced model (12s).
insert into public.zad_brain_runs (user_id, trigger, status, started_at, finished_at, input_tokens, output_tokens, prompt_sizes) values
  (:a, 'chat', 'success', '2026-10-20 10:00:00+00', '2026-10-20 10:00:02+00', 1000000, 0, '{"calls":{"models":["gemini-3.5-flash-lite"]}}'),
  (:a, 'chat', 'success', '2026-10-20 11:00:00+00', '2026-10-20 11:00:04+00', 0, 1000000, '{"calls":{"models":["gemini-3.1-flash-lite"]}}'),
  (:a, 'chat', 'success', '2026-10-20 12:00:00+00', '2026-10-20 12:00:08+00', 1000000, 0, '{"calls":{"models":["gemini-3.1-flash-lite","gemini-3.6-flash"]}}'),
  (:a, 'chat', 'success', '2026-10-20 13:00:00+00', '2026-10-20 13:00:12+00', 500, 50, '{"calls":{"models":["gemini-3.5-flash"]}}'),
  (:a, 'daily', 'success', '2026-10-20 14:00:00+00', null, 9, 9, null);
insert into public.zad_health_daily (day, user_id) values (:day, :a);
\set QUIET 0

select pg_temp.check(public.zad_run_cost_usd('["gemini-3.5-flash-lite"]', 1000000, 1000000, '2026-10-20') = 2.80, 'a million in and out on 3.5 lite is 0.30 + 2.50');
select pg_temp.check(public.zad_run_cost_usd('["gemini-3.1-flash-lite","gemini-3.6-flash"]', 1000000, 0, '2026-10-20') = 0.75, 'a mixed run is priced at its dearest model');
select pg_temp.check(public.zad_run_cost_usd('["gemini-3.6-flash"]', 1000000, 0, '2027-02-01') = 1.50, 'the 2027 price applies from January');
select pg_temp.check(public.zad_run_cost_usd('["gemini-3.5-flash"]', 1000, 10, '2026-10-20') is null, 'a model without a published price is not guessed');
select pg_temp.check(public.zad_run_cost_usd(null, 1000, 10, '2026-10-20') is null, 'a run with no models recorded is unpriced');

select pg_temp.check(public.zad_health_brain_cost(:day) = 1, 'the day''s row is filled');
select pg_temp.check((select brain_cost_usd = 2.55 and brain_unpriced_runs = 1 and brain_fast_runs = 2 from public.zad_health_daily where day = :day),
  'cost sums the priced runs (0.30 + 1.50 + 0.75), the unpriced one is counted apart, two were under 6s');
select pg_temp.check((select brain_p90_secs between 10 and 12 from public.zad_health_daily where day = :day), 'p90 reads the slow tail');

select pg_temp.check((select runs = 4 and cost_usd = 2.55 and unpriced_runs = 1 and fast_pct = 50 from public.zad_brain_cost_monthly('2026-10-01') where user_id = :a),
  'the month per home: runs, cost, unpriced, share under 6s');
select pg_temp.check(not has_function_privilege('authenticated', 'public.zad_brain_cost_monthly(date)', 'execute'), 'customers cannot read it');
