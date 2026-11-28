-- P2.6: خانة جرعة من غير إجابة بعد ٤٥ دقيقة لحساب مربوط توصل للمسؤول، بالموافقة بس، مرة واحدة.
-- «فايتة» = خانة في dose_times مالهاش taken/skipped/dose_log (مافيش صف status='missed').
\set ON_ERROR_STOP on
create or replace function pg_temp.check(cond boolean, what text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAILED: %', what; end if; end $$;
-- ميعاد (HH24:MI UTC) قبل الآن بـp_min دقيقة.
create or replace function pg_temp.hhmm(p_min int) returns text language sql as $$ select to_char((now() - make_interval(mins => p_min)) at time zone 'UTC', 'HH24:MI') $$;

insert into auth.users values ('aaaaaaaa-0000-0000-0000-000000000001'), ('bbbbbbbb-0000-0000-0000-000000000002'), ('cccccccc-0000-0000-0000-000000000003');
insert into zad_users values ('aaaaaaaa-0000-0000-0000-000000000001', 'EG'), ('bbbbbbbb-0000-0000-0000-000000000002', 'EG'), ('cccccccc-0000-0000-0000-000000000003', 'EG');
-- son = صاحب البيت، mom = حساب مربوط بموافقة، dad = حساب مربوط من غير موافقة
insert into zad_household_members (id, user_id, display_name, kind, linked_user_id) values
  ('11111111-1111-1111-1111-111111111111', 'aaaaaaaa-0000-0000-0000-000000000001', 'أنا', 'self', null),
  ('22222222-2222-2222-2222-222222222222', 'aaaaaaaa-0000-0000-0000-000000000001', 'ماما', 'elder', 'bbbbbbbb-0000-0000-0000-000000000002'),
  ('33333333-3333-3333-3333-333333333333', 'aaaaaaaa-0000-0000-0000-000000000001', 'بابا', 'elder', 'cccccccc-0000-0000-0000-000000000003');
insert into scratch_medicine_grants values ('aaaaaaaa-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000002');
-- ١) خانة من ساعة من غير إجابة، لماما بموافقة: لحظة واحدة.
insert into zad_pharmacy_items (id, user_id, name, dose_times) values
  ('aaaa0000-0000-0000-0000-00000000000a', 'bbbbbbbb-0000-0000-0000-000000000002', 'كونكور', pg_temp.hhmm(60));
select pg_temp.check(zad_enqueue_guardian_missed_doses() = 1, 'first run inserts exactly one');
select pg_temp.check((select count(*) from zad_voice_moments where moment = 'guardian_dose_missed' and user_id = 'aaaaaaaa-0000-0000-0000-000000000001') = 1, 'the guardian got one moment');
select pg_temp.check((select facts ->> 'patient_name' from zad_voice_moments where moment = 'guardian_dose_missed') = 'ماما', 'patient name');
select pg_temp.check((select facts ->> 'medicine_name' from zad_voice_moments where moment = 'guardian_dose_missed') = 'كونكور', 'medicine name');
-- ٢) تاني مرة: مفيش تكرار (المفتاح ثابت للخانة).
select pg_temp.check(zad_enqueue_guardian_missed_doses() = 0, 'second run adds nothing');
select pg_temp.check((select count(*) from zad_voice_moments where moment = 'guardian_dose_missed') = 1, 'still one moment');
-- ٣) من غير موافقة (بابا): مفيش.
insert into zad_pharmacy_items (user_id, name, dose_times) values ('cccccccc-0000-0000-0000-000000000003', 'بنادول', pg_temp.hhmm(90));
select pg_temp.check(zad_enqueue_guardian_missed_doses() = 0, 'no consent: no moment');
-- ٤) قبل المهلة (٢٠ دقيقة): مفيش.
insert into zad_pharmacy_items (user_id, name, dose_times) values ('bbbbbbbb-0000-0000-0000-000000000002', 'قبل المهلة', pg_temp.hhmm(20));
select pg_temp.check(zad_enqueue_guardian_missed_doses() = 0, 'before the grace period: no moment');
-- ٥) جرعة المسؤول نفسه: مفيش. اتاخدت / اتخطت / dose_log: مفيش.
insert into zad_pharmacy_items (user_id, name, dose_times) values ('aaaaaaaa-0000-0000-0000-000000000001', 'فيتامين', pg_temp.hhmm(120));
select pg_temp.check(zad_enqueue_guardian_missed_doses() = 0, 'own dose: no moment');
insert into zad_pharmacy_items (id, user_id, name, dose_times) values
  ('aaaa0000-0000-0000-0000-0000000000d1', 'bbbbbbbb-0000-0000-0000-000000000002', 'اتاخد', pg_temp.hhmm(100)),
  ('aaaa0000-0000-0000-0000-0000000000d2', 'bbbbbbbb-0000-0000-0000-000000000002', 'اتخطى', pg_temp.hhmm(110)),
  ('aaaa0000-0000-0000-0000-0000000000d3', 'bbbbbbbb-0000-0000-0000-000000000002', 'سجل', pg_temp.hhmm(130));
