-- محاولات الإعلان بتعدّي تجديد الـ٥ ساعات (20261012100000) on a scratch database:
--
--   docker run -d --name zadpg -e POSTGRES_PASSWORD=pg postgres:16
--   psql() { docker exec -i -w /work zadpg psql -U postgres -v ON_ERROR_STOP=1 -q; }
--   docker cp supabase zadpg:/work/
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/ad_attempts_survive_refill_test.sql
--
-- The file loads the three migrations it needs itself (\i, paths from /work).

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

-- The live shapes (information_schema, 2026-10-12), before this migration's column.
create table if not exists public.zad_tiers (
  tier text primary key, brain_monthly int not null, scan_monthly int not null,
  chat_monthly int not null, voice_monthly int not null,
  telegram_media boolean not null default false, ads_enabled boolean not null default true,
  sort_order int not null default 0);
create table if not exists public.zad_entitlements (
  user_id uuid primary key, tier text not null default 'free', tier_expires_at timestamptz,
  brain_left int not null default 0, scan_left int not null default 0, chat_left int not null default 0,
  voice_left int not null default 0, cycle_reset_at timestamptz not null default now(),
  last_free_brain_at timestamptz, ad_watch_count int not null default 0,
  brain_session_expires_at timestamptz, updated_at timestamptz not null default now(),
  media_pass_expires_at timestamptz, purchase_token text);
create table if not exists public.zad_ad_grants (
  id bigint generated always as identity primary key, user_id uuid not null, granted_at timestamptz not null default now());
alter table public.zad_users add column if not exists country text;
insert into public.zad_tiers values
  ('free', 0, 0, 5, -1, false, true, 0), ('plus', 0, 0, 1000, -1, true, false, 2)
on conflict do nothing;

\i supabase/migrations/20261012010000_free_refill_five_hours.sql
\i supabase/migrations/20261012050000_ad_reward_by_country.sql
\i supabase/migrations/20261012100000_ad_attempts_survive_refill.sql

-- An ad watched through admob-ssv (service role), the 60-second gap stepped over.
create or replace function pg_temp.watch(uid uuid) returns jsonb language plpgsql as $$
begin
  perform set_config('request.jwt.claims', '{"role":"service_role"}', false);
  update public.zad_ad_grants set granted_at = granted_at - interval '2 minutes' where user_id = uid;
  return public.zad_ad_reward_grant(uid);
end $$;
-- The cycle ends now.
create or replace function pg_temp.cycle_ends(uid uuid) returns public.zad_entitlements language plpgsql as $$
begin
  update public.zad_entitlements set cycle_reset_at = now() - interval '1 minute' where user_id = uid;
  return public.zad_entitlement_refresh(uid);
end $$;
-- Spending, as zad_entitlement_consume does it: chat_left only.
create or replace function pg_temp.spend(uid uuid, n int) returns void language sql as $$
  update public.zad_entitlements set chat_left = chat_left - n where user_id = uid $$;

begin;
do $$
declare
  eg uuid := gen_random_uuid(); plain uuid := gen_random_uuid();
  lapsed uuid := gen_random_uuid(); paid uuid := gen_random_uuid();
  e public.zad_entitlements;
begin
  insert into auth.users (id) values (eg), (plain), (lapsed), (paid);
  insert into zad_users (id, country) values (eg, 'EG');

  -- A free customer with a fresh 5 watches three ads in Egypt: 2 + 2 + (2 + box 2) = 8.
  insert into zad_entitlements (user_id, chat_left, cycle_reset_at) values (eg, 5, now() + interval '4 hours');
  perform pg_temp.watch(eg); perform pg_temp.watch(eg); perform pg_temp.watch(eg);
  select * into e from zad_entitlements where user_id = eg;
  assert e.chat_left = 13 and e.ad_attempts_left = 8, format('after ads: %s / %s', e.chat_left, e.ad_attempts_left);

  -- The bug: 3 spent (from the free 5), the cycle ends — the 8 from ads must still be there.
  perform pg_temp.spend(eg, 3);
  e := pg_temp.cycle_ends(eg);
  assert e.chat_left = 13, format('refill kept %s, not 5 free + 8 from ads', e.chat_left);
  assert e.ad_attempts_left = 8, format('ad share %s after the refill', e.ad_attempts_left);

  -- Spending past the free 5 eats into the ad share; only what is left of it carries over.
  perform pg_temp.spend(eg, 10);
  e := pg_temp.cycle_ends(eg);
  assert e.chat_left = 8 and e.ad_attempts_left = 3, format('3 ad left: %s / %s', e.chat_left, e.ad_attempts_left);

  -- All spent: back to the free 5 and nothing more.
  perform pg_temp.spend(eg, 8);
  e := pg_temp.cycle_ends(eg);
  assert e.chat_left = 5 and e.ad_attempts_left = 0, format('all spent: %s / %s', e.chat_left, e.ad_attempts_left);

  -- Inside the window nothing changes.
  perform pg_temp.spend(eg, 2);
  e := zad_entitlement_refresh(eg);
  assert e.chat_left = 3, format('refilled inside the window: %s', e.chat_left);

  -- The free 5 alone still never stack: 4 left, no ads, refill gives 5.
  insert into zad_entitlements (user_id, chat_left, cycle_reset_at) values (plain, 4, now() - interval '1 minute');
  e := zad_entitlement_refresh(plain);
  assert e.chat_left = 5, format('free stacked: %s', e.chat_left);

  -- A lapsed subscription comes down to the free 5, whatever was left of the month.
  insert into zad_entitlements (user_id, tier, tier_expires_at, chat_left, ad_attempts_left, cycle_reset_at)
    values (lapsed, 'plus', now() - interval '1 hour', 300, 10, now() + interval '10 days');
  e := zad_entitlement_refresh(lapsed);
  assert e.tier = 'free' and e.chat_left = 5 and e.ad_attempts_left = 0,
    format('lapsed: %s %s / %s', e.tier, e.chat_left, e.ad_attempts_left);

  -- The monthly cycle of a paid plan clears the ad share.
  insert into zad_entitlements (user_id, tier, tier_expires_at, chat_left, ad_attempts_left, cycle_reset_at)
    values (paid, 'plus', now() + interval '20 days', 40, 6, now() - interval '1 minute');
  e := zad_entitlement_refresh(paid);
  assert e.chat_left = 1000 and e.ad_attempts_left = 0, format('paid: %s / %s', e.chat_left, e.ad_attempts_left);

  assert not has_function_privilege('authenticated', 'public.zad_entitlement_refresh(uuid)', 'execute'),
    'customers can call the refresh directly';
  assert not has_function_privilege('authenticated', 'public.zad_ad_reward_grant(uuid)', 'execute'),
    'customers can grant themselves an ad reward';
  assert not has_function_privilege('anon', 'public.zad_ad_reward_grant(uuid)', 'execute'),
    'anon can grant an ad reward';
end $$;
rollback;

\echo ad_attempts_survive_refill_test: ok
