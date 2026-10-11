-- On top of scratch_scaffold.sql: what 20261011230000_guardian_outcomes reads, with
-- _agent_proactive_suppressed as the repo has it (20260913190000).
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/guardian_outcomes_scaffold.sql
--   psql < supabase/migrations/20261011230000_guardian_outcomes.sql
--   psql < supabase/sql/tests/guardian_outcomes_test.sql

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

create table if not exists public.agent_tasks (
  id uuid primary key default gen_random_uuid(), user_id uuid, kind text, task_description text,
  scheduled_for timestamptz, status text default 'pending', created_at timestamptz default now(),
  updated_at timestamptz);
create table if not exists public.zad_chat_turns (
  id uuid primary key default gen_random_uuid(), user_id uuid, role text, text text, created_at timestamptz default now());
create table if not exists public.agent_actions (
  id uuid primary key default gen_random_uuid(), user_id uuid not null, source text not null default 'app_chat',
  tool_name text not null default 'x', created_at timestamptz not null default now());
create table if not exists public.zad_memory (
  id uuid primary key default gen_random_uuid(), user_id uuid, note text);
alter table public.zad_memory add column if not exists subject_kind text;
alter table public.zad_memory add column if not exists suppress_until timestamptz;

create or replace function public._agent_proactive_suppressed(p_user uuid, p_kind text)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $$
  select exists (
    select 1 from public.zad_memory m
    where m.user_id = p_user
      and m.subject_kind = p_kind
      and m.suppress_until > now()
  );
$$;

insert into auth.users values ('00000000-0000-0000-0000-0000000000a1'), ('00000000-0000-0000-0000-0000000000a2')
  on conflict do nothing;