insert into zad_pharmacy_doses (user_id, item_id, scheduled_at, taken_at, status) values
  ('bbbbbbbb-0000-0000-0000-000000000002', 'aaaa0000-0000-0000-0000-0000000000d1', now() - interval '100 minutes', now() - interval '95 minutes', 'taken'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'aaaa0000-0000-0000-0000-0000000000d2', now() - interval '110 minutes', null, 'skipped');
insert into zad_dose_log (user_id, pharmacy_item_id, taken_at) values
  ('bbbbbbbb-0000-0000-0000-000000000002', 'aaaa0000-0000-0000-0000-0000000000d3', now() - interval '125 minutes');
select pg_temp.check(zad_enqueue_guardian_missed_doses() = 0, 'taken / skipped / dose_log: no moment');
-- ٦) المسؤول وصله family_dose_missed لنفس الدوا بعد الخانة: مانكرّرش.
insert into zad_pharmacy_items (id, user_id, name, dose_times) values
  ('aaaa0000-0000-0000-0000-0000000000e1', 'bbbbbbbb-0000-0000-0000-000000000002', 'اتنبّه', pg_temp.hhmm(150));
insert into zad_voice_moments (user_id, moment, facts, dedupe_key) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'family_dose_missed',
   '{"member_id":"bbbbbbbb-0000-0000-0000-000000000002","item_ids":["aaaa0000-0000-0000-0000-0000000000e1"]}', 'fdm-1');
select pg_temp.check(zad_enqueue_guardian_missed_doses() = 0, 'already told by family_dose_missed: no duplicate');
delete from zad_voice_moments where dedupe_key = 'fdm-1';
delete from zad_pharmacy_items where id = 'aaaa0000-0000-0000-0000-0000000000e1';
-- ٧) فرد مؤرشف: مفيش.
update zad_household_members set archived_at = now() where id = '22222222-2222-2222-2222-222222222222';
insert into zad_pharmacy_items (user_id, name, dose_times) values ('bbbbbbbb-0000-0000-0000-000000000002', 'مؤرشف', pg_temp.hhmm(200));
select pg_temp.check(zad_enqueue_guardian_missed_doses() = 0, 'archived member: no moment');
update zad_household_members set archived_at = null where id = '22222222-2222-2222-2222-222222222222';
delete from zad_pharmacy_items where name = 'مؤرشف';
-- ٨) سقف ٥ في اليوم: واحدة اتبعتت، فيتبعت ٤ بس من ٩ دوا فايتين.
delete from zad_pharmacy_items where user_id = 'bbbbbbbb-0000-0000-0000-000000000002' and id <> 'aaaa0000-0000-0000-0000-00000000000a';
delete from zad_pharmacy_doses; delete from zad_dose_log;
insert into zad_pharmacy_items (user_id, name, dose_times)
  select 'bbbbbbbb-0000-0000-0000-000000000002', 'دوا' || g, pg_temp.hhmm(60 + g) from generate_series(1, 9) g;
select pg_temp.check(zad_enqueue_guardian_missed_doses() = 4, 'cap: five per day in total (one already sent)');
select pg_temp.check((select count(*) from zad_voice_moments where moment = 'guardian_dose_missed') = 5, 'five moments total');
select pg_temp.check(not has_function_privilege('authenticated', 'zad_enqueue_guardian_missed_doses()', 'execute'), 'authenticated cannot run it');
select pg_temp.check(has_function_privilege('service_role', 'zad_enqueue_guardian_missed_doses()', 'execute'), 'service_role can run it');
