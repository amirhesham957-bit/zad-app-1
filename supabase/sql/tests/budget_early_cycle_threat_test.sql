-- «خطر» في تالت يوم من الشهر (migration 20261101170000), on a scratch database:
--
--   psql < supabase/migrations/20261101170000_budget_early_cycle_threat.sql
--   psql < supabase/sql/tests/budget_early_cycle_threat_test.sql
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

-- The owner's numbers on 2026-11-01: 10,000, 2,128.47 spent, ~3.9 days into a 31-day cycle.
select pg_temp.check(public.zad_budget_threat(true, 7871.53, 2128.47, 10000, 3.9, 31) = 'SAFE',
  'a month''s shop in the first days is not DANGER');
select pg_temp.check(public.zad_budget_threat(true, 4000, 6000, 10000, 3, 31) = 'WATCH',
  'more than half gone in the first week is WATCH');
select pg_temp.check(public.zad_budget_threat(true, -50, 10050, 10000, 2, 31) = 'OVER',
  'over the money is OVER on any day');
select pg_temp.check(public.zad_budget_threat(true, 4500, 5500, 10000, 10, 31) = 'DANGER',
  'from day seven the run rate judges: 55% in a third of the month');
select pg_temp.check(public.zad_budget_threat(true, 6500, 3500, 10000, 10, 31) = 'WATCH',
  '35% in 10 of 31 days is WATCH');
select pg_temp.check(public.zad_budget_threat(true, 8000, 2000, 10000, 10, 31) = 'SAFE',
  '20% in 10 of 31 days is SAFE');
select pg_temp.check(public.zad_budget_threat(false, 0, 100, 0, 10, 31) = 'UNKNOWN',
  'no budget set is UNKNOWN');
select pg_temp.check(public.zad_budget_threat(true, 0, 0, 0, 10, 31) = 'UNKNOWN',
  'nothing to spend from is UNKNOWN');
-- The whole state function at least compiles next to it (plpgsql bodies parse at create).
select pg_temp.check(to_regprocedure('public.zad_budget_state(uuid,text)') is not null, 'zad_budget_state exists');
