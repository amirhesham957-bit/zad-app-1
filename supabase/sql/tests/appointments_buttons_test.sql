-- P1.6b (المواعيد). بعد سلسلة money_buttons + commit_intent_home_scaffold + 20261122090000 + 20261129040000.
-- بيثبت إن زراير «مواعيدي» بتعدي من zad_commit_my_intent بصفة auth.uid() بس، وإن item_id بيخلي الإضافة آمنة للتكرار.
\set ON_ERROR_STOP on

create function pg_temp.check(ok boolean, msg text) returns void language plpgsql as $$
begin if ok is not true then raise exception 'FAILED: %', msg; end if; end $$;

insert into auth.users values ('77777777-7777-7777-7777-777777777777'), ('88888888-8888-8888-8888-888888888888');
select set_config('request.jwt.claims', '{"role":"authenticated","sub":"77777777-7777-7777-7777-777777777777"}', false);

-- ١) إضافة بـitem_id: الصف بنفس الـid، والمصدر app، والحدث manual
select pg_temp.check((public.zad_commit_my_intent('appointment.added', 'ap:1',
  '{"item_id":"aaaaaaaa-0000-4000-8000-000000000001","title":"دكتور أسنان","kind":"medical","starts_at":"2026-12-01T10:00:00Z","place_label":"العيادة","remind_minutes_before":60,"recurrence":"once","source":"app","for_person":"أمي"}',
  null, 'trace-appt-0001') ->> 'ok')::boolean, 'add ok');
select pg_temp.check((select title = 'دكتور أسنان' and kind = 'medical' and source = 'app' and for_person = 'أمي' and remind_minutes_before = 60
  from public.zad_appointments where id = 'aaaaaaaa-0000-4000-8000-000000000001' and user_id = '77777777-7777-7777-7777-777777777777'), 'row written under the client id');
select pg_temp.check((select source from public.zad_events where client_event_id = 'ap:1') = 'manual', 'ledger source manual');
select pg_temp.check((select trace_id from public.zad_events where client_event_id = 'ap:1') = 'trace-appt-0001', 'trace id on the ledger');

-- ٢) نفس الـid بمفتاح تاني = من غير صف تاني؛ ونفس المفتاح = duplicate
select pg_temp.check((public.zad_commit_my_intent('appointment.added', 'ap:1b',
  '{"item_id":"aaaaaaaa-0000-4000-8000-000000000001","title":"دكتور أسنان","kind":"medical","starts_at":"2026-12-01T10:00:00Z"}') ->> 'ok')::boolean, 'replay under another key ok');
select pg_temp.check((select count(*) from public.zad_appointments where user_id = '77777777-7777-7777-7777-777777777777') = 1, 'replay wrote no second row');
select pg_temp.check((public.zad_commit_my_intent('appointment.added', 'ap:1', '{}') ->> 'duplicate')::boolean, 'same key is duplicate');

-- ٣) الإضافة من غير item_id لسه شغالة (أداة الشات)، والتحقق
select pg_temp.check((public.zad_commit_my_intent('appointment.added', 'ap:2', '{"title":"اجتماع","starts_at":"2026-12-02T08:00:00Z"}') ->> 'ok')::boolean, 'add without item_id');
select pg_temp.check(public.zad_commit_my_intent('appointment.added', 'ap:3', '{"title":"ا","starts_at":"2026-12-02T08:00:00Z"}') ->> 'reason' = 'appt_title_invalid', 'short title refused');
select pg_temp.check(public.zad_commit_my_intent('appointment.added', 'ap:4', '{"item_id":"not-a-uuid","title":"اجتماع","starts_at":"2026-12-02T08:00:00Z"}') ->> 'reason' = 'item_not_found', 'bad item_id refused');

-- ٤) الحالة بـpatch: done، وupdated_at بيتحرك والباقي ثابت
update public.zad_appointments set updated_at = '2020-01-01' where id = 'aaaaaaaa-0000-4000-8000-000000000001';
select pg_temp.check((public.zad_commit_my_intent('appointment.updated', 'ap:5', '{"item_id":"aaaaaaaa-0000-4000-8000-000000000001","patch":{"status":"done"}}') ->> 'ok')::boolean, 'status done');
select pg_temp.check((select status = 'done' and updated_at > '2021-01-01' and title = 'دكتور أسنان' from public.zad_appointments where id = 'aaaaaaaa-0000-4000-8000-000000000001'), 'only status changed, updated_at moved');
select pg_temp.check(public.zad_commit_my_intent('appointment.updated', 'ap:6', '{"item_id":"aaaaaaaa-0000-4000-8000-000000000001","patch":{"status":"gone"}}') ->> 'reason' = 'status_invalid', 'bad status refused');
select pg_temp.check(public.zad_commit_my_intent('appointment.updated', 'ap:7', '{"item_id":"aaaaaaaa-0000-4000-8000-000000000099","patch":{"status":"done"}}') ->> 'reason' = 'item_not_found', 'missing row refused');

-- ٥) واحد تاني ماحدش يلمس صفه، لا تعديل ولا حذف ولا إعادة إضافة بنفس الـid
insert into public.zad_appointments (id, user_id, title, starts_at) values ('bbbbbbbb-0000-4000-8000-000000000001', '88888888-8888-8888-8888-888888888888', 'بتاع غيري', now());
select pg_temp.check(public.zad_commit_my_intent('appointment.updated', 'ap:8', '{"item_id":"bbbbbbbb-0000-4000-8000-000000000001","patch":{"status":"done"}}') ->> 'reason' = 'item_not_found', 'other user row not editable');
select pg_temp.check(public.zad_commit_my_intent('appointment.deleted', 'ap:9', '{"item_id":"bbbbbbbb-0000-4000-8000-000000000001"}') ->> 'reason' = 'item_not_found', 'other user row not deletable');
select pg_temp.check(public.zad_commit_my_intent('appointment.added', 'ap:10', '{"item_id":"bbbbbbbb-0000-4000-8000-000000000001","title":"اجتماع","starts_at":"2026-12-02T08:00:00Z"}') ->> 'reason' = 'item_not_found', 'other user id not claimable');
select pg_temp.check((select status = 'upcoming' and title = 'بتاع غيري' from public.zad_appointments where id = 'bbbbbbbb-0000-4000-8000-000000000001'), 'other row untouched');

-- ٦) الحذف
select pg_temp.check((public.zad_commit_my_intent('appointment.deleted', 'ap:11', '{"item_id":"aaaaaaaa-0000-4000-8000-000000000001"}') ->> 'ok')::boolean, 'delete ok');
select pg_temp.check((select count(*) from public.zad_appointments where id = 'aaaaaaaa-0000-4000-8000-000000000001') = 0, 'row gone');
select pg_temp.check(public.zad_commit_my_intent('appointment.deleted', 'ap:12', '{"item_id":"aaaaaaaa-0000-4000-8000-000000000001"}') ->> 'reason' = 'item_not_found', 'second delete is item_not_found');

-- ٧) من غير JWT
select set_config('request.jwt.claims', '{}', false);
select pg_temp.check(public.zad_commit_my_intent('appointment.added', 'ap:13', '{}') ->> 'reason' = 'not_authenticated', 'no JWT refused');

select 'appointments_buttons_test ok';
