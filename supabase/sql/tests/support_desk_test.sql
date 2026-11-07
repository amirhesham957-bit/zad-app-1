-- مكتب الدعم (20261107123000). Scratch database only:
--   psql < supabase/sql/tests/support_desk_test.sql
-- Proves: lookup by id or email (login or ticket contact), nothing financial in the answer, every
-- lookup and renewal logged, renewal through zad_set_tier from the current expiry, limits enforced.

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then create role anon; end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then create role authenticated; end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then create role service_role; end if;
end $$;

create schema if not exists auth;
create table if not exists auth.users (id uuid primary key, email text);
create table if not exists public.zad_users (id uuid primary key, country text, created_at timestamptz default now());
create table if not exists public.zad_entitlements (
  user_id uuid primary key, tier text, tier_expires_at timestamptz, chat_left int, scan_left int);
create table if not exists public.zad_tiers (tier text primary key, sort_order int);
insert into zad_tiers values ('free', 0), ('starter', 1), ('plus', 2), ('pro', 3) on conflict do nothing;
create table if not exists public.zad_product_events (user_id uuid, name text, at timestamptz default now());
create table if not exists public.telegram_bindings (user_id uuid, bound_at timestamptz);
create table if not exists public.zad_brain_runs (user_id uuid, status text, error text, started_at timestamptz default now());
create table if not exists public.zad_support_tickets (
  user_id uuid, contact_email text, subject text, status text, created_at timestamptz default now());
create table if not exists public.zad_transactions (user_id uuid, amount numeric, merchant_name text);
create table if not exists public._set_tier (p_user uuid, p_tier text, p_expires timestamptz);
create or replace function public.zad_set_tier(p_user uuid, p_tier text, p_expires timestamptz default null)
  returns jsonb language sql as
  $$ insert into public._set_tier values (p_user, p_tier, p_expires) returning jsonb_build_object('ok', true, 'applied', true) $$;
create or replace function public.zad_problem_kind(p text) returns text language sql immutable as
  $$ select case when p ~* 'gemini' then 'الذكاء مش متاح' else 'تانية' end $$;

\i supabase/migrations/20261107123000_support_desk.sql

do $$
declare
  u constant uuid := '11111111-1111-4111-8111-111111111111';
  other constant uuid := '22222222-2222-4222-8222-222222222222';
  r jsonb;
begin
  insert into zad_users values (u, 'EG'), (other, 'SA');
  insert into auth.users values (u, 'Owner@Zad.app');
  insert into zad_support_tickets values (other, 'help@x.com', 'البنك', 'open');
  insert into zad_entitlements values (u, 'pro', now() + interval '10 days', 5, 2);
  insert into zad_product_events values (u, 'app_open'), (u, 'bank.off');
  insert into zad_brain_runs values (u, 'failed', 'Error: every gemini model unavailable');
  insert into zad_transactions values (u, 999, 'كارفور');

  r := public.zad_support_lookup(-100, u::text);
  assert r ->> 'found' = 'true' and r ->> 'tier' = 'pro' and r ->> 'bank_last' = 'bank.off', 'by id: ' || r::text;
  assert r -> 'brain_failed_7d' ->> 'الذكاء مش متاح' = '1', 'failures by kind';
  assert position('999' in r::text) = 0 and position('كارفور' in r::text) = 0, 'nothing financial: ' || r::text;

  assert public.zad_support_lookup(-100, ' owner@zad.APP ') ->> 'user_id' = u::text, 'by login email, any case';
  assert public.zad_support_lookup(-100, 'help@x.com') ->> 'user_id' = other::text, 'by a ticket contact email';
  assert public.zad_support_lookup(-100, 'nobody') ->> 'found' = 'false', 'not found';
  assert (select count(*) from zad_support_access_log where action = 'lookup') = 4, 'every lookup logged';

  -- Renewal: from the current expiry (pro until +10 days) ⇒ +40 days, through zad_set_tier.
  r := public.zad_support_extend(-100, u, 30);
  assert r ->> 'ok' = 'true' and r ->> 'tier' = 'pro', 'renewed: ' || r::text;
  assert (select p_expires from _set_tier) between now() + interval '39 days' and now() + interval '41 days', 'from the expiry';
  -- A free account gets pro from now.
  r := public.zad_support_extend(-100, other, 7);
  assert (select p_tier from _set_tier where p_user = other) = 'pro', 'free ⇒ pro';
  -- Limits.
  assert public.zad_support_extend(-100, u, 0) ->> 'reason' = 'days_1_to_90';
  assert public.zad_support_extend(-100, u, 91) ->> 'reason' = 'days_1_to_90';
  assert public.zad_support_extend(-100, u, 5, 'free') ->> 'reason' = 'unknown_tier';
  assert public.zad_support_extend(-100, gen_random_uuid(), 5) ->> 'reason' = 'no_such_user';
  assert (select count(*) from zad_support_access_log where action = 'extend') = 2, 'each renewal logged';
  raise notice 'support desk: ok';
end $$;
