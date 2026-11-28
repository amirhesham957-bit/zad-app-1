-- P2.6: الجرعة الفايتة لحساب مربوط توصل للمسؤول بعد ٤٥ دقيقة، بالموافقة بس، مرة واحدة.
\set ON_ERROR_STOP on
create or replace function pg_temp.check(cond boolean, what text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAILED: %', what; end if; end $$;

insert into auth.users values ('aaaaaaaa-0000-0000-0000-000000000001'), ('bbbbbbbb-0000-0000-0000-000000000002'), ('cccccccc-0000-0000-0000-000000000003');
-- son = صاحب البيت، mom = حساب مربوط، dad = حساب مربوط مالوش موافقة
insert into zad_household_members (id, user_id, display_name, kind, linked_user_id) values
  ('11111111-1111-1111-1111-111111111111', 'aaaaaaaa-0000-0000-0000-000000000001', 'أنا', 'self', null),
  ('22222222-2222-2222-2222-222222222222', 'aaaaaaaa-0000-0000-0000-000000000001', 'ماما', 'elder', 'bbbbbbbb-0000-0000-0000-000000000002'),
  ('33333333-3333-3333-3333-333333333333', 'aaaaaaaa-0000-0000-0000-000000000001', 'بابا', 'elder', 'cccccccc-0000-0000-0000-000000000003');
insert into scratch_medicine_grants values ('aaaaaaaa-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000002');
insert into zad_pharmacy_items (id, user_id, name) values
  ('aaaa0000-0000-0000-0000-00000000000a', 'bbbbbbbb-0000-0000-0000-000000000002', 'كونكور'),
  ('aaaa0000-0000-0000-0000-00000000000b', 'cccccccc-0000-0000-0000-000000000003', 'بنادول'),
  ('aaaa0000-0000-0000-0000-00000000000c', 'aaaaaaaa-0000-0000-0000-000000000001', 'فيتامين');
-- ١) فايتة من ساعة (بعد المهلة)، لماما بموافقة.
insert into zad_pharmacy_doses (user_id, item_id, scheduled_at, status) values
  ('bbbbbbbb-0000-0000-0000-000000000002', 'aaaa0000-0000-0000-0000-00000000000a', now() - interval '60 minutes', 'missed');
select pg_temp.check(zad_enqueue_guardian_missed_doses() = 1, 'first run inserts exactly one');
select pg_temp.check((select count(*) from zad_voice_moments where moment = 'guardian_dose_missed' and user_id = 'aaaaaaaa-0000-0000-0000-000000000001') = 1, 'the guardian got one moment');
select pg_temp.check((select facts ->> 'patient_name' from zad_voice_moments where moment = 'guardian_dose_missed') = 'ماما', 'patient name');
select pg_temp.check((select facts ->> 'medicine_name' from zad_voice_moments where moment = 'guardian_dose_missed') = 'كونكور', 'medicine name');
-- ٢) تاني مرة: مفيش تكرار.
select pg_temp.check(zad_enqueue_guardian_missed_doses() = 0, 'second run adds nothing');
select pg_temp.check((select count(*) from zad_voice_moments where moment = 'guardian_dose_missed') = 1, 'still one moment');
-- ٣) من غير موافقة (بابا): مفيش.
insert into zad_pharmacy_doses (user_id, item_id, scheduled_at, status) values
  ('cccccccc-0000-0000-0000-000000000003', 'aaaa0000-0000-0000-0000-00000000000b', now() - interval '90 minutes', 'missed');
select pg_temp.check(zad_enqueue_guardian_missed_doses() = 0, 'no consent: no moment');
-- ٤) قبل المهلة (٢٠ دقيقة): مفيش.
insert into zad_pharmacy_doses (user_id, item_id, scheduled_at, status) values
  ('bbbbbbbb-0000-0000-0000-000000000002', 'aaaa0000-0000-0000-0000-00000000000a', now() - interval '20 minutes', 'missed');
select pg_temp.check(zad_enqueue_guardian_missed_doses() = 0, 'before the grace period: no moment');
-- ٥) جرعة المسؤول نفسه، وجرعة اتاخدت/اتخطت: مفيش.
insert into zad_pharmacy_doses (user_id, item_id, scheduled_at, status) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'aaaa0000-0000-0000-0000-00000000000c', now() - interval '2 hours', 'missed'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'aaaa0000-0000-0000-0000-00000000000a', now() - interval '3 hours', 'taken'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'aaaa0000-0000-0000-0000-00000000000a', now() - interval '4 hours', 'skipped');
select pg_temp.check(zad_enqueue_guardian_missed_doses() = 0, 'own dose / taken / skipped: no moment');
-- ٦) فرد مؤرشف: مفيش (بعد ما الموافقة لسه موجودة).
update zad_household_members set archived_at = now() where id = '22222222-2222-2222-2222-222222222222';
insert into zad_pharmacy_doses (user_id, item_id, scheduled_at, status) values
  ('bbbbbbbb-0000-0000-0000-000000000002', 'aaaa0000-0000-0000-0000-00000000000a', now() - interval '5 hours', 'missed');
select pg_temp.check(zad_enqueue_guardian_missed_doses() = 0, 'archived member: no moment');
update zad_household_members set archived_at = null where id = '22222222-2222-2222-2222-222222222222';
-- ٧) سقف ٥ في اليوم، وغير service_role مايقدرش ينفّذ.
delete from zad_pharmacy_doses;
insert into zad_pharmacy_doses (user_id, item_id, scheduled_at, status)
  select 'bbbbbbbb-0000-0000-0000-000000000002', 'aaaa0000-0000-0000-0000-00000000000a', now() - interval '1 hour' - (g || ' minutes')::interval, 'missed'
  from generate_series(1, 9) g;
select pg_temp.check(zad_enqueue_guardian_missed_doses() = 4, 'cap: five per day in total (one already sent)');
select pg_temp.check((select count(*) from zad_voice_moments where moment = 'guardian_dose_missed') = 5, 'five moments total');
select pg_temp.check(not has_function_privilege('authenticated', 'zad_enqueue_guardian_missed_doses()', 'execute'), 'authenticated cannot run it');
select pg_temp.check(has_function_privilege('service_role', 'zad_enqueue_guardian_missed_doses()', 'execute'), 'service_role can run it');
