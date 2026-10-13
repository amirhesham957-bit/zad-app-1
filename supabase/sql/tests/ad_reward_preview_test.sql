-- zad_ad_reward_preview (20261013120000) says what zad_ad_reward_grant will do, before the ad:
--
--   docker run -d --name zadpg -e POSTGRES_PASSWORD=pg postgres:16
--   psql() { docker exec -i -w /work zadpg psql -U postgres -v ON_ERROR_STOP=1 -q; }
--   docker cp supabase zadpg:/work/
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/ad_reward_preview_test.sql

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

create or replace function pg_temp.as_user(uid uuid) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, false) $$;
create or replace function pg_temp.as_service() returns void language sql as $$
  select set_config('request.jwt.claims', '{"role":"service_role"}', false) $$;

begin;
do $$
declare
  eg uuid := gen_random_uuid(); kid uuid := gen_random_uuid(); fam uuid := gen_random_uuid();
  p jsonb; g jsonb;
begin
  insert into auth.users (id) values (eg), (kid);
  insert into zad_users (id, country) values (eg, 'EG');
  insert into zad_entitlements (user_id, chat_left, cycle_reset_at) values (eg, 5, now() + interval '4 hours');

  -- Before any ad: available now, +2 in Egypt, no box yet.
  perform pg_temp.as_user(eg);
  p := zad_ad_reward_preview();
  assert (p->>'available')::boolean and (p->>'reward')::int = 2 and (p->>'wait_seconds')::int = 0
     and not (p->>'box_next')::boolean, format('fresh: %s', p);

  -- Each of the ten: the preview's reward and box match what the grant then gives.
  for i in 1..10 loop
    perform pg_temp.as_service();
    update zad_ad_grants set granted_at = granted_at - interval '2 minutes' where user_id = eg;
    perform pg_temp.as_user(eg);
    p := zad_ad_reward_preview();
    assert (p->>'available')::boolean, format('ad %s not available: %s', i, p);
    perform pg_temp.as_service();
    g := zad_ad_reward_grant(eg);
    assert (g->>'granted')::boolean, format('ad %s refused: %s', i, g);
    assert (g->>'reward')::int = (p->>'reward')::int + case when (p->>'box_next')::boolean then (p->>'box_bonus')::int else 0 end,
      format('ad %s: preview %s, grant %s', i, p, g);
    assert (g->>'box_opened')::boolean = (p->>'box_next')::boolean, format('ad %s box: %s / %s', i, p, g);
  end loop;

  -- Right after a grant it says how long to wait (the grant would answer too_fast).
  update zad_ad_grants set granted_at = now() - interval '10 seconds'
   where id = (select max(id) from zad_ad_grants where user_id = eg);
  delete from zad_ad_grants where id = (select min(id) from zad_ad_grants where user_id = eg);
  perform pg_temp.as_user(eg);
  p := zad_ad_reward_preview();
  assert (p->>'wait_seconds')::int between 49 and 50, format('wait: %s', p);
  perform pg_temp.as_service();
  assert zad_ad_reward_grant(eg)->>'reason' = 'too_fast', 'grant was not too_fast while the preview said wait';

  -- Ten today: not available, and the grant agrees.
  insert into zad_ad_grants (user_id, granted_at) values (eg, now() - interval '5 minutes');
  update zad_ad_grants set granted_at = granted_at - interval '2 minutes' where user_id = eg
     and granted_at > now() - interval '1 minute';
  perform pg_temp.as_user(eg);
  p := zad_ad_reward_preview();
  assert not (p->>'available')::boolean and p->>'reason' = 'daily_ad_cap', format('cap: %s', p);
  perform pg_temp.as_service();
  assert zad_ad_reward_grant(eg)->>'reason' = 'daily_ad_cap', 'grant disagrees on the cap';

  -- A child account: never.
  insert into family_groups (id) values (fam);
  insert into family_members (family_id, user_id, role) values (fam, kid, 'child');
  perform pg_temp.as_user(kid);
  p := zad_ad_reward_preview();
  assert not (p->>'available')::boolean and p->>'reason' = 'kids_no_ads', format('kid: %s', p);

  assert has_function_privilege('authenticated', 'public.zad_ad_reward_preview()', 'execute'), 'customers cannot ask';
  assert not has_function_privilege('anon', 'public.zad_ad_reward_preview()', 'execute'), 'anon can ask';
end $$;
rollback;

\echo ad_reward_preview_test: ok
