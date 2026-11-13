-- «زاد يسأل عليك» (migration 20261113110000), on a scratch database:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/asks_after_you_scaffold.sql
--   psql < supabase/migrations/20261113110000_asks_after_you.sql
--   psql < supabase/sql/tests/asks_after_you_test.sql
--
-- Raises on the first failed check; each passing one prints "ok:".

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

\set QUIET 1
\o /dev/null
create or replace function pg_temp.check(cond boolean, label text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAIL: %', label; end if; raise notice 'ok: %', label; end $$;

-- «الآن» = ٧ المسا في القاهرة (١٧:٠٠ UTC، نوفمبر من غير توقيت صيفي).
\set now '''2026-11-20 17:00:00+00'''

insert into auth.users values
  ('00000000-0000-0000-0000-0000000000a1'), ('00000000-0000-0000-0000-0000000000b1'), ('00000000-0000-0000-0000-0000000000c1'),
  ('00000000-0000-0000-0000-0000000000d1'), ('00000000-0000-0000-0000-0000000000e1'), ('00000000-0000-0000-0000-0000000000f1');
insert into public.zad_users (id, currency, country) values
  ('00000000-0000-0000-0000-0000000000a1', 'EGP', 'EG'),  -- غايب ٥ أيام، تليجرام
  ('00000000-0000-0000-0000-0000000000b1', 'EGP', 'EG'),  -- فتح التطبيق امبارح
  ('00000000-0000-0000-0000-0000000000c1', 'EGP', 'EG'),  -- مابيفتحش التطبيق بس كلّم زاد امبارح على تليجرام
  ('00000000-0000-0000-0000-0000000000d1', 'EGP', 'EG'),  -- غايب ٥ أيام ومالوش أي طريق يوصله
  ('00000000-0000-0000-0000-0000000000e1', 'EGP', 'EG'),  -- غايب ٦٠ يوم
  ('00000000-0000-0000-0000-0000000000f1', 'SAR', 'SA');  -- غايب ٥ أيام بس الساعة عنده ٨ مش ٧
insert into public.telegram_bindings values
  ('00000000-0000-0000-0000-0000000000a1', 1), ('00000000-0000-0000-0000-0000000000b1', 2), ('00000000-0000-0000-0000-0000000000c1', 3),
  ('00000000-0000-0000-0000-0000000000e1', 5), ('00000000-0000-0000-0000-0000000000f1', 6);
insert into public.zad_product_events (user_id, name, at) values
  ('00000000-0000-0000-0000-0000000000a1', 'app_open', :now::timestamptz - interval '5 days'),
  ('00000000-0000-0000-0000-0000000000a1', 'bank.off', :now::timestamptz - interval '1 day'),   -- مش فتح
  ('00000000-0000-0000-0000-0000000000b1', 'app_open', :now::timestamptz - interval '1 day'),
  ('00000000-0000-0000-0000-0000000000c1', 'app_open', :now::timestamptz - interval '10 days'),
  ('00000000-0000-0000-0000-0000000000d1', 'app_open', :now::timestamptz - interval '5 days'),
  ('00000000-0000-0000-0000-0000000000e1', 'app_open', :now::timestamptz - interval '60 days'),
  ('00000000-0000-0000-0000-0000000000f1', 'app_open', :now::timestamptz - interval '5 days');
insert into public.zad_chat_turns (user_id, role, text, created_at) values
  ('00000000-0000-0000-0000-0000000000c1', 'user', 'صرفت ٥٠', :now::timestamptz - interval '1 day'),
  ('00000000-0000-0000-0000-0000000000a1', 'assistant', 'صباح الخير', :now::timestamptz - interval '1 day');  -- زاد مش هو
insert into public.zad_transactions (user_id, amount, txn_kind, created_at) values
  ('00000000-0000-0000-0000-0000000000a1', 120, 'expense', :now::timestamptz - interval '2 days'),
  ('00000000-0000-0000-0000-0000000000a1', 80, 'expense', :now::timestamptz - interval '1 day'),
  ('00000000-0000-0000-0000-0000000000a1', 999, 'expense', :now::timestamptz - interval '9 days');  -- قبل الغياب

select pg_temp.check(public.zad_enqueue_ignored_days(:now::timestamptz) = 1, 'one customer is asked after');
select pg_temp.check((select user_id from public.zad_voice_moments) = '00000000-0000-0000-0000-0000000000a1', 'it is the one away 5 days');
select pg_temp.check((select facts ->> 'step' from public.zad_voice_moments) = '1', 'first step');
select pg_temp.check((select (facts ->> 'days_away')::int from public.zad_voice_moments) = 5, 'days away counted');
select pg_temp.check((select (facts ->> 'expenses_recorded_while_away')::int from public.zad_voice_moments) = 2, 'only expenses while away');
select pg_temp.check((select facts ->> 'time_zone' from public.zad_voice_moments) = 'Africa/Cairo', 'his market time zone');
select pg_temp.check(not exists (select 1 from public.zad_voice_moments where user_id = '00000000-0000-0000-0000-0000000000c1'),
  'still talking on Telegram is not away');
select pg_temp.check(not exists (select 1 from public.zad_voice_moments where user_id = '00000000-0000-0000-0000-0000000000d1'),
  'no channel, no moment');
select pg_temp.check(not exists (select 1 from public.zad_voice_moments where user_id = '00000000-0000-0000-0000-0000000000e1'),
  'gone 60 days is left alone');
select pg_temp.check(not exists (select 1 from public.zad_voice_moments where user_id = '00000000-0000-0000-0000-0000000000f1'),
  'only at 7 pm in his own market');

-- نفس الساعة تاني (كرون اتكرر) ⇒ مفيش تكرار.
select pg_temp.check(public.zad_enqueue_ignored_days(:now::timestamptz) = 0, 'same hour twice adds nothing');
-- بكرة ولسه ساكت ⇒ مفيش سؤال تاني قبل ١٤ يوم.
select pg_temp.check(public.zad_enqueue_ignored_days(:now::timestamptz + interval '1 day') = 0, 'no second ask before day 14');
-- يوم ١٤ ⇒ الخطوة ٢.
-- (العميل c1 هيبقى ساكت ١٠ أيام ساعتها، فبيتسأل أول مرة هو كمان — العدّ هنا لـa1 لوحده.)
select public.zad_enqueue_ignored_days(:now::timestamptz + interval '9 days');
select pg_temp.check((select count(*) from public.zad_voice_moments where user_id = '00000000-0000-0000-0000-0000000000a1') = 2, 'second ask on day 14');
select pg_temp.check((select max(facts ->> 'step') from public.zad_voice_moments where user_id = '00000000-0000-0000-0000-0000000000a1') = '2', 'second step');
select pg_temp.check((select count(*) from public.zad_voice_moments where user_id = '00000000-0000-0000-0000-0000000000c1') = 1, 'the Telegram talker who went quiet is asked once');
-- وبعدها خلاص لحد ما يرجع.
select public.zad_enqueue_ignored_days(:now::timestamptz + interval '20 days');
select pg_temp.check((select count(*) from public.zad_voice_moments where user_id = '00000000-0000-0000-0000-0000000000a1') = 2, 'never a third ask');

-- رجع وفتح وغاب تاني ⇒ غياب جديد يبدأ من الأول.
insert into public.zad_product_events (user_id, name, at) values
  ('00000000-0000-0000-0000-0000000000a1', 'app_open', :now::timestamptz + interval '21 days');
select public.zad_enqueue_ignored_days(:now::timestamptz + interval '25 days');
select pg_temp.check((select count(*) from public.zad_voice_moments where user_id = '00000000-0000-0000-0000-0000000000a1') = 3, 'a new absence starts over');

select pg_temp.check(not has_function_privilege('anon', 'public.zad_enqueue_ignored_days(timestamptz)', 'execute'), 'anon cannot enqueue');
select pg_temp.check(not has_function_privilege('authenticated', 'public.zad_enqueue_ignored_days(timestamptz)', 'execute'), 'authenticated cannot enqueue');
