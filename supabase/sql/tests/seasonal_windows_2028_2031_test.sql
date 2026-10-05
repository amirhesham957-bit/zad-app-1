-- Hijri season windows 2028–2031 (migration 20261005170000), on a scratch
-- database:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/migrations/20260722070000_add_seasonal_budget_forecasting.sql   # stops at line 140
--     (zad_transactions is not in the scaffold) after the season tables and their seed exist
--   psql < supabase/migrations/20261005170000_seasonal_windows_2028_2031.sql
--   psql < supabase/sql/tests/seasonal_windows_2028_2031_test.sql

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

create or replace function pg_temp.check(cond boolean, label text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAIL: %', label; end if; raise notice 'ok: %', label; end $$;

select pg_temp.check((select count(*) from seasonal_event_windows where year between 2028 and 2031) = 16,
  'four seasons a year, 2028 to 2031');
select pg_temp.check(exists (select 1 from seasonal_event_windows w join seasonal_events e on e.id = w.event_id
  where e.slug = 'ramadan' and w.start_date::date = '2028-01-28' and w.end_date::date = '2028-02-25'), 'Ramadan 1449');
-- 2030 has two Ramadans; the December one is filed under the year it ends.
select pg_temp.check((select count(*) from seasonal_event_windows w join seasonal_events e on e.id = w.event_id
  where e.slug = 'ramadan' and w.start_date >= '2030-01-01' and w.start_date < '2031-01-01') = 2,
  'both Ramadans that start in 2030 are there');
select pg_temp.check(not exists (select 1 from seasonal_event_windows where end_date < start_date), 'no window ends before it starts');
select pg_temp.check(not exists (
  select 1 from seasonal_event_windows a join seasonal_event_windows b
    on a.event_id = b.event_id and a.ctid <> b.ctid and a.start_date <= b.end_date and b.start_date <= a.end_date),
  'no season overlaps itself');
-- A re-run adds nothing.
\i supabase/migrations/20261005170000_seasonal_windows_2028_2031.sql
select pg_temp.check((select count(*) from seasonal_event_windows where year between 2028 and 2031) = 16, 'idempotent');
