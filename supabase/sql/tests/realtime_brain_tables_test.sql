-- 20261011190000: the three tables join supabase_realtime once, however often it runs.
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/realtime_brain_tables_test.sql

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

begin;
create table if not exists public.app_notifications (id uuid primary key, user_id uuid);
create table if not exists public.zad_insights (id uuid primary key, user_id uuid);
create table if not exists public.zad_pharmacy_doses (id uuid primary key, user_id uuid);
create table if not exists public.zad_debts_rt_probe (id uuid primary key);
create publication supabase_realtime for table public.zad_debts_rt_probe;
-- one of the three already in, as on a project where someone added it by hand
alter publication supabase_realtime add table public.zad_insights;

\i supabase/migrations/20261011190000_realtime_for_what_the_brain_writes.sql
\i supabase/migrations/20261011190000_realtime_for_what_the_brain_writes.sql

do $$ begin
  assert (select count(*) from pg_publication_tables
           where pubname = 'supabase_realtime'
             and tablename in ('app_notifications', 'zad_insights', 'zad_pharmacy_doses')) = 3,
    'not all three are published';
  assert exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'zad_debts_rt_probe'),
    'a table already published was dropped';
end $$;
rollback;

\echo realtime_brain_tables_test: all checks passed
