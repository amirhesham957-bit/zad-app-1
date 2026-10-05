-- The occasion's name for the widget's countdown (migration 20261005100000),
-- on a scratch database:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/migrations/20261004120000_app_campaigns.sql
--   psql < supabase/migrations/20261005100000_app_campaigns_event_name.sql
--   psql < supabase/sql/tests/app_campaigns_event_name_test.sql

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

create or replace function pg_temp.check(cond boolean, label text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAIL: %', label; end if; raise notice 'ok: %', label; end $$;

-- 1. Every seeded campaign has a name.
select pg_temp.check(not exists (select 1 from public.app_campaigns where event_name is null),
  'every seeded campaign is named');
select pg_temp.check((select event_name from public.app_campaigns where event_key = 'white_friday' and dialect is null)
  = 'الوايت فرايداي', 'White Friday');
select pg_temp.check((select event_name from public.app_campaigns where event_key = 'new_year' and dialect = 'GULF')
  = 'رأس السنة', 'the Gulf copy spells New Year its own way');
select pg_temp.check((select event_name from public.app_campaigns where event_key = 'new_year' and dialect is null)
  = 'راس السنة', 'and the default keeps its own');

-- 2. A name changed on the dashboard survives a re-run.
update public.app_campaigns set event_name = 'بلاك فرايداي' where event_key = 'white_friday' and dialect is null;
\i supabase/migrations/20261005100000_app_campaigns_event_name.sql
select pg_temp.check((select event_name from public.app_campaigns where event_key = 'white_friday' and dialect is null)
  = 'بلاك فرايداي', 're-applying keeps a dashboard edit');

-- 3. Short enough for the widget's one line.
do $$ begin
  update public.app_campaigns set event_name = repeat('x', 41) where event_key = 'halloween' and dialect is null;
  raise exception 'FAIL: stored a 41-character name';
exception when check_violation then raise notice 'ok: at most 40 characters'; end $$;
