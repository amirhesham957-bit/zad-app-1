-- Goals over days (migration 20261113070000, ZAD_PLAN 10.2d), on a scratch database. Runs in CI:
--   docker run -d --name zadpg -e POSTGRES_PASSWORD=pg postgres:17-alpine
--   psql() { docker exec -i zadpg psql -U postgres -v ON_ERROR_STOP=1 -q; }
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/goals_over_days_scaffold.sql
--   psql < supabase/migrations/20261113070000_goals_over_days.sql
--   psql < supabase/sql/tests/goals_over_days_test.sql
--
-- A (a1) has the app's counted goal, B (b1) the chat's money goal. Raises on the first failed check.

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

create or replace function pg_temp.check(cond boolean, label text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAIL: %', label; end if; raise notice 'ok: %', label; end $$;

-- Backfill.
select pg_temp.check((select progress_kind from public.agent_goals where id = 'b0000000-0000-0000-0000-0000000000b1') = 'amount',
  'the chat''s money goal is an amount');
select pg_temp.check((select progress_kind from public.agent_goals where id = 'a0000000-0000-0000-0000-0000000000a1') = 'tasks',
  'the app''s counted goal stays counted');
select pg_temp.check((select count(*) from public.agent_tasks where goal_id = 'b0000000-0000-0000-0000-0000000000b1' and kind = 'goal_review' and status = 'pending') = 1,
  'the goal without a follow-up got one');
select pg_temp.check((select task_description from public.agent_tasks where goal_id = 'b0000000-0000-0000-0000-0000000000b1') like '%حط كام%',
  'a money goal''s follow-up asks how much went in');
select pg_temp.check((select count(*) from public.agent_tasks where goal_id = 'a0000000-0000-0000-0000-0000000000a1' and kind = 'goal_review') = 1,
  'a goal that had its follow-up did not get a second');

-- One follow-up per goal, however often it is asked for.
select public.zad_goal_ensure_review('00000000-0000-0000-0000-0000000000b1', 'b0000000-0000-0000-0000-0000000000b1');
select pg_temp.check((select count(*) from public.agent_tasks where goal_id = 'b0000000-0000-0000-0000-0000000000b1' and status in ('pending', 'running')) = 1,
  'ensure_review is idempotent');
select pg_temp.check(public.zad_goal_ensure_review('00000000-0000-0000-0000-0000000000a1', 'b0000000-0000-0000-0000-0000000000b1') is null,
  'nobody schedules a review on someone else''s goal');

-- Progress.
select pg_temp.check((public.zad_goal_add_progress('00000000-0000-0000-0000-0000000000b1', 'b0000000-0000-0000-0000-0000000000b1', 150) ->> 'current_value')::numeric = 150,
  'the owner puts 150 in');
select pg_temp.check(public.zad_goal_add_progress('00000000-0000-0000-0000-0000000000a1', 'b0000000-0000-0000-0000-0000000000b1', 150) ->> 'reason' = 'unknown_goal',
  'another account cannot move my goal');
select pg_temp.check(public.zad_goal_add_progress('00000000-0000-0000-0000-0000000000a1', 'a0000000-0000-0000-0000-0000000000a1', 5) ->> 'reason' = 'not_amount',
  'a counted goal takes no amount');
select pg_temp.check((public.zad_goal_add_progress('00000000-0000-0000-0000-0000000000b1', 'b0000000-0000-0000-0000-0000000000b1', -500) ->> 'current_value')::numeric = 0,
  'taking out more than is there stops at zero');
select pg_temp.check(public.zad_goal_add_progress('00000000-0000-0000-0000-0000000000b1', 'b0000000-0000-0000-0000-0000000000b1', 0) ->> 'reason' = 'no_amount',
  'zero is not progress');

-- A finished review moves a counted goal by one, and a money goal not at all.
update public.agent_tasks set status = 'done' where goal_id = 'a0000000-0000-0000-0000-0000000000a1';
select pg_temp.check((select current_value from public.agent_goals where id = 'a0000000-0000-0000-0000-0000000000a1') = 2,
  'a done review counts for a counted goal');
select public.zad_goal_add_progress('00000000-0000-0000-0000-0000000000b1', 'b0000000-0000-0000-0000-0000000000b1', 100);
update public.agent_tasks set status = 'done' where goal_id = 'b0000000-0000-0000-0000-0000000000b1';
select pg_temp.check((select current_value from public.agent_goals where id = 'b0000000-0000-0000-0000-0000000000b1') = 100,
  'a done review adds nothing to a money goal');

-- The client calls neither function.
select pg_temp.check(not has_function_privilege('authenticated', 'public.zad_goal_add_progress(uuid, uuid, numeric)', 'execute'),
  'authenticated cannot add progress');
select pg_temp.check(not has_function_privilege('anon', 'public.zad_goal_ensure_review(uuid, uuid)', 'execute'),
  'anon cannot schedule reviews');
select pg_temp.check(has_function_privilege('service_role', 'public.zad_goal_add_progress(uuid, uuid, numeric)', 'execute'),
  'the brain can');

select 'goals_over_days_test: all checks passed' as result;
