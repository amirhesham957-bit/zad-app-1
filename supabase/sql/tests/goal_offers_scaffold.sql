-- Scaffold for goal_offers_test.sql: agent_goals (just the columns the offer functions read). Scratch only.
\set ON_ERROR_STOP on
do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;
create table public.agent_goals (id uuid primary key default gen_random_uuid(), user_id uuid not null, title text, status text not null default 'active', member_id uuid);
