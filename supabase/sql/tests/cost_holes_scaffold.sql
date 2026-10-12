-- Scratch shape for cost_holes_test.sql (migration 20261012090000). Scratch database only:
--
--   docker run -d --name zadpg -e POSTGRES_PASSWORD=pg postgres:17-alpine
--   psql() { docker exec -i zadpg psql -U postgres -v ON_ERROR_STOP=1 -q; }
--   psql < supabase/sql/tests/cost_holes_scaffold.sql
--   psql < supabase/migrations/20261012010000_free_refill_five_hours.sql
--   psql < supabase/migrations/20261012020000_one_attempts_balance.sql
--   psql < supabase/migrations/20261012090000_close_cost_holes.sql
--   psql < supabase/sql/tests/cost_holes_test.sql
--
-- Tables as live on 2026-10-12 (information_schema, read-only). The two ad grants are
-- stand-ins with the live grants (authenticated could execute both): the test is about
-- who may call them, not what they do.

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then create role anon nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then create role authenticated nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then create role service_role nologin bypassrls; end if;
end $$;
create schema if not exists auth;
create table if not exists auth.users (id uuid primary key);
create or replace function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claims', true)::jsonb ->> 'sub', '')::uuid $$;
create or replace function auth.role() returns text language sql stable as $$
  select current_setting('request.jwt.claims', true)::jsonb ->> 'role' $$;
grant usage on schema auth to anon, authenticated, service_role;
grant usage on schema public to anon, authenticated, service_role;
-- Supabase's own default: a new function is executable by anon and authenticated.
alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public grant all on functions to anon, authenticated, service_role;

create table public.zad_tiers (
  tier text primary key, brain_monthly int not null, scan_monthly int not null, chat_monthly int not null,
  voice_monthly int not null, telegram_media boolean not null default false, ads_enabled boolean not null default true,
  sort_order int not null default 0);
insert into public.zad_tiers values
  ('free', 0, 0, 5, -1, false, true, 0), ('starter', 0, 0, 300, -1, false, false, 1),
  ('plus', 0, 0, 1000, -1, false, false, 2), ('pro', 0, 0, 2500, -1, true, false, 3);

create table public.zad_entitlements (
  user_id uuid primary key, tier text not null default 'free', tier_expires_at timestamptz,
  brain_left int not null default 0, scan_left int not null default 0, chat_left int not null default 0,
  voice_left int not null default 0, cycle_reset_at timestamptz not null default now(),
  last_free_brain_at timestamptz, ad_watch_count int not null default 0, brain_session_expires_at timestamptz,
  updated_at timestamptz not null default now(), media_pass_expires_at timestamptz, purchase_token text);

create table public.zad_ad_grants (id bigserial primary key, user_id uuid not null, granted_at timestamptz not null default now());

create or replace function public.zad_week_start(p_at timestamptz, p_tz text default 'UTC')
returns timestamptz language sql immutable set search_path = public as $$
  select (date_trunc('day', (p_at at time zone p_tz))
          - make_interval(days => ((extract(isodow from (p_at at time zone p_tz))::int + 1) % 7)))
         at time zone p_tz;
$$;

create or replace function public.zad_ad_reward_grant(p_user uuid default null)
returns jsonb language sql security definer set search_path = public as $$ select '{"granted":true}'::jsonb $$;
create or replace function public.zad_media_pass_grant(p_user uuid default null)
returns jsonb language sql security definer set search_path = public as $$ select '{"granted":true}'::jsonb $$;
grant execute on function public.zad_ad_reward_grant(uuid) to authenticated, service_role;
grant execute on function public.zad_media_pass_grant(uuid) to authenticated, service_role;

insert into auth.users values ('00000000-0000-0000-0000-00000000000a'), ('00000000-0000-0000-0000-00000000000b');
