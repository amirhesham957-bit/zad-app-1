-- الحصة المجانية كل ساعتين لكل نوع وسلّم الإعلانات (20261110210000_two_hour_quota_ad_ladder):
-- ٢٠ رسالة و٣ صوت و٢ صورة، كل نوع لوحده؛ الإعلان ١ = ٥ رسايل، ٢ = صوت + ٥، ٣ = صوت + صورة + ٥،
-- وبعد كده ٣ رسايل، ولحد ٩ في اليوم؛ المكسوب من إعلان بيفضل بعد التجديد؛ والمدفوع زي ما هو.
--
--   docker run -d --name zadpg -e POSTGRES_PASSWORD=pg postgres:17-alpine
--   psql() { docker exec -i -w /work zadpg psql -U postgres -v ON_ERROR_STOP=1 -q; }
--   docker cp supabase zadpg:/work/
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/two_hour_quota_ad_ladder_test.sql

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

create or replace function public.zad_week_start(p_at timestamptz, p_tz text) returns timestamptz
language sql stable as $$ select date_trunc('week', p_at at time zone p_tz) at time zone p_tz $$;

\i supabase/migrations/20261012010000_free_refill_five_hours.sql
\i supabase/migrations/20261012020000_one_attempts_balance.sql
\i supabase/migrations/20261012050000_ad_reward_by_country.sql
\i supabase/migrations/20261012100000_ad_attempts_survive_refill.sql
\i supabase/migrations/20261013120000_ad_reward_preview.sql
\i supabase/migrations/20261028010000_three_ads_one_attempt.sql
\i supabase/migrations/20261028020000_three_voice_questions_a_day.sql
\i supabase/migrations/20261103230000_free_voice_six.sql
\i supabase/migrations/20261110210000_two_hour_quota_ad_ladder.sql

create or replace function pg_temp.as_user(uid uuid) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, false) $$;
create or replace function pg_temp.as_service() returns void language sql as $$
  select set_config('request.jwt.claims', '{"role":"service_role"}', false) $$;

begin;
do $$
declare
  u uuid := gen_random_uuid();
  paid uuid := gen_random_uuid();
  kid uuid := gen_random_uuid();
  s jsonb; c jsonb; p jsonb; g jsonb;
  e zad_entitlements;
  got text[] := '{}';
begin
  insert into auth.users (id) values (u), (paid), (kid);
  -- An old free row mid five-hour cycle: the migration's last line restarts it.
  insert into zad_entitlements (user_id, chat_left, cycle_reset_at) values (u, 2, now() + interval '4 hours');
  insert into zad_entitlements (user_id, tier, chat_left, cycle_reset_at)
    values (paid, 'plus', 1000, now() + interval '20 days');
  update zad_entitlements set cycle_reset_at = now() where user_id = u;  -- as the migration does for live rows

  -- A fresh cycle: 20 / 3 / 2, two hours long.
  perform pg_temp.as_service();
  s := zad_entitlement_status(u);
  assert (s->>'attempts_left')::int = 20 and (s->>'attempts_per_cycle')::int = 20, format('messages: %s', s);
  assert (s->>'voice_free_left')::int = 3 and (s->>'images_left')::int = 2, format('voice/images: %s', s);
  assert (s->>'next_refill_at')::timestamptz between now() + interval '119 minutes' and now() + interval '121 minutes',
    format('two hours: %s', s->>'next_refill_at');

  -- An image no longer eats messages; a third image in the cycle is refused.
  assert (zad_entitlement_consume(u, 'scan')->>'allowed')::boolean, 'image 1';
  assert (zad_entitlement_consume(u, 'scan')->>'allowed')::boolean, 'image 2';
  c := zad_entitlement_consume(u, 'scan');
  assert not (c->>'allowed')::boolean and c->>'reason' = 'image_cycle_cap', format('image 3: %s', c);
  select * into e from zad_entitlements where user_id = u;
  assert e.chat_left = 20 and e.scan_left = 0, format('after images: %s', row_to_json(e));

  -- Voice: three, then refused; a refund gives one back.
  for i in 1..3 loop
    assert (zad_entitlement_consume(u, 'voice')->>'allowed')::boolean, format('voice %s', i);
  end loop;
  c := zad_entitlement_consume(u, 'voice');
  assert c->>'reason' = 'voice_cycle_cap', format('voice 4: %s', c);
  perform zad_entitlement_refund(u, 'voice');
  perform zad_entitlement_refund(u, 'scan');
  select * into e from zad_entitlements where user_id = u;
  assert e.voice_left = 1 and e.scan_left = 1, format('refunds: %s', row_to_json(e));

  -- Messages: chat 1, brain 3, from the twenty.
  perform zad_entitlement_consume(u, 'chat');
  perform zad_entitlement_consume(u, 'brain');
  assert (select chat_left from zad_entitlements where user_id = u) = 16, 'chat 1 + brain 3';

  -- The ladder: nine ads, the preview always agreeing with the grant.
  for i in 1..9 loop
    update zad_ad_grants set granted_at = granted_at - interval '2 minutes' where user_id = u;
    perform pg_temp.as_user(u);
    p := zad_ad_reward_preview();
    perform pg_temp.as_service();
    g := zad_ad_reward_grant(u);
    assert (g->>'granted')::boolean, format('ad %s: %s', i, g);
    assert g->>'reward' = p->>'reward' and g->>'reward_voice' = p->>'reward_voice'
       and g->>'reward_images' = p->>'reward_images', format('ad %s: preview %s grant %s', i, p, g);
    got := got || format('%s/%s/%s', g->>'reward', g->>'reward_voice', g->>'reward_images');
  end loop;
  assert got = array['5/0/0','5/1/0','5/1/1','3/0/0','3/0/0','3/0/0','3/0/0','3/0/0','3/0/0'], format('ladder: %s', got);
  select * into e from zad_entitlements where user_id = u;
  assert e.chat_left = 16 + 33 and e.voice_left = 1 + 2 and e.scan_left = 1 + 1, format('after ads: %s', row_to_json(e));
  update zad_ad_grants set granted_at = granted_at - interval '2 minutes' where user_id = u;
  assert zad_ad_reward_grant(u)->>'reason' = 'daily_ad_cap', 'a tenth ad';

  -- The refill: the cycle's own back, ad-earned kept on top, kind by kind.
  update zad_entitlements set cycle_reset_at = now() - interval '1 second' where user_id = u;
  perform zad_entitlement_consume(u, 'chat');
  select * into e from zad_entitlements where user_id = u;
  assert e.chat_left = 20 + 33 - 1 and e.voice_left = 3 + 2 and e.scan_left = 2 + 1,
    format('refill keeps ad-earned: %s', row_to_json(e));

  -- Paid: untouched — scans still cost two from the monthly balance, voice unlimited.
  c := zad_entitlement_consume(paid, 'scan');
  assert (c->>'allowed')::boolean and (c->>'left')::int = 998, format('paid scan: %s', c);
  assert zad_entitlement_consume(paid, 'voice')->>'reason' = 'unlimited', 'paid voice';
  s := zad_entitlement_status(paid);
  assert s->'images_left' = 'null'::jsonb and (s->>'ads_enabled')::boolean = false, format('paid status: %s', s);

  -- A child: no ads at all.
  insert into family_groups (id) values (kid);
  insert into family_members (family_id, user_id, role) values (kid, kid, 'child');
  assert zad_ad_reward_grant(kid)->>'reason' = 'kids_no_ads', 'kid granted';
end $$;
rollback;

\echo two_hour_quota_ad_ladder_test: ok
