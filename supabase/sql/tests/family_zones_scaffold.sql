-- The live shapes (read off the project 2026-10-03) that migration
-- 20261003110000_child_zones_by_consent.sql builds on, for a scratch database
-- already set up by scratch_scaffold.sql. Run in this order:
--
--   docker run -d --name zadpg -e POSTGRES_PASSWORD=pg postgres:17-alpine
--   psql() { docker exec -i zadpg psql -U postgres -v ON_ERROR_STOP=1 -q; }
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/family_zones_scaffold.sql
--   psql < supabase/migrations/20261001130000_family_shares_by_consent.sql
--   psql < supabase/migrations/20261003110000_child_zones_by_consent.sql
--   psql < supabase/sql/tests/family_zones_test.sql

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

alter table public.zad_users add column if not exists country text;

create or replace function public.zad_market_timezone(p_country text) returns text
language sql immutable set search_path to 'public' as $$
  select case upper(coalesce(p_country, ''))
    when 'SA' then 'Asia/Riyadh' when 'EG' then 'Africa/Cairo' when 'AE' then 'Asia/Dubai'
    else 'Africa/Cairo' end;
$$;

create table if not exists public.zad_voice_moments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  moment text not null,
  facts jsonb not null default '{}'::jsonb,
  dedupe_key text not null,
  status text not null default 'pending',
  attempts int not null default 0,
  created_at timestamptz not null default now(),
  sent_at timestamptz,
  delivery jsonb,
  error text,
  claimed_at timestamptz,
  unique (user_id, dedupe_key)
);
alter table public.zad_voice_moments enable row level security;

-- What 20261001130000's functions read at run time; empty is enough here.
create table if not exists public.zad_pharmacy_doses (id uuid primary key default gen_random_uuid(), item_id uuid, scheduled_at timestamptz, status text);
create table if not exists public.zad_transactions (id uuid primary key default gen_random_uuid(), user_id uuid, amount numeric, category text, is_expense boolean, txn_kind text, created_at timestamptz default now());
create table if not exists public.zad_appointments (id uuid primary key default gen_random_uuid(), user_id uuid, title text, starts_at timestamptz, status text);
create table if not exists public.family_tasbiha (id uuid primary key default gen_random_uuid(), user_id uuid, family_id uuid, streak_days int);
alter table public.zad_users add column if not exists monthly_limit numeric;
