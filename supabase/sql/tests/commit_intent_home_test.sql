-- ZAD_OR_PLAN م٢.٥: صيانة البيت والمستندات والمواعيد من الباب.
\set ON_ERROR_STOP on
create or replace function pg_temp.check(cond boolean, what text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAILED: %', what; end if; end $$;
create or replace function pg_temp.ci(j text) returns jsonb language sql as $$ select zad_commit_intent(j::jsonb) $$;
-- نية من المستخدم ١ بنوع وحمولة ومفتاح.
create or replace function pg_temp.go(k text, cid text, payload text) returns jsonb language sql as $$
  select zad_commit_intent(jsonb_build_object('user_id', '11111111-1111-1111-1111-111111111111', 'kind', k,
    'client_event_id', cid, 'payload', payload::jsonb)) $$;
create or replace function pg_temp.go2(k text, cid text, payload text) returns jsonb language sql as $$
  select zad_commit_intent(jsonb_build_object('user_id', '22222222-2222-2222-2222-222222222222', 'kind', k,
    'client_event_id', cid, 'payload', payload::jsonb)) $$;

-- ═══ صيانة ═══
select pg_temp.check((pg_temp.go('maintenance.added', 'm1', '{"name":"  غسالة  ","warranty_expiry_date":"2027-03-01","service_interval_days":180,"estimated_cost":350}') ->> 'ok')::boolean, 'maintenance added');
select pg_temp.check((select name = 'غسالة' and category = 'عام' and warranty_expiry_date = '2027-03-01' and service_interval_days = 180 and estimated_cost = 350
                        from zad_maintenance_items where user_id = '11111111-1111-1111-1111-111111111111'), 'row trimmed, default category');
select pg_temp.check((select (payload -> 'after' ->> 'name') = 'غسالة' and payload ->> 'row_id' is not null from zad_events where client_event_id = 'm1'), 'event has the after row');
select pg_temp.check(pg_temp.go('maintenance.added', 'm2', '{"name":"غ"}') ->> 'reason' = 'device_name_invalid', 'name too short');
select pg_temp.check(pg_temp.go('maintenance.added', 'm3', '{"name":"تلاجة","warranty_expiry_date":"2027-02-31"}') ->> 'reason' = 'day_invalid', 'impossible day');
select pg_temp.check(pg_temp.go('maintenance.added', 'm4', '{"name":"تلاجة","service_interval_days":0}') ->> 'reason' = 'interval_invalid', 'interval zero');
select pg_temp.check(pg_temp.go('maintenance.added', 'm5', '{"name":"تلاجة","estimated_cost":-5}') ->> 'reason' = 'cost_invalid', 'negative cost');
select pg_temp.check(pg_temp.go('maintenance.added', 'm6', '{"name":"تلاجة","category":"' || repeat('ا', 61) || '"}') ->> 'reason' = 'device_category_invalid', 'category too long');
select pg_temp.check((select count(*) from zad_maintenance_items) = 1, 'refusals wrote nothing');

select pg_temp.check((pg_temp.go('maintenance.updated', 'm7', jsonb_build_object('item_id', (select id from zad_maintenance_items), 'patch', '{"last_service_date":"2026-11-01"}'::jsonb)::text) ->> 'ok')::boolean, 'maintenance updated');
select pg_temp.check((select last_service_date = '2026-11-01' and warranty_expiry_date = '2027-03-01' from zad_maintenance_items), 'only the patched field moved');
select pg_temp.check((select payload -> 'before' ->> 'last_service_date' is null and payload -> 'before' ? 'last_service_date' from zad_events where client_event_id = 'm7'), 'update keeps the old value in the event');
select pg_temp.check(pg_temp.go('maintenance.updated', 'm8', jsonb_build_object('item_id', (select id from zad_maintenance_items), 'patch', '{}'::jsonb)::text) ->> 'reason' = 'patch_empty', 'empty patch');
select pg_temp.check(pg_temp.go('maintenance.updated', 'm9', jsonb_build_object('item_id', (select id from zad_maintenance_items), 'patch', '{"name":"x"}'::jsonb)::text) ->> 'reason' = 'patch_field_unknown', 'unknown field');
select pg_temp.check(pg_temp.go('maintenance.updated', 'm10', jsonb_build_object('item_id', (select id from zad_maintenance_items), 'patch', '{"last_service_date":"أمس"}'::jsonb)::text) ->> 'reason' = 'day_invalid', 'bad date in patch');
-- مستخدم تاني مايلمسش الصف ولا يمسحه.
select pg_temp.check(pg_temp.go2('maintenance.updated', 'm11', jsonb_build_object('item_id', (select id from zad_maintenance_items), 'patch', '{"last_service_date":"2026-12-01"}'::jsonb)::text) ->> 'reason' = 'item_not_found', 'other user update refused');
select pg_temp.check(pg_temp.go2('maintenance.deleted', 'm12', jsonb_build_object('item_id', (select id from zad_maintenance_items))::text) ->> 'reason' = 'item_not_found', 'other user delete refused');
select pg_temp.check((select last_service_date = '2026-11-01' from zad_maintenance_items), 'other user left it alone');
select pg_temp.check(pg_temp.go('maintenance.deleted', 'm13', '{"item_id":"not-a-uuid"}') ->> 'reason' = 'item_not_found', 'bad id');
select pg_temp.check((pg_temp.go('maintenance.deleted', 'm14', jsonb_build_object('item_id', (select id from zad_maintenance_items))::text) ->> 'ok')::boolean, 'maintenance deleted');
select pg_temp.check(not exists (select 1 from zad_maintenance_items), 'row gone');
select pg_temp.check((select payload -> 'before' ->> 'name' = 'غسالة' and payload -> 'after' = 'null'::jsonb from zad_events where client_event_id = 'm14'), 'delete keeps the full row as before');
select pg_temp.check(pg_temp.go('maintenance.explode', 'm15', '{}') ->> 'reason' = 'unknown_kind', 'unknown maintenance kind');
select pg_temp.check((select count(*) from zad_guard_events where intent ->> 'client_event_id' in ('m2','m3','m4','m5','m6','m8','m9','m10','m11','m12','m13')) = 11, 'every maintenance refusal logged');

-- ═══ مستندات ═══
select pg_temp.check((pg_temp.go('document.saved', 'd1', '{"kind":"passport","holder":"أمير","expires_on":"2028-05-10"}') ->> 'ok')::boolean, 'document saved');
select pg_temp.check((select payload -> 'before' = 'null'::jsonb and payload -> 'after' ->> 'expires_on' = '2028-05-10' from zad_events where client_event_id = 'd1'), 'new document: before null');
select pg_temp.check((pg_temp.go('document.saved', 'd2', '{"kind":"passport","holder":"أمير","expires_on":"2033-05-10"}') ->> 'ok')::boolean, 'document renewed');
select pg_temp.check((select count(*) = 1 and max(expires_on) = date '2033-05-10' from zad_documents where kind = 'passport'), 'renewal updates the same row');
select pg_temp.check((select payload -> 'before' ->> 'expires_on' = '2028-05-10' from zad_events where client_event_id = 'd2'), 'renewal keeps the old date');
select pg_temp.check((pg_temp.go('document.saved', 'd3', '{"kind":"other","label":"كارنيه النادي","expires_on":"2027-01-01"}') ->> 'ok')::boolean, 'other with a label');
select pg_temp.check(pg_temp.go('document.saved', 'd4', '{"kind":"other","expires_on":"2027-01-01"}') ->> 'reason' = 'label_required', 'other needs a label');
select pg_temp.check(pg_temp.go('document.saved', 'd5', '{"kind":"visa","expires_on":"2027-01-01"}') ->> 'reason' = 'kind_invalid', 'unknown kind');
select pg_temp.check(pg_temp.go('document.saved', 'd6', '{"kind":"passport","expires_on":"2027-13-01"}') ->> 'reason' = 'day_invalid', 'bad date');
select pg_temp.check(pg_temp.go('document.saved', 'd7', '{"kind":"passport","expires_on":"2101-01-01"}') ->> 'reason' = 'date_out_of_range', 'out of range');
select pg_temp.check(pg_temp.go('document.saved', 'd8', '{"kind":"passport","holder":" أمير","expires_on":"2027-01-01"}') ->> 'reason' = 'holder_invalid', 'untrimmed holder');
select pg_temp.check(pg_temp.go('document.saved', 'd9', '{"kind":"passport","holder":"' || repeat('ا', 41) || '","expires_on":"2027-01-01"}') ->> 'reason' = 'holder_invalid', 'long holder');
select pg_temp.check(pg_temp.go('document.saved', 'd10', '{"kind":"other","label":"' || repeat('ب', 41) || '","expires_on":"2027-01-01"}') ->> 'reason' = 'label_invalid', 'long label');
-- نفس النوع لمستخدم تاني صف تاني، ومايلمسش صف الأول.
select pg_temp.check((pg_temp.go2('document.saved', 'd11', '{"kind":"passport","holder":"أمير","expires_on":"2040-01-01"}') ->> 'ok')::boolean, 'second user saves the same kind');
select pg_temp.check((select expires_on = date '2033-05-10' from zad_documents where user_id = '11111111-1111-1111-1111-111111111111' and kind = 'passport'), 'first user row untouched');
select pg_temp.check(pg_temp.go2('document.deleted', 'd12', jsonb_build_object('item_id', (select id from zad_documents where user_id = '11111111-1111-1111-1111-111111111111' and kind = 'passport'))::text) ->> 'reason' = 'item_not_found', 'other user delete refused');
select pg_temp.check((pg_temp.go('document.deleted', 'd13', jsonb_build_object('item_id', (select id from zad_documents where user_id = '11111111-1111-1111-1111-111111111111' and kind = 'passport'))::text) ->> 'ok')::boolean, 'document deleted');
select pg_temp.check((select payload -> 'before' ->> 'holder' = 'أمير' and payload -> 'after' = 'null'::jsonb from zad_events where client_event_id = 'd13'), 'delete keeps the row as before');
select pg_temp.check(not exists (select 1 from zad_documents where user_id = '11111111-1111-1111-1111-111111111111' and kind = 'passport'), 'passport gone');
select pg_temp.check((select count(*) from zad_documents where user_id = '22222222-2222-2222-2222-222222222222') = 1, 'other user still has theirs');
select pg_temp.check(pg_temp.go('document.deleted', 'd14', '{"item_id":"00000000-0000-0000-0000-000000000000"}') ->> 'reason' = 'item_not_found', 'missing id');
select pg_temp.check((select count(*) from zad_guard_events where intent ->> 'client_event_id' in ('d4','d5','d6','d7','d8','d9','d10','d12','d14')) = 9, 'every document refusal logged');

-- ═══ مواعيد ═══
select pg_temp.check((pg_temp.go('appointment.added', 'a1', '{"title":" دكتور أسنان ","kind":"medical","starts_at":"2026-12-01T17:00:00+03:00","place_label":"عيادة النور","remind_minutes_before":60,"recurrence":"once","source":"chat","for_person":"ماما","expected_cost":400.456}') ->> 'ok')::boolean, 'appointment added');
select pg_temp.check((select title = 'دكتور أسنان' and kind = 'medical' and starts_at = '2026-12-01T14:00:00Z' and place_label = 'عيادة النور'
                         and remind_minutes_before = 60 and source = 'chat' and for_person = 'ماما' and expected_cost = 400.46
                        from zad_appointments where user_id = '11111111-1111-1111-1111-111111111111'), 'row as the tool built it');
select pg_temp.check((pg_temp.go('appointment.added', 'a2', '{"title":"اتصال","starts_at":"2026-12-02T10:00:00Z"}') ->> 'ok')::boolean, 'defaults');
select pg_temp.check((select kind = 'personal' and remind_minutes_before = 0 and recurrence = 'once' and source = 'chat' and status = 'upcoming'
                        and place_label is null and for_person is null and expected_cost is null from zad_appointments where title = 'اتصال'), 'defaults applied');
select pg_temp.check(pg_temp.go('appointment.added', 'a3', '{"title":"ا","starts_at":"2026-12-02T10:00:00Z"}') ->> 'reason' = 'appt_title_invalid', 'short title');
select pg_temp.check(pg_temp.go('appointment.added', 'a4', '{"title":"اجتماع","starts_at":"بكرة"}') ->> 'reason' = 'starts_at_invalid', 'bad time');
select pg_temp.check(pg_temp.go('appointment.added', 'a5', '{"title":"اجتماع","starts_at":"2026-12-02T10:00:00Z","kind":"party"}') ->> 'reason' = 'kind_invalid', 'bad kind');
select pg_temp.check(pg_temp.go('appointment.added', 'a6', '{"title":"اجتماع","starts_at":"2026-12-02T10:00:00Z","recurrence":"minutely"}') ->> 'reason' = 'appt_recurrence_invalid', 'bad recurrence');
select pg_temp.check(pg_temp.go('appointment.added', 'a7', '{"title":"اجتماع","starts_at":"2026-12-02T10:00:00Z","remind_minutes_before":10081}') ->> 'reason' = 'remind_invalid', 'remind too long');
select pg_temp.check(pg_temp.go('appointment.added', 'a8', '{"title":"اجتماع","starts_at":"2026-12-02T10:00:00Z","remind_minutes_before":1.5}') ->> 'reason' = 'remind_invalid', 'remind fractional');
select pg_temp.check(pg_temp.go('appointment.added', 'a9', '{"title":"اجتماع","starts_at":"2026-12-02T10:00:00Z","place_label":"' || repeat('م', 121) || '"}') ->> 'reason' = 'place_too_long', 'place too long');
select pg_temp.check(pg_temp.go('appointment.added', 'a10', '{"title":"اجتماع","starts_at":"2026-12-02T10:00:00Z","for_person":"' || repeat('ا', 41) || '"}') ->> 'reason' = 'for_person_invalid', 'for_person too long');
select pg_temp.check(pg_temp.go('appointment.added', 'a11', '{"title":"اجتماع","starts_at":"2026-12-02T10:00:00Z","expected_cost":0}') ->> 'reason' = 'cost_invalid', 'cost zero');
select pg_temp.check(pg_temp.go('appointment.added', 'a12', '{"title":"اجتماع","starts_at":"2026-12-02T10:00:00Z","expected_cost":2000000}') ->> 'reason' = 'cost_invalid', 'cost over cap');
select pg_temp.check(pg_temp.go('appointment.added', 'a13', '{"title":"اجتماع","starts_at":"2026-12-02T10:00:00Z","source":"fax"}') ->> 'reason' = 'source_invalid', 'bad source');
select pg_temp.check((select count(*) from zad_appointments) = 2, 'refusals wrote nothing');

select pg_temp.check((pg_temp.go('appointment.updated', 'a14', jsonb_build_object('item_id', (select id from zad_appointments where title = 'اتصال'),
  'patch', '{"status":"done","title":"اتصال بالعميل","place_label":"مكتب","remind_minutes_before":15,"recurrence":"weekly","starts_at":"2026-12-03T09:00:00+02:00","expected_cost":75}'::jsonb)::text) ->> 'ok')::boolean, 'appointment updated');
select pg_temp.check((select status = 'done' and title = 'اتصال بالعميل' and place_label = 'مكتب' and remind_minutes_before = 15 and recurrence = 'weekly'
                         and starts_at = '2026-12-03T07:00:00Z' and expected_cost = 75 and updated_at >= created_at from zad_appointments where id = (select (payload ->> 'row_id')::uuid from zad_events where client_event_id = 'a14')), 'every patched field moved');
select pg_temp.check((select payload -> 'before' ->> 'status' = 'upcoming' and payload -> 'before' ->> 'title' = 'اتصال' and payload -> 'after' ->> 'status' = 'done' from zad_events where client_event_id = 'a14'), 'update keeps before and after');
select pg_temp.check((pg_temp.go('appointment.updated', 'a15', jsonb_build_object('item_id', (select id from zad_appointments where title = 'اتصال بالعميل'),
  'patch', '{"place_label":null,"expected_cost":null}'::jsonb)::text) ->> 'ok')::boolean, 'null clears place and cost');
select pg_temp.check((select place_label is null and expected_cost is null and title = 'اتصال بالعميل' from zad_appointments where title = 'اتصال بالعميل'), 'cleared, rest untouched');
select pg_temp.check(pg_temp.go('appointment.updated', 'a16', jsonb_build_object('item_id', (select id from zad_appointments limit 1), 'patch', '{}'::jsonb)::text) ->> 'reason' = 'patch_empty', 'empty patch');
select pg_temp.check(pg_temp.go('appointment.updated', 'a17', jsonb_build_object('item_id', (select id from zad_appointments limit 1), 'patch', '{"for_person":"x"}'::jsonb)::text) ->> 'reason' = 'patch_field_unknown', 'unknown field');
select pg_temp.check(pg_temp.go('appointment.updated', 'a18', jsonb_build_object('item_id', (select id from zad_appointments limit 1), 'patch', '{"status":"postponed"}'::jsonb)::text) ->> 'reason' = 'status_invalid', 'bad status');
select pg_temp.check(pg_temp.go('appointment.updated', 'a19', jsonb_build_object('item_id', (select id from zad_appointments limit 1), 'patch', '{"title":null}'::jsonb)::text) ->> 'reason' = 'appt_title_invalid', 'null title');
select pg_temp.check(pg_temp.go('appointment.updated', 'a20', jsonb_build_object('item_id', (select id from zad_appointments limit 1), 'patch', '{"expected_cost":-1}'::jsonb)::text) ->> 'reason' = 'cost_invalid', 'negative cost');
select pg_temp.check(pg_temp.go('appointment.updated', 'a21', jsonb_build_object('item_id', (select id from zad_appointments limit 1), 'patch', '{"remind_minutes_before":-1}'::jsonb)::text) ->> 'reason' = 'remind_invalid', 'negative remind');
select pg_temp.check(pg_temp.go('appointment.updated', 'a22', jsonb_build_object('item_id', (select id from zad_appointments limit 1), 'patch', '{"starts_at":"later"}'::jsonb)::text) ->> 'reason' = 'starts_at_invalid', 'bad new time');
select pg_temp.check(pg_temp.go2('appointment.updated', 'a23', jsonb_build_object('item_id', (select id from zad_appointments limit 1), 'patch', '{"status":"cancelled"}'::jsonb)::text) ->> 'reason' = 'item_not_found', 'other user update refused');
select pg_temp.check(pg_temp.go2('appointment.deleted', 'a24', jsonb_build_object('item_id', (select id from zad_appointments limit 1))::text) ->> 'reason' = 'item_not_found', 'other user delete refused');
select pg_temp.check((select count(*) = 2 and count(*) filter (where status = 'cancelled') = 0 from zad_appointments), 'other user left them alone');
select pg_temp.check((pg_temp.go('appointment.deleted', 'a25', jsonb_build_object('item_id', (select id from zad_appointments where title = 'دكتور أسنان'))::text) ->> 'ok')::boolean, 'appointment deleted');
select pg_temp.check((select payload -> 'before' ->> 'title' = 'دكتور أسنان' and payload -> 'before' ->> 'for_person' = 'ماما' and payload -> 'after' = 'null'::jsonb from zad_events where client_event_id = 'a25'), 'delete keeps the full row as before');
select pg_temp.check((select count(*) = 1 from zad_appointments), 'one left');
select pg_temp.check(pg_temp.go('appointment.deleted', 'a26', '{"item_id":"x"}') ->> 'reason' = 'item_not_found', 'bad id');
select pg_temp.check(pg_temp.go('appointment.snooze', 'a27', '{}') ->> 'reason' = 'unknown_kind', 'unknown appointment kind');
select pg_temp.check((select count(*) from zad_guard_events where intent ->> 'client_event_id' in
  ('a3','a4','a5','a6','a7','a8','a9','a10','a11','a12','a13','a16','a17','a18','a19','a20','a21','a22','a23','a24','a26','a27')) = 22, 'every appointment refusal logged');

-- تكرار: نفس المفتاح مايكتبش تاني.
select pg_temp.check((pg_temp.go('appointment.added', 'a1', '{"title":"تاني","starts_at":"2026-12-05T10:00:00Z"}') ->> 'duplicate')::boolean, 'duplicate key answered as duplicate');
select pg_temp.check((select count(*) from zad_appointments) = 1, 'duplicate wrote nothing');

select 'commit_intent_home: all checks passed';
