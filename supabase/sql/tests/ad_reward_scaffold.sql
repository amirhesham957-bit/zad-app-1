-- On top of scratch_scaffold.sql: the live shapes zad_ad_reward_grant touches
-- (20261012050000). How to run: the top of ad_reward_by_country_test.sql.

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

-- The live shapes the grant touches.
alter table public.zad_users add column if not exists country text;
create table if not exists public.zad_ad_grants (
  id bigint generated always as identity primary key, user_id uuid not null, granted_at timestamptz not null default now());
create table if not exists public.zad_entitlements (
  user_id uuid primary key, tier text not null default 'free', chat_left int not null default 0,
  ad_watch_count int not null default 0, brain_session_expires_at timestamptz, updated_at timestamptz default now());
create or replace function public.zad_entitlement_refresh(p uuid) returns public.zad_entitlements
language plpgsql as $$ declare e public.zad_entitlements; begin
  insert into public.zad_entitlements (user_id) values (p) on conflict do nothing;
  select * into e from public.zad_entitlements where user_id = p; return e; end $$;

