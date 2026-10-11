-- حارس الدورة وحارس القناة (20261011220000). Family: mom f001, dad f002 (fa001); neighbour f003.

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

-- 1. a healthy day: nothing broken, one quiet row in the health table
begin;
do $$
declare r jsonb;
begin
  r := zad_loop_guard();
  assert (r->>'receipt_without_prices')::int = 0 and (r->>'bought_not_ticked')::int = 0
     and (r->>'composed_then_wasted')::int = 0 and (r->>'stuck_tasks')::int = 0, r::text;
  assert (select bad_runs from zad_brain_health_alerts where kind = 'loop_break') = 0;
end $$;
rollback;

-- 2. each break is counted
begin;
-- a receipt with a shop and no report; another with its report (not counted)
insert into zad_transactions (user_id, source_type, merchant_name, created_at) values
  ('00000000-0000-0000-0000-00000000f001', 'receipt', 'كارفور', now() - interval '2 days'),
  ('00000000-0000-0000-0000-00000000f002', 'receipt', 'بنده', now() - interval '2 days');
insert into price_index (item_name, price, currency, user_id, source, store_name, "timestamp")
  values ('لبن', 30, 'EGP', '00000000-0000-0000-0000-00000000f002', 'crowdsource', 'بنده', now() - interval '1 day');
-- mom's open «جبنة» line; dad bought cheese after it was added
insert into zad_shopping_list (user_id, item_name, created_at) values
  ('00000000-0000-0000-0000-00000000f001', 'جبنة', now() - interval '1 day');
insert into zad_inventory_observations (user_id, item_name, qty, source, observed_at) values
  ('00000000-0000-0000-0000-00000000f002', 'الجبنه', 2, 'chat_add', now() - interval '2 hours');
-- the neighbour bought cheese too: not the family's line
insert into zad_inventory_observations (user_id, item_name, qty, source, observed_at) values
  ('00000000-0000-0000-0000-00000000f003', 'جبنة', 1, 'camera_ocr', now() - interval '1 hour');
-- a greeting composed and thrown away; a stuck task
insert into zad_voice_moments (user_id, moment, status, error) values
  ('00000000-0000-0000-0000-00000000f001', 'good_night', 'failed', 'no channel delivered');
insert into agent_tasks (user_id, kind, status, created_at) values
  ('00000000-0000-0000-0000-00000000f001', 'home_weekly_digest', 'pending', now() - interval '2 days');
do $$
declare r jsonb;
begin
  r := zad_loop_guard();
  assert (r->>'receipt_without_prices')::int = 1, r::text;
  assert (r->>'bought_not_ticked')::int = 1, r::text;
  assert (r->>'composed_then_wasted')::int = 1, r::text;
  assert (r->>'stuck_tasks')::int = 1, r::text;
  assert (select bad_runs from zad_brain_health_alerts where kind = 'loop_break') = 4;
  -- a second run the same day updates the one row
  perform zad_loop_guard();
  assert (select count(*) from zad_brain_health_alerts where kind = 'loop_break') = 1;
end $$;
rollback;

-- 3. the channel guardian: no token, no Telegram, a greeting held back ⇒ one in-app note a week
begin;
insert into zad_voice_moments (user_id, moment, status, error) values
  ('00000000-0000-0000-0000-00000000f001', 'morning_greeting', 'failed', 'no channel (not composed)'),
  ('00000000-0000-0000-0000-00000000f002', 'morning_greeting', 'failed', 'no channel (not composed)');
insert into telegram_bindings (user_id, chat_id, bound_at) values ('00000000-0000-0000-0000-00000000f002', 1, now());
do $$
declare r jsonb;
begin
  r := zad_loop_guard();
  assert (r->>'channel_nudges')::int = 1, r::text;
  assert (select count(*) from app_notifications where user_id = '00000000-0000-0000-0000-00000000f001'
            and title = 'زاد مش قادر يوصلك') = 1;
  assert not exists (select 1 from app_notifications where user_id = '00000000-0000-0000-0000-00000000f002'),
    'dad has Telegram — nothing to nudge';
  r := zad_loop_guard();
  assert (r->>'channel_nudges')::int = 0, 'nudged twice in a week';
end $$;
rollback;

\echo loop_guard_test: all checks passed
