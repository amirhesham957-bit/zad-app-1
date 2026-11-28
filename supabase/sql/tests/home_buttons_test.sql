-- P1.6b (البيت). بعد سلسلة commit_intent_home (السقالة + مجالات الصيانة والمستندات) + events_trace_id + 20261129030000.
-- بيثبت إن زراير الصيانة والمستندات بتعدي من zad_commit_my_intent بصفة auth.uid() بس، وبمصدر manual وtrace_id.
\set ON_ERROR_STOP on
create function pg_temp.check(ok boolean, msg text) returns void language plpgsql as $$
begin if ok is not true then raise exception 'FAILED: %', msg; end if; end $$;

insert into auth.users values ('77777777-7777-7777-7777-777777777777'), ('88888888-8888-8888-8888-888888888888');
select set_config('request.jwt.claims', '{"role":"authenticated","sub":"77777777-7777-7777-7777-777777777777"}', false);

-- ١) إضافة جهاز بتاريخ الشراء، وهوية صاحب الطلب من الـJWT
select pg_temp.check((public.zad_commit_my_intent('maintenance.added', 'hm:1', '{"name":"تكييف","category":"تكييف","purchase_date":"2026-01-05","warranty_expiry_date":"2028-01-05","service_interval_days":180,"estimated_cost":0}', null, 'trace-home-0001') ->> 'ok')::boolean, 'device added');
select pg_temp.check((select purchase_date = '2026-01-05' and warranty_expiry_date = '2028-01-05' and user_id = '77777777-7777-7777-7777-777777777777' from public.zad_maintenance_items where name = 'تكييف'), 'row written for me with purchase date');
select pg_temp.check((select trace_id = 'trace-home-0001' and source = 'manual' from public.zad_events where client_event_id = 'hm:1'), 'trace id and manual source on the ledger');
select pg_temp.check(public.zad_commit_my_intent('maintenance.added', 'hm:2', '{"name":"سخان","purchase_date":"2026-02-31"}') ->> 'reason' = 'day_invalid', 'impossible purchase date refused');
select pg_temp.check((select count(*) from public.zad_maintenance_items) = 1, 'refusal wrote nothing');

-- ٢) تم الصيانة
select pg_temp.check((public.zad_commit_my_intent('maintenance.updated', 'hm:3', jsonb_build_object('item_id', (select id from public.zad_maintenance_items), 'patch', '{"last_service_date":"2026-11-28"}'::jsonb)) ->> 'ok')::boolean, 'serviced');
select pg_temp.check((select last_service_date = '2026-11-28' from public.zad_maintenance_items), 'service date written');

-- ٣) التكرار من غير كتابة
select pg_temp.check((public.zad_commit_my_intent('maintenance.added', 'hm:1', '{"name":"تكييف"}') ->> 'duplicate')::boolean, 'same key is duplicate');
select pg_temp.check((select count(*) from public.zad_maintenance_items) = 1, 'duplicate wrote nothing');

-- ٤) المستندات: حفظ جديد، وحفظ تاني لنفس (نوع، صاحب) = تجديد مش صف تاني
select pg_temp.check((public.zad_commit_my_intent('document.saved', 'hd:1', '{"kind":"passport","holder":"أنا","label":"","expires_on":"2030-05-01"}') ->> 'ok')::boolean, 'document saved');
select pg_temp.check((public.zad_commit_my_intent('document.saved', 'hd:2', '{"kind":"passport","holder":"أنا","label":"","expires_on":"2035-05-01"}') ->> 'ok')::boolean, 'document renewed');
select pg_temp.check((select count(*) = 1 and min(expires_on) = date '2035-05-01' from public.zad_documents), 'one row, new date');
select pg_temp.check(public.zad_commit_my_intent('document.saved', 'hd:3', '{"kind":"other","holder":"","label":"","expires_on":"2030-05-01"}') ->> 'reason' = 'label_required', 'other needs a name');

-- ٥) حذف: صفوفي بس، وصف واحد تاني ماتلمسش
insert into public.zad_documents (user_id, kind, holder, label, expires_on) values ('88888888-8888-8888-8888-888888888888', 'passport', 'غيري', '', '2031-01-01');
select pg_temp.check(public.zad_commit_my_intent('document.deleted', 'hd:4', jsonb_build_object('item_id', (select id from public.zad_documents where user_id = '88888888-8888-8888-8888-888888888888'))) ->> 'reason' = 'item_not_found', 'cannot delete someone else''s document');
select pg_temp.check((public.zad_commit_my_intent('document.deleted', 'hd:5', jsonb_build_object('item_id', (select id from public.zad_documents where user_id = '77777777-7777-7777-7777-777777777777'))) ->> 'ok')::boolean, 'my document deleted');
select pg_temp.check((public.zad_commit_my_intent('maintenance.deleted', 'hm:4', jsonb_build_object('item_id', (select id from public.zad_maintenance_items))) ->> 'ok')::boolean, 'device deleted');
select pg_temp.check((select count(*) from public.zad_documents) = 1 and (select count(*) from public.zad_maintenance_items) = 0, 'only mine went');

-- ٦) من غير JWT
select set_config('request.jwt.claims', '{}', false);
select pg_temp.check(public.zad_commit_my_intent('document.saved', 'hd:6', '{}') ->> 'reason' = 'not_authenticated', 'no JWT refused');

select 'home_buttons_test ok';
