-- رسالة الليل الواحدة (migration 20261024213500, ZAD_PLAN 1.5), on a scratch database:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/migrations/20261024213500_night_one_message.sql
--   psql < supabase/sql/tests/night_one_message_test.sql
--
-- Raises on the first failed check; each passing one prints "ok:".

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

\set QUIET 1
create or replace function pg_temp.check(cond boolean, label text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAIL: %', label; end if; raise notice 'ok: %', label; end $$;
alter table public.zad_users add column if not exists country text, add column if not exists sleep_bed time;
create table if not exists public.zad_voice_moments (
  id uuid primary key default gen_random_uuid(), user_id uuid, moment text, status text default 'pending', dedupe_key text);
-- الساعة اللي «الآن» واقف عليها في الاختبار: الدالة بتقرا توقيت السوق، والسوق هنا متوقّت عشان
-- now() بتوقيته يبقى الساعة اللي عايزينها.
create or replace function public.zad_market_timezone(p_country text) returns text language sql as $$
  select current_setting('test.tz', true) $$;
insert into auth.users values ('00000000-0000-0000-0000-0000000000a1'), ('00000000-0000-0000-0000-0000000000b1') on conflict do nothing;
insert into public.zad_users (id, currency, country) values
  ('00000000-0000-0000-0000-0000000000a1', 'EGP', 'EG'), ('00000000-0000-0000-0000-0000000000b1', 'SAR', 'SA');
-- منطقة توقيت ثابتة الإزاحة بحيث الساعة المحلية دلوقتي = [p_hhmm].
create or replace function pg_temp.at_local(p_hhmm time) returns void language plpgsql as $$
declare v_off interval := p_hhmm - (now() at time zone 'UTC')::time;
        v_min int;
begin
  v_min := round(extract(epoch from v_off) / 60)::int;
  -- POSIX: «Etc/GMT-3» = +03:00؛ دقايق بتتكتب بالشكل <+HHMM>-HH:MM.
  v_min := ((v_min % 1440) + 1440) % 1440;
  if v_min > 720 then v_min := v_min - 1440; end if;
  perform set_config('test.tz', format('<X>%s%s:%s', case when v_min >= 0 then '-' else '+' end,
    lpad((abs(v_min) / 60)::text, 2, '0'), lpad((abs(v_min) % 60)::text, 2, '0')), false);
end $$;
\set QUIET 0

-- 1. The night slot follows the customer's bedtime.
select pg_temp.check(public.zad_night_slot(null) = '21:30', 'no sleep window: 9:30 as before');
select pg_temp.check(public.zad_night_slot('23:30') = '22:30', 'bed at 11:30 → night at 10:30');
select pg_temp.check(public.zad_night_slot('20:00') = '19:30', 'an early bed never pulls the night before 7:30');
select pg_temp.check(public.zad_night_slot('01:30') = '23:00', 'after midnight → 11 p.m., same day');
select pg_temp.check(public.zad_night_slot('12:00') = '21:30', 'an impossible bedtime → the default');

-- 2. The slot window.
select pg_temp.check(public.zad_in_slot('21:45', '21:30', 30), 'inside the half hour');
select pg_temp.check(not public.zad_in_slot('22:00', '21:30', 30), 'the end is open');
select pg_temp.check(not public.zad_in_slot('21:29', '21:30', 30), 'before the slot');
select pg_temp.check(not public.zad_in_slot('00:05', '23:50', 30), 'a window never wraps into tomorrow');

-- 3. The stand-alone stock question waits 40 minutes past the night slot.
select pg_temp.at_local('21:50');
select pg_temp.check(not public.zad_checkin_night_due('00000000-0000-0000-0000-0000000000a1'), '9:50: too early (slot 9:30 + 40)');
select pg_temp.at_local('22:15');
select pg_temp.check(public.zad_checkin_night_due('00000000-0000-0000-0000-0000000000a1'), '10:15, no day-close tonight: ask');

-- 4. A day-close tonight carries the questions, so the stand-alone one stays quiet.
insert into public.zad_voice_moments (user_id, moment, status, dedupe_key)
  values ('00000000-0000-0000-0000-0000000000a1', 'close_day', 'sent', 'close_day:' || to_char(now() at time zone current_setting('test.tz'), 'YYYY-MM-DD'));
select pg_temp.check(not public.zad_checkin_night_due('00000000-0000-0000-0000-0000000000a1'), 'the day-close went out tonight: no second message');
select pg_temp.check(public.zad_checkin_night_due('00000000-0000-0000-0000-0000000000b1'), 'another account is not affected');
insert into public.zad_voice_moments (user_id, moment, status, dedupe_key)
  values ('00000000-0000-0000-0000-0000000000b1', 'close_day', 'skipped', 'close_day:' || to_char(now() at time zone current_setting('test.tz'), 'YYYY-MM-DD'));
select pg_temp.check(public.zad_checkin_night_due('00000000-0000-0000-0000-0000000000b1'), 'a skipped day-close did not carry the questions: ask');

-- 5. A late sleeper is asked later.
update public.zad_users set sleep_bed = '00:30' where id = '00000000-0000-0000-0000-0000000000b1';
select pg_temp.check(not public.zad_checkin_night_due('00000000-0000-0000-0000-0000000000b1'), 'bed 12:30: 10:15 is still before their night');

-- 6. Only the bot can ask.
select pg_temp.check(not has_function_privilege('authenticated', 'public.zad_checkin_night_due(uuid)', 'execute'), 'customers cannot call it');
