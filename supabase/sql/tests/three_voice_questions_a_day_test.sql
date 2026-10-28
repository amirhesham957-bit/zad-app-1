-- ٣ أسئلة صوتية في اليوم للمجاني (20261028020000_three_voice_questions_a_day): التالت بيعدّي والرابع
-- لأ، التصريح القديم مابيعدّيش الحد، الإرجاع بيرجّع واحد، بكرة الحد بيرجع، والمدفوع من غير حد.
--
--   docker run -d --name zadpg -e POSTGRES_PASSWORD=pg postgres:17-alpine
--   psql() { docker exec -i -w /work zadpg psql -U postgres -v ON_ERROR_STOP=1 -q; }
--   docker cp supabase zadpg:/work/
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/three_voice_questions_a_day_test.sql

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

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
insert into public.zad_tiers values ('free', 0, 0, 5, -1, false, true, 0), ('plus', 0, 0, 1000, -1, true, false, 2)
  on conflict do nothing;

-- Live 2026-10-28: zad_week_start as 20260817010000 defines it.
create or replace function public.zad_week_start(p_at timestamptz, p_tz text) returns timestamptz
language sql stable as $$ select date_trunc('week', p_at at time zone p_tz) at time zone p_tz $$;

\i supabase/migrations/20261012010000_free_refill_five_hours.sql
\i supabase/migrations/20261012020000_one_attempts_balance.sql
\i supabase/migrations/20261012050000_ad_reward_by_country.sql
\i supabase/migrations/20261012100000_ad_attempts_survive_refill.sql
\i supabase/migrations/20261028020000_three_voice_questions_a_day.sql

begin;
do $$
declare
  free_u uuid := gen_random_uuid();
  paid_u uuid := gen_random_uuid();
  d jsonb;
  chat_before int;
begin
  insert into auth.users (id) values (free_u), (paid_u);
  insert into zad_entitlements (user_id, chat_left, cycle_reset_at, media_pass_expires_at)
    values (free_u, 5, now() + interval '4 hours', now() + interval '20 hours');
  insert into zad_entitlements (user_id, tier, chat_left, cycle_reset_at)
    values (paid_u, 'plus', 1000, now() + interval '20 days');

  assert (select voice_daily from zad_tiers where tier = 'free') = 3, 'free: 3 a day';
  assert (select voice_daily from zad_tiers where tier = 'plus') = -1, 'paid: no daily cap';

  -- Three questions pass, even with an old media pass; the attempts balance is untouched.
  for i in 1..3 loop
    d := zad_entitlement_consume(free_u, 'voice');
    assert (d->>'allowed')::boolean and d->>'reason' = 'quota', format('question %s: %s', i, d);
    assert (d->>'voice_left')::int = 3 - i, format('question %s left: %s', i, d);
  end loop;
  assert (select chat_left from zad_entitlements where user_id = free_u) = 5, 'voice spent chat attempts';

  -- The fourth is refused.
  d := zad_entitlement_consume(free_u, 'voice');
  assert not (d->>'allowed')::boolean and d->>'reason' = 'voice_daily_cap', format('fourth: %s', d);
  assert (d->>'voice_resets_at')::timestamptz = ((now() at time zone 'utc')::date + 1)::timestamp at time zone 'utc',
    format('resets: %s', d);

  -- A question that came back empty gives its try back.
  perform zad_entitlement_refund(free_u, 'voice');
  d := zad_entitlement_consume(free_u, 'voice');
  assert (d->>'allowed')::boolean, format('after refund: %s', d);
  assert not (zad_entitlement_consume(free_u, 'voice')->>'allowed')::boolean, 'refund gave more than one';

  -- The media pass still opens a scan.
  assert zad_entitlement_consume(free_u, 'scan')->>'reason' = 'media_pass', 'scan lost its pass';

  -- Tomorrow: three again.
  update zad_entitlements set voice_day = voice_day - 1 where user_id = free_u;
  d := zad_entitlement_consume(free_u, 'voice');
  assert (d->>'allowed')::boolean and (d->>'voice_left')::int = 2, format('next day: %s', d);

  -- Paid: unlimited, nothing counted.
  for i in 1..10 loop
    d := zad_entitlement_consume(paid_u, 'voice');
    assert (d->>'allowed')::boolean and d->>'reason' = 'unlimited', format('paid %s: %s', i, d);
  end loop;
  assert (select voice_day_count from zad_entitlements where user_id = paid_u) = 0, 'paid voice was counted';
end $$;
rollback;

\echo three_voice_questions_a_day_test: ok
