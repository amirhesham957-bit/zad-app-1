-- «احتمال مطر في الساعات الجاية» (migration 20261115010000), on a scratch database:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/rain_soon_scaffold.sql
--   psql < supabase/migrations/20261115010000_rain_soon.sql
--   psql < supabase/sql/tests/rain_soon_test.sql
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

-- «الآن» = ١٢ الضهر في القاهرة (١٠:١٥ UTC، نوفمبر من غير توقيت صيفي) = ١:١٥ في الرياض.
\set now '''2026-11-15 10:15:00+00'''

insert into auth.users (id, last_sign_in_at) values
  ('00000000-0000-0000-0000-0000000000a1', :now::timestamptz - interval '1 day'),   -- نشط
  ('00000000-0000-0000-0000-0000000000b1', :now::timestamptz - interval '1 day'),   -- مسافر
  ('00000000-0000-0000-0000-0000000000c1', :now::timestamptz - interval '1 day'),   -- طفل
  ('00000000-0000-0000-0000-0000000000d1', :now::timestamptz - interval '60 days'), -- غايب، بس كلّم زاد امبارح
  ('00000000-0000-0000-0000-0000000000e1', :now::timestamptz - interval '60 days'), -- غايب خالص
  ('00000000-0000-0000-0000-0000000000f1', :now::timestamptz - interval '1 day');   -- الرياض: الساعة ١ مش ١٢
insert into public.zad_users (id, currency, country, travel_country) values
  ('00000000-0000-0000-0000-0000000000a1', 'EGP', 'EG', null),
  ('00000000-0000-0000-0000-0000000000b1', 'EGP', 'EG', 'US'),
  ('00000000-0000-0000-0000-0000000000c1', 'EGP', 'EG', null),
  ('00000000-0000-0000-0000-0000000000d1', 'EGP', 'EG', null),
  ('00000000-0000-0000-0000-0000000000e1', 'EGP', 'EG', null),
  ('00000000-0000-0000-0000-0000000000f1', 'SAR', 'SA', null);
insert into public.family_groups (id) values ('00000000-0000-0000-0000-00000000f000');
insert into public.family_members (family_id, user_id, role) values
  ('00000000-0000-0000-0000-00000000f000', '00000000-0000-0000-0000-0000000000c1', 'child');
insert into public.zad_chat_turns (user_id, role, text, created_at) values
  ('00000000-0000-0000-0000-0000000000d1', 'user', 'صرفت ٥٠', :now::timestamptz - interval '1 day'),
  ('00000000-0000-0000-0000-0000000000e1', 'assistant', 'صباح الخير', :now::timestamptz - interval '1 day');  -- زاد مش هو

select pg_temp.check(public.zad_enqueue_rain_soon(:now::timestamptz) = 2, 'two customers get a check at noon');
select pg_temp.check((select array_agg(user_id order by user_id) from public.zad_voice_moments)
  = array['00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000d1']::uuid[], 'active, home, adult, Cairo noon');
select pg_temp.check((select bool_and(moment = 'rain_soon' and dedupe_key = 'rain_soon:2026-11-15:12') from public.zad_voice_moments), 'keyed by day and hour');
select pg_temp.check((select bool_and(facts ->> 'time_zone' = 'Africa/Cairo' and facts ->> 'local_date' = '2026-11-15' and (facts ->> 'local_hour')::int = 12)
  from public.zad_voice_moments), 'facts carry the local day, hour and zone');

select pg_temp.check(public.zad_enqueue_rain_soon(:now::timestamptz) = 0, 'the same hour twice adds nothing');
select pg_temp.check(public.zad_enqueue_rain_soon(:now::timestamptz + interval '1 hour') = 0, '1 pm is not a check hour in Cairo');
select pg_temp.check(public.zad_enqueue_rain_soon(:now::timestamptz - interval '1 hour') = 1, '11 in Cairo is noon in Riyadh');

-- الأول اتبعتله تنبيه الضهر ⇐ مفيش فحص تاني النهارده، والتاني اتقفل skipped ⇐ يتفحص تاني الساعة ٣.
update public.zad_voice_moments set status = 'sent' where user_id = '00000000-0000-0000-0000-0000000000a1';
update public.zad_voice_moments set status = 'skipped' where user_id = '00000000-0000-0000-0000-0000000000d1';
select pg_temp.check(public.zad_enqueue_rain_soon(:now::timestamptz + interval '3 hours') = 1, 'at 3 pm only the one not yet warned');
select pg_temp.check(exists (select 1 from public.zad_voice_moments where user_id = '00000000-0000-0000-0000-0000000000d1'
  and dedupe_key = 'rain_soon:2026-11-15:15'), 'his 3 pm check');
-- بكرة يوم جديد.
select pg_temp.check(public.zad_enqueue_rain_soon(:now::timestamptz + interval '21 hours') = 2, 'a new day, both checked again at 9');

select pg_temp.check(not has_function_privilege('authenticated', 'public.zad_enqueue_rain_soon(timestamptz)', 'execute'), 'not callable by users');
