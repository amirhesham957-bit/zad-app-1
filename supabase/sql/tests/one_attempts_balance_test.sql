-- One «محاولات» balance (20261012020000): chat 1, scan 2, brain 3, voice free; the
-- owner's plans 300 / 1000 / 2500; no «unlimited»; the weekly free consultation stays
-- a gift. Runs on top of the 5-hour refill. Scratch only:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/one_attempts_balance_test.sql

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

-- Live shapes and rows (2026-10-11).
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
  ('free', 5, 15, 90, -1, false, true, 0), ('starter', 15, 30, 150, -1, true, false, 1),
  ('plus', 50, 100, 500, -1, true, false, 2), ('pro', 150, 300, -1, -1, true, false, 3)
on conflict do nothing;
create or replace function public.zad_week_start(p_at timestamptz, p_tz text default 'UTC')
returns timestamptz language sql immutable set search_path to 'public' as $$
  select (date_trunc('day', (p_at at time zone p_tz))
          - make_interval(days => ((extract(isodow from (p_at at time zone p_tz))::int + 1) % 7)))
         at time zone p_tz; $$;

-- An existing «unlimited» pro subscriber, as on live: chat_left 0.
insert into public.zad_entitlements (user_id, tier, tier_expires_at, chat_left, cycle_reset_at)
  values ('00000000-0000-0000-0000-0000000000aa', 'pro', now() + interval '20 days', 0, now() + interval '20 days');

\i supabase/migrations/20261012010000_free_refill_five_hours.sql
\i supabase/migrations/20261012020000_one_attempts_balance.sql

begin;
do $$
declare
  u uuid := gen_random_uuid(); p uuid := gen_random_uuid(); d jsonb; e public.zad_entitlements;
begin
  -- The plans.
  assert (select chat_monthly from zad_tiers where tier = 'starter') = 300, 'basic is not 300';
  assert (select chat_monthly from zad_tiers where tier = 'plus') = 1000, 'plus is not 1000';
  assert (select chat_monthly from zad_tiers where tier = 'pro') = 2500, 'family is not 2500';
  assert not exists (select 1 from zad_tiers where chat_monthly < 0), 'a tier is still unlimited';

  -- The existing pro subscriber is not locked out until next month.
  assert (select chat_left from zad_entitlements where user_id = '00000000-0000-0000-0000-0000000000aa') = 2500,
    'the existing pro subscriber kept a zero balance';

  -- Free: 5 attempts. brain costs 3, chat 1, scan 2.
  insert into zad_entitlements (user_id, cycle_reset_at, last_free_brain_at) values (u, now() - interval '1 minute', now());
  d := zad_entitlement_consume(u, 'brain');
  assert (d->>'allowed')::bool and (d->>'left')::int = 2 and (d->>'cost')::int = 3, format('brain: %s', d);
  d := zad_entitlement_consume(u, 'chat');
  assert (d->>'allowed')::bool and (d->>'left')::int = 1, format('chat: %s', d);
  -- 1 left, a scan costs 2: refused, balance untouched, told when it refills.
  d := zad_entitlement_consume(u, 'scan');
  assert not (d->>'allowed')::bool and d->>'reason' = 'needs_ads_or_upgrade', format('scan with 1 left: %s', d);
  assert (d->>'left')::int = 1 and (d->>'cost')::int = 2 and d ? 'cycle_reset_at', format('refusal shape: %s', d);
  assert (select chat_left from zad_entitlements where user_id = u) = 1, 'a refused scan spent attempts';
  -- Voice stays free.
  d := zad_entitlement_consume(u, 'voice');
  assert (d->>'allowed')::bool and d->>'reason' = 'unlimited', format('voice: %s', d);
  assert (select chat_left from zad_entitlements where user_id = u) = 1, 'voice spent attempts';

  -- Weekly consultation is a gift once the balance cannot pay for a brain call.
  update zad_entitlements set last_free_brain_at = null where user_id = u;
  d := zad_entitlement_consume(u, 'brain');
  assert (d->>'allowed')::bool and d->>'reason' = 'weekly_free', format('weekly gift: %s', d);
  assert (select chat_left from zad_entitlements where user_id = u) = 1, 'the gift spent attempts';
  d := zad_entitlement_consume(u, 'brain');
  assert not (d->>'allowed')::bool and d ? 'next_weekly_free_at', format('second brain: %s', d);

  -- Paid: buys spend the same balance; empty = quota_exhausted.
  insert into zad_entitlements (user_id, tier, tier_expires_at, chat_left, cycle_reset_at)
    values (p, 'starter', now() + interval '20 days', 3, now() + interval '20 days');
  d := zad_entitlement_consume(p, 'brain');
  assert (d->>'allowed')::bool and (d->>'left')::int = 0, format('paid brain: %s', d);
  d := zad_entitlement_consume(p, 'chat');
  assert not (d->>'allowed')::bool and d->>'reason' = 'quota_exhausted', format('paid empty: %s', d);

  -- Status reports the one balance.
  perform set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  d := zad_entitlement_status();
  assert (d->>'attempts_left')::int = 1 and (d->>'attempts_per_cycle')::int = 5, format('status: %s', d);
  assert (d->'costs'->>'brain')::int = 3 and d ? 'next_refill_at', format('status costs: %s', d);
  assert not (d->>'brain_available')::bool, 'brain shown available with 1 attempt and no gift';
  perform set_config('request.jwt.claims', '', true);

  assert not has_function_privilege('authenticated', 'public.zad_entitlement_consume(uuid,text,text)', 'execute'),
    'customers can spend attempts directly';
  assert has_function_privilege('authenticated', 'public.zad_entitlement_status(uuid,text)', 'execute'),
    'customers cannot read their balance';
end $$;
rollback;

\echo one_attempts_balance_test: ok
