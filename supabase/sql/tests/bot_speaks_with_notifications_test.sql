-- 20261123140000: every app notification of a bound user reaches the bot once; the writers that already push themselves do not double.
--   psql < scratch_scaffold.sql; psql < bot_speaks_scaffold.sql; psql < the migration; psql < this file
\set ON_ERROR_STOP on
do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;
begin;
do $$ declare
  a uuid := gen_random_uuid(); b uuid := gen_random_uuid(); n int; c record; nid uuid;
begin
  insert into auth.users (id) values (a), (b);
  insert into telegram_bindings (user_id, chat_id, bound_at) values (a, 111, now());   -- b is not bound

  -- Restock alert: service_role writer marked bot_push -> one bot call to notification_push with the notification id.
  perform set_config('request.jwt.claims', '{"role":"service_role"}', true);
  insert into app_notifications (user_id, title, message, bot_push) values (a, '🛒 ناقصك حاجة وقريبة منك', 'لبن عند محل قريب', true)
    returning id into nid;
  select count(*) into n from net.calls;
  assert n = 1, 'restock alert reaches the bot once, got ' || n;
  select * into c from net.calls;
  assert c.url like '%job=notification_push', 'goes through the gated job: ' || c.url;
  assert (c.body ->> 'notification_id')::uuid = nid and (c.body ->> 'user_id')::uuid = a, 'carries the id the bot dedupes on';
  assert c.body ->> 'body' not ilike '%اشترى%' and not (c.body ? 'source') and not (c.body ? 'buyer'), 'no who-bought/source in the payload';

  -- Brain writes (service_role, unmarked) already push by themselves: no second message.
  insert into app_notifications (user_id, title, message) values (a, 'تنبيه من المخ', 'x');
  select count(*) into n from net.calls;
  assert n = 1, 'unmarked service_role insert is not doubled, got ' || n;

  -- The user's own task result keeps the old ungated path.
  insert into app_notifications (user_id, title, message) values (a, 'زاد خلّص مهمة كنت طلبتها', 'تمام');
  select * into c from net.calls order by id desc limit 1;
  assert c.url like '%job=realtime_push', 'task result stays on realtime_push: ' || c.url;

  -- A DB function / trigger / signed-in writer (no service_role claim) was silent before and now speaks.
  perform set_config('request.jwt.claims', '', true);
  insert into app_notifications (user_id, title, message) values (a, 'تنبيه عيلة', 'ابنك صرف');
  select * into c from net.calls order by id desc limit 1;
  assert c.url like '%job=notification_push' and c.body ->> 'title' = 'تنبيه عيلة', 'db-side writer reaches the bot';
  perform set_config('request.jwt.claims', '{"role":"authenticated","sub":"' || a || '"}', true);
  insert into app_notifications (user_id, title, message) values (a, 'تنبيه تاني', 'y');
  select count(*) into n from net.calls;
  assert n = 4, 'signed-in/db writers push, got ' || n;

  -- Not bound: nothing is called.
  insert into app_notifications (user_id, title, message, bot_push) values (b, 'مش مربوط', 'z', true);
  select count(*) into n from net.calls;
  assert n = 4, 'unbound user gets no bot call, got ' || n;

  -- The bot dedupe table is server-only, one row per notification.
  assert not has_table_privilege('authenticated', 'public.zad_bot_notification_push', 'select'), 'customers can read the push log';
  insert into zad_bot_notification_push (notification_id, user_id) values (nid, a);
  begin
    insert into zad_bot_notification_push (notification_id, user_id) values (nid, a);
    raise exception 'second claim for the same notification was accepted';
  exception when unique_violation then null; end;

  -- A failing pg_net never blocks the notification write.
  create or replace function net.http_post(url text, headers jsonb, body jsonb, timeout_milliseconds int)
    returns bigint language plpgsql as $f$ begin raise exception 'pg_net is down'; end $f$;
  insert into app_notifications (user_id, title, message, bot_push) values (a, 'pg_net واقع', 'w', true);
  assert exists (select 1 from app_notifications where title = 'pg_net واقع'), 'notification lost when pg_net is down';

  -- The old trigger and function are gone (no double fire).
  assert not exists (select 1 from pg_trigger where tgname = 'trigger_notify_telegram_on_agent_task_notification'), 'old trigger still there';
end $$;
rollback;
\echo bot_speaks_with_notifications_test: all checks passed
