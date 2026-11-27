-- zad_bandit_state (20261127100000). Scratch only:
--   psql < supabase/sql/tests/scratch_scaffold.sql ; psql < ...bandit_state.sql ; psql < this
\set ON_ERROR_STOP on
do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;
begin;
do $$
declare u uuid := gen_random_uuid(); m uuid := gen_random_uuid();
begin
  assert to_regclass('public.zad_bandit_state') is not null, 'table missing';
  assert (select relrowsecurity from pg_class where oid = 'public.zad_bandit_state'::regclass), 'rls off';
  assert not has_table_privilege('authenticated', 'public.zad_bandit_state', 'select'), 'customers read bandit';
  assert not has_table_privilege('authenticated', 'public.zad_bandit_state', 'insert'), 'customers write bandit';
  assert not has_table_privilege('anon', 'public.zad_bandit_state', 'select'), 'anon reads bandit';
  assert has_table_privilege('service_role', 'public.zad_bandit_state', 'insert'), 'service cannot write';
  insert into public.zad_bandit_state (user_id, member_id, kind, arm, successes) values (u, m, 'habit_budget', 'warm', 1);
  begin
    insert into public.zad_bandit_state (user_id, member_id, kind, arm) values (u, m, 'habit_budget', 'warm');
    raise exception 'duplicate key kept';
  exception when unique_violation then null; end;
  begin
    insert into public.zad_bandit_state (user_id, member_id, kind, arm, failures) values (u, m, 'habit_budget', 'x', -1);
    raise exception 'negative kept';
  exception when check_violation then null; end;
end $$;
rollback;
\echo bandit_state_test: all checks passed
