-- zad_entitlement_refresh (20261012010000): the free balance comes back to 5 every
-- 5 hours, never stacks above 5, and paid tiers stay monthly. Scratch only:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/free_refill_five_hours_test.sql

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

-- The live shapes (information_schema, 2026-10-11).
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
insert into public.zad_tiers values
  ('free', 5, 15, 90, -1, false, true, 0), ('plus', 50, 100, 500, -1, true, false, 2)
on conflict do nothing;

\i supabase/migrations/20261012010000_free_refill_five_hours.sql

begin;
do $$
declare
  free_u uuid := gen_random_uuid(); paid_u uuid := gen_random_uuid(); lapsed_u uuid := gen_random_uuid();
  e public.zad_entitlements;
begin
  -- A free customer whose cycle ended, holding more than 5 from ads: back to exactly 5.
  insert into zad_entitlements (user_id, chat_left, cycle_reset_at) values (free_u, 9, now() - interval '1 minute');
  e := zad_entitlement_refresh(free_u);
  assert e.chat_left = 5, format('free refill gave %s, not 5', e.chat_left);
  assert e.cycle_reset_at between now() + interval '5 hours' - interval '1 second'
                              and now() + interval '5 hours' + interval '1 second',
    format('next refill at %s, not in 5 hours', e.cycle_reset_at);

  -- Inside the window nothing refills: spend 3, refresh, still 2.
  update zad_entitlements set chat_left = 2 where user_id = free_u;
  e := zad_entitlement_refresh(free_u);
  assert e.chat_left = 2, format('refilled inside the window: %s', e.chat_left);

  -- Paid tiers keep the monthly cycle.
  insert into zad_entitlements (user_id, tier, tier_expires_at, cycle_reset_at)
    values (paid_u, 'plus', now() + interval '20 days', now() - interval '1 minute');
  e := zad_entitlement_refresh(paid_u);
  assert e.chat_left = 500 and e.brain_left = 50, 'paid tier did not get its monthly allowance';
  assert e.cycle_reset_at > now() + interval '27 days', 'paid tier is not on a monthly cycle';

  -- A lapsed subscription drops to free and gets the free 5-hour refill at once.
  insert into zad_entitlements (user_id, tier, tier_expires_at, chat_left, cycle_reset_at)
    values (lapsed_u, 'plus', now() - interval '1 hour', 300, now() + interval '10 days');
  e := zad_entitlement_refresh(lapsed_u);
  assert e.tier = 'free' and e.chat_left = 5, format('lapsed: tier %s, chat %s', e.tier, e.chat_left);
  assert e.cycle_reset_at < now() + interval '5 hours 1 second', 'lapsed customer waits a month';

  assert not has_function_privilege('authenticated', 'public.zad_entitlement_refresh(uuid)', 'execute'),
    'customers can call the refresh directly';
  assert not has_function_privilege('anon', 'public.zad_entitlement_refresh(uuid)', 'execute'),
    'anon can call the refresh directly';
end $$;
rollback;

\echo free_refill_five_hours_test: ok
