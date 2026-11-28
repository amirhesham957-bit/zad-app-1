-- Scratch shape for family_buttons_test.sql, after events_ledger_scaffold + events_ledger + household_traits + member_facts +
-- events_trace_id: the family tables the P1.6b family door writes (live shapes, 2026-11-28, trimmed to the columns it touches) and
-- a copy of zad_is_minor_user from 20261128190000_visibility_matrix (whose own chain is too wide to share). Never against live.
\set ON_ERROR_STOP on
do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

create table public.family_groups (id uuid primary key default gen_random_uuid(), invite_code text, created_at timestamptz default now());
create table public.family_members (
  id uuid primary key default gen_random_uuid(), family_id uuid references public.family_groups(id) on delete cascade, user_id uuid,
  role text default 'member', alias text, created_at timestamptz default now(), balance numeric default 0,
  last_seen_at timestamptz default now(), daily_limit numeric, weekly_limit numeric);
create table public.family_chores (id uuid primary key default gen_random_uuid(), family_id uuid, assigned_to uuid, title text, due_date text,
  is_completed boolean default false, created_at timestamptz default now(), reward_amount numeric default 0, minutes integer);
create table public.family_chore_preferences (
  member_id uuid primary key references public.family_members(id) on delete cascade,
  family_id uuid not null references public.family_groups(id) on delete cascade,
  minutes_per_week integer not null default 120 check (minutes_per_week between 0 and 2000),
  dislikes text[] not null default '{}' check (cardinality(dislikes) <= 20),
  likes text[] not null default '{}' check (cardinality(likes) <= 20),
  updated_at timestamptz not null default now());
create table public.family_goals (id uuid primary key default gen_random_uuid(), family_id uuid, target_amount double precision default 0.0,
  current_amount double precision default 0.0, month_year text, reward_suggestion text, created_at timestamptz default now());
create table public.family_financial_challenges (id uuid primary key default gen_random_uuid(), family_id uuid not null references public.family_groups(id) on delete cascade,
  challenge_type text not null default 'monthly', title text not null, description text, target_amount numeric not null default 0,
  reward_amount numeric not null default 0, start_date timestamptz, end_date timestamptz, is_active boolean not null default true,
  created_at timestamptz default now(),
  season_key text check (season_key is null or season_key ~ '^[a-z0-9_]{2,40}$'),
  badge text check (badge is null or char_length(badge) between 1 and 16));
create table public.seasonal_events (id uuid primary key default gen_random_uuid(), slug text);
create table public.sinking_funds (id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.family_groups(id) on delete cascade,
  event_id uuid references public.seasonal_events(id) on delete set null, name text not null, target_amount numeric not null default 0,
  current_amount numeric not null default 0, target_date timestamptz, created_by uuid references auth.users(id) on delete set null,
  is_active boolean not null default true, created_at timestamptz default now());

create or replace function public.zad_is_minor_user(p_who uuid)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select p_who is not null and (
    exists (select 1 from public.family_members where user_id = p_who and role = 'child')
    or exists (select 1 from public.zad_household_members
                where linked_user_id = p_who and kind = 'child' and archived_at is null));
$$;
revoke all on function public.zad_is_minor_user(uuid) from public, anon, authenticated;

-- The door logs every refusal here (20261121180000_commit_intent, trimmed to its columns).
create table public.zad_guard_events (id bigserial primary key, user_id uuid not null references auth.users(id) on delete cascade,
  kind text not null, reason text not null, source text, intent jsonb not null, created_at timestamptz not null default now());
