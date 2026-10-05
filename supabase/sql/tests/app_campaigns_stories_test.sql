-- «حكايات زاد» (migration 20261005160000), on a scratch database:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/migrations/20261004120000_app_campaigns.sql
--   psql < supabase/migrations/20261005100000_app_campaigns_event_name.sql
--   psql < supabase/migrations/20261005160000_app_campaigns_stories.sql
--   psql < supabase/sql/tests/app_campaigns_stories_test.sql

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

create or replace function pg_temp.check(cond boolean, label text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAIL: %', label; end if; raise notice 'ok: %', label; end $$;

-- 1. The seeded occasions have stories, in both copies; the national days do not.
select pg_temp.check((select count(*) from public.app_campaigns where jsonb_array_length(story_slides) > 0) = 10,
  'ten campaigns carry stories');
select pg_temp.check((select jsonb_array_length(story_slides) from public.app_campaigns
  where event_key = 'white_friday' and dialect = 'GULF') = 4, 'White Friday, Gulf copy: four slides');
select pg_temp.check(not exists (select 1 from public.app_campaigns, jsonb_array_elements(story_slides) e
  where coalesce(e->>'emoji', '') = '' or coalesce(e->>'text', '') = ''), 'every slide has an emoji and a line');
select pg_temp.check((select story_slides from public.app_campaigns where event_key = 'egypt_october_6') = '[]'::jsonb,
  'a campaign without stories is an empty array');

-- 2. A dashboard edit survives a re-run.
update public.app_campaigns set story_slides = '[{"emoji":"✏️","text":"من اللوحة"}]' where event_key = 'ramadan' and dialect is null;
\i supabase/migrations/20261005160000_app_campaigns_stories.sql
select pg_temp.check((select story_slides->0->>'text' from public.app_campaigns where event_key = 'ramadan' and dialect is null)
  = 'من اللوحة', 're-applying keeps a dashboard edit');

-- 3. The shape is enforced.
do $$ begin
  update public.app_campaigns set story_slides = '{"emoji":"x"}' where event_key = 'halloween' and dialect is null;
  raise exception 'FAIL: stored an object';
exception when check_violation then raise notice 'ok: an array, not an object'; end $$;
do $$ begin
  update public.app_campaigns set story_slides = (select jsonb_agg(jsonb_build_object('emoji','x','text','y')) from generate_series(1,7))
    where event_key = 'halloween' and dialect is null;
  raise exception 'FAIL: stored seven slides';
exception when check_violation then raise notice 'ok: at most six slides'; end $$;
