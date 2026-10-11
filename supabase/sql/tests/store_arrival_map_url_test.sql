-- agent_tasks.map_url (migration 20261010180000): only storeMapUrl's own link fits. Scratch database only:
--
--   docker run -d --name zadpg -e POSTGRES_PASSWORD=pg postgres:17-alpine
--   psql() { docker exec -i zadpg psql -U postgres -v ON_ERROR_STOP=1 -q; }
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/store_arrival_map_url_test.sql
--
-- agent_tasks is created here in its live shape (read 2026-10-10) when the scaffold lacks
-- it; the migration is applied inside the transaction, and everything rolls back.

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

begin;

create table if not exists public.agent_tasks (
  id uuid primary key default gen_random_uuid(), user_id uuid not null, task_description text not null,
  status text, scheduled_for timestamptz, result text, created_at timestamptz default now(),
  updated_at timestamptz default now(), kind text, goal_id uuid, recurrence text, last_run_result text);
-- A row from before the migration: no link, still valid after it.
insert into public.agent_tasks (user_id, task_description, kind, status)
values ('00000000-0000-0000-0000-0000000000d1', 'وصول لـ«كارفور» (supermarket)', 'store_arrival', 'done');

\i supabase/migrations/20261010180000_store_arrival_keeps_its_point.sql
-- Idempotent: CI may meet it twice on a reset.
\i supabase/migrations/20261010180000_store_arrival_keeps_its_point.sql

do $$
declare v_ok text := 'https://www.google.com/maps/search/?api=1&query=30.04442,31.23571';
begin
  insert into public.agent_tasks (user_id, task_description, kind, status, map_url)
  values ('00000000-0000-0000-0000-0000000000d1', 'وصول لـ«العطار» (spices)', 'store_arrival', 'done', v_ok);
  insert into public.agent_tasks (user_id, task_description, kind, status, map_url)
  values ('00000000-0000-0000-0000-0000000000d1', 'وصول لـ«x» (supermarket)', 'store_arrival', 'done',
          'https://www.google.com/maps/search/?api=1&query=-33.86882,-151.20929');
  -- Anything else is refused: another site, a script, a looser point, extra parameters.
  declare bad text;
  begin
    foreach bad in array array[
      'https://evil.example/?q=30.04442,31.23571',
      'javascript:alert(1)',
      'https://www.google.com/maps/search/?api=1&query=30.04,31.23',
      v_ok || '&hl=ar',
      'http://www.google.com/maps/search/?api=1&query=30.04442,31.23571'
    ] loop
      begin
        insert into public.agent_tasks (user_id, task_description, kind, map_url)
        values ('00000000-0000-0000-0000-0000000000d1', 'x', 'store_arrival', bad);
        raise exception 'accepted a bad link: %', bad;
      exception when check_violation then null;
      end;
    end loop;
  end;
  if (select count(*) from public.agent_tasks where map_url is not null) <> 2 then
    raise exception 'expected two linked rows';
  end if;
  raise notice 'store_arrival_map_url_test: all passed';
end $$;

rollback;
