-- كل ٣ إعلانات = محاولة واحدة (20261028010000_three_ads_one_attempt): الإعلان الأول والتاني صفر،
-- التالت +١، ولحد ٩ في اليوم = ٣ محاولات؛ والمعاينة بتقول نفس اللي المنحة بتعمله.
--
--   docker run -d --name zadpg -e POSTGRES_PASSWORD=pg postgres:17-alpine
--   psql() { docker exec -i -w /work zadpg psql -U postgres -v ON_ERROR_STOP=1 -q; }
--   docker cp supabase zadpg:/work/
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/three_ads_one_attempt_test.sql

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
insert into public.zad_tiers values ('free', 0, 0, 5, -1, false, true, 0) on conflict do nothing;

\i supabase/migrations/20261012010000_free_refill_five_hours.sql
\i supabase/migrations/20261012050000_ad_reward_by_country.sql
\i supabase/migrations/20261012100000_ad_attempts_survive_refill.sql
\i supabase/migrations/20261013120000_ad_reward_preview.sql
\i supabase/migrations/20261028010000_three_ads_one_attempt.sql

create or replace function pg_temp.as_user(uid uuid) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, false) $$;
create or replace function pg_temp.as_service() returns void language sql as $$
  select set_config('request.jwt.claims', '{"role":"service_role"}', false) $$;

begin;
do $$
declare
  sa uuid := gen_random_uuid();
  p jsonb; g jsonb; before int; got int[] := '{}';
begin
  insert into auth.users (id) values (sa);
  insert into zad_users (id, country) values (sa, 'SA');
  insert into zad_entitlements (user_id, chat_left, cycle_reset_at) values (sa, 5, now() + interval '4 hours');

  assert not exists (select 1 from zad_ad_reward_rates where per_ad <> 0 or box_bonus <> 1),
    'every country: 0 per ad, 1 on the third';

  -- Nine ads: rewards 0,0,1 three times; the preview agrees every time.
  for i in 1..9 loop
    perform pg_temp.as_service();
    update zad_ad_grants set granted_at = granted_at - interval '2 minutes' where user_id = sa;
    perform pg_temp.as_user(sa);
    p := zad_ad_reward_preview();
    assert (p->>'available')::boolean and (p->>'daily_cap')::int = 9, format('ad %s: %s', i, p);
    perform pg_temp.as_service();
    g := zad_ad_reward_grant(sa);
    assert (g->>'granted')::boolean, format('ad %s refused: %s', i, g);
    assert (g->>'reward')::int = (p->>'reward')::int + case when (p->>'box_next')::boolean then (p->>'box_bonus')::int else 0 end,
      format('ad %s: preview %s, grant %s', i, p, g);
    got := got || (g->>'reward')::int;
  end loop;
  assert got = array[0,0,1,0,0,1,0,0,1], format('rewards: %s', got);
  select chat_left into before from zad_entitlements where user_id = sa;
  assert before = 5 + 3, format('chat_left after nine ads: %s', before);

  -- The tenth: refused by both.
  update zad_ad_grants set granted_at = granted_at - interval '2 minutes' where user_id = sa;
  perform pg_temp.as_user(sa);
  p := zad_ad_reward_preview();
  assert not (p->>'available')::boolean and p->>'reason' = 'daily_ad_cap', format('cap: %s', p);
  perform pg_temp.as_service();
  assert zad_ad_reward_grant(sa)->>'reason' = 'daily_ad_cap', 'the grant gave a tenth ad';
end $$;
rollback;

\echo three_ads_one_attempt_test: ok
