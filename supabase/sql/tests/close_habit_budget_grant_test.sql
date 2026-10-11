-- 20261011130000_close_habit_budget_grant: anon and signed-in callers can no longer run
-- the two definer functions; the service role (and agent_proactive_scan, owned by
-- postgres) still can.
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/close_habit_budget_grant_test.sql   (creates the live
--        signatures with Supabase's default grants, applies the migration, checks)
--
-- Never against the live project: the guard below refuses.

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

-- The live signatures, granted the way Supabase grants a new public function. The
-- bodies are stand-ins: the migration only changes who may execute them.
create or replace function public._agent_habit_budget_for_user(p_user uuid)
returns void language plpgsql security definer set search_path to 'public'
as $$ begin perform p_user; end $$;
create or replace function public.zad_sync_pay_day_from_cycle()
returns trigger language plpgsql security definer set search_path to 'public'
as $$ begin return new; end $$;
grant execute on function public._agent_habit_budget_for_user(uuid) to public, anon, authenticated, service_role;
grant execute on function public.zad_sync_pay_day_from_cycle() to public, anon, authenticated, service_role;

do $$ begin
  assert has_function_privilege('anon', 'public._agent_habit_budget_for_user(uuid)', 'execute'),
    'fixture: anon should start with execute';
end $$;

\i supabase/migrations/20261011130000_close_habit_budget_grant.sql

do $$
declare r text;
begin
  foreach r in array array['anon', 'authenticated'] loop
    assert not has_function_privilege(r, 'public._agent_habit_budget_for_user(uuid)', 'execute'),
      r || ' can still run _agent_habit_budget_for_user';
    assert not has_function_privilege(r, 'public.zad_sync_pay_day_from_cycle()', 'execute'),
      r || ' can still run zad_sync_pay_day_from_cycle';
  end loop;
  assert has_function_privilege('service_role', 'public._agent_habit_budget_for_user(uuid)', 'execute'),
    'service_role lost _agent_habit_budget_for_user';
  assert has_function_privilege('service_role', 'public.zad_sync_pay_day_from_cycle()', 'execute'),
    'service_role lost zad_sync_pay_day_from_cycle';
end $$;

-- As PostgREST would call it, signed out.
begin;
set local role anon;
do $$ begin
  perform public._agent_habit_budget_for_user('00000000-0000-0000-0000-0000000000e1');
  raise exception 'anon ran _agent_habit_budget_for_user';
exception when insufficient_privilege then null;
end $$;
rollback;

begin;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000e1","role":"authenticated"}', true);
set local role authenticated;
do $$ begin
  perform public._agent_habit_budget_for_user('00000000-0000-0000-0000-0000000000e2');
  raise exception 'a signed-in account ran _agent_habit_budget_for_user for another account';
exception when insufficient_privilege then null;
end $$;
rollback;

begin;
set local role service_role;
select public._agent_habit_budget_for_user('00000000-0000-0000-0000-0000000000e1');
rollback;

\echo close_habit_budget_grant_test: all checks passed
