-- Health alerts reach the admin chat only (migration 20261010130000). Scratch database only:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/admin_alerts_test.sql      -- stand-ins, then the migration
--
-- The three live functions are long and touch a dozen tables; what the migration edits is
-- their admin loop. So each stand-in carries its function's loop exactly as the live text
-- had it on 2026-10-10 (three spacing styles: 8-space with the headers on one line, and
-- 2-space with and without `public.`), and the live text itself was checked read-only the
-- same day: each loop matched once and no `telegram_bindings` was left after the swap.

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

create schema if not exists net;
create table if not exists net._calls (url text, body jsonb);
create or replace function net.http_post(url text, headers jsonb, body jsonb, timeout_milliseconds int)
 returns bigint language sql as $$ insert into net._calls values (url, body) returning 1::bigint $$;
create or replace function public.zad_cron_secret(p text) returns text language sql as $$ select 's3cret' $$;
create table if not exists public.dashboard_admins (user_id uuid primary key);
create table if not exists public.telegram_bindings (
  id uuid primary key default gen_random_uuid(), user_id uuid not null, chat_id bigint,
  binding_code text not null, code_expires_at timestamptz not null, bound_at timestamptz);

create or replace function public.zad_brain_health_check()
 returns jsonb language plpgsql security definer set search_path to 'public'
as $function$
declare
    v_admin record;
    v_body text := 'العقل: ٣ من ١٠ تشغيلة فشلت';
begin
        for v_admin in
            select b.user_id from dashboard_admins a
            join telegram_bindings b on b.user_id = a.user_id and b.bound_at is not null
        loop
            perform net.http_post(
                url := 'https://auuftqncrjsnyylolhbu.supabase.co/functions/v1/zad-telegram-bot?job=realtime_push',
                headers := jsonb_build_object('Content-Type', 'application/json',
                                              'X-Realtime-Push-Secret', public.zad_cron_secret('zad_realtime_push_secret')),
                body := jsonb_build_object('user_id', v_admin.user_id,
                                           'title', '⚠️ صحة العقل', 'body', v_body),
                timeout_milliseconds := 15000
            );
        end loop;
    return jsonb_build_object('alerted', true);
end;
$function$;

create or replace function public.zad_proactive_silence_check()
 returns jsonb language plpgsql security definer set search_path to 'public'
as $function$
declare
  v_admin record;
  v_body text := 'العقل الاستباقي ساكت من ٣٧ ساعة';
begin
  for v_admin in
    select b.user_id from public.dashboard_admins a
    join public.telegram_bindings b on b.user_id = a.user_id and b.bound_at is not null
  loop
    perform net.http_post(
      url := 'https://auuftqncrjsnyylolhbu.supabase.co/functions/v1/zad-telegram-bot?job=realtime_push',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'X-Realtime-Push-Secret', public.zad_cron_secret('zad_realtime_push_secret')
      ),
      body := jsonb_build_object('user_id', v_admin.user_id,
                                 'title', '🔇 العقل ساكت', 'body', v_body),
      timeout_milliseconds := 15000
    );
  end loop;
  return jsonb_build_object('alerted', true);
end;
$function$;

create or replace function public.agent_proactive_scan()
 returns jsonb language plpgsql security definer set search_path to 'public'
as $function$
declare
  v_admin record;
  v_body text := 'الماسح الاستباقي: ١ فشل';
begin
      for v_admin in
        select b.user_id from public.dashboard_admins a
        join public.telegram_bindings b on b.user_id = a.user_id and b.bound_at is not null
      loop
        perform net.http_post(
          url := 'https://auuftqncrjsnyylolhbu.supabase.co/functions/v1/zad-telegram-bot?job=realtime_push',
          headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'X-Realtime-Push-Secret', public.zad_cron_secret('zad_realtime_push_secret')
          ),
          body := jsonb_build_object('user_id', v_admin.user_id,
                                     'title', '🚨 الماسح الاستباقي', 'body', v_body),
          timeout_milliseconds := 15000
        );
      end loop;
  return jsonb_build_object('scanned', 1);
end;
$function$;

-- An admin who is also a customer: the old loops would push to this binding.
insert into auth.users values ('00000000-0000-0000-0000-0000000000ad') on conflict do nothing;
insert into public.dashboard_admins values ('00000000-0000-0000-0000-0000000000ad') on conflict do nothing;
insert into public.telegram_bindings (user_id, chat_id, binding_code, code_expires_at, bound_at)
  values ('00000000-0000-0000-0000-0000000000ad', 4242, 'ADMIN001', now(), now());

\ir ../../migrations/20261010130000_admin_alerts_to_the_admin_chat.sql

do $$
declare
  fn text;
  v_def text;
begin
  foreach fn in array array['zad_brain_health_check', 'zad_proactive_silence_check', 'agent_proactive_scan'] loop
    select pg_get_functiondef(p.oid) into v_def from pg_proc p where p.proname = fn;
    assert position('telegram_bindings' in v_def) = 0, fn || ' still reads telegram_bindings';
    assert position('job=realtime_push' in v_def) = 0, fn || ' still posts to realtime_push';
    assert position('zad_notify_admin' in v_def) > 0, fn || ' does not call zad_notify_admin';
  end loop;

  truncate net._calls;
  perform public.zad_brain_health_check();
  perform public.zad_proactive_silence_check();
  perform public.agent_proactive_scan();
  assert (select count(*) from net._calls) = 3, (select count(*) from net._calls)::text;
  assert not exists (select 1 from net._calls where url not like '%?job=admin_alert');
  assert not exists (select 1 from net._calls where body ? 'user_id'), 'an alert still names a customer';
  assert (select array_agg(body->>'title' order by body->>'title') from net._calls)
    = (select array_agg(t order by t) from unnest(array['⚠️ صحة العقل', '🔇 العقل ساكت', '🚨 الماسح الاستباقي']) t);
  assert exists (select 1 from net._calls where body->>'body' like 'العقل الاستباقي ساكت%');
end $$;

-- A second run finds no loop left and stops (checked from the shell: applying the migration
-- again must fail with "has 0 admin loops matching").

select 'admin_alerts_test: all passed' as result;
