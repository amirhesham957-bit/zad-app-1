-- ZAD_OR_PLAN م٢.٥: الصيدلية من الباب — إضافة (لنفسه ولفرد موافق)، تعديل بحقول معروفة بس، حذف، وجرعة من كاتبها الوحيد.
\set ON_ERROR_STOP on
create or replace function pg_temp.check(cond boolean, what text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAILED: %', what; end if; end $$;
create or replace function pg_temp.ci(j text) returns jsonb language sql as $$ select zad_commit_intent(j::jsonb) $$;

-- ١ و٤ (ماما) في عيلة، وماما وافقت إن ١ يتابع أدويتها. ٢ في نفس العيلة ومش موافق. ٣ برا.
insert into family_members values ('f0000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111'),
                                  ('f0000000-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222'),
                                  ('f0000000-0000-0000-0000-000000000001', '44444444-4444-4444-4444-444444444444');
insert into scratch_medicine_grants values ('11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444444');
insert into zad_pharmacy_items (id, user_id, name, remaining_quantity, dose_times, daily_dose_count) values
  ('c0000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'كونكور', 10, '08:00', 1),
  ('c0000000-0000-0000-0000-000000000002', '22222222-2222-2222-2222-222222222222', 'بنادول', 5, null, 1),
  ('c0000000-0000-0000-0000-000000000003', '33333333-3333-3333-3333-333333333333', 'أسبرين', 5, null, 1);

-- ١) إضافة لنفسه: العدد من المواعيد مش من اللي اتبعت.
select pg_temp.check((pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"pharmacy.added","client_event_id":"p1","payload":{"name":"جلوكوفاج","dose_times":"08:00,20:00","daily_dose_count":3,"remaining_quantity":30,"unit":"قرص"}}') ->> 'ok')::boolean, 'add own');
select pg_temp.check((select daily_dose_count = 2 and remaining_quantity = 30 and user_id = '11111111-1111-1111-1111-111111111111' from zad_pharmacy_items where name = 'جلوكوفاج'), 'count follows the times');
-- نفس الطلب تاني: مفيش دوا تاني (ده اللي عمل منبهين لنفس الدوا ١٥/٨).
select pg_temp.check((pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"pharmacy.added","client_event_id":"p1","payload":{"name":"جلوكوفاج","dose_times":"08:00,20:00"}}') ->> 'duplicate')::boolean, 'repeat is a duplicate');
select pg_temp.check((select count(*) from zad_pharmacy_items where name = 'جلوكوفاج') = 1, 'one row');

-- ٢) لماما (موافقة): في صيدليتها. لـ٢ (مش موافق) ولـ٣ (برا): مرفوض ومتسجل.
select pg_temp.check((pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"pharmacy.added","client_event_id":"p2","payload":{"owner_id":"44444444-4444-4444-4444-444444444444","name":"فولتارين"}}') ->> 'ok')::boolean, 'add to a consenting member');
select pg_temp.check(exists (select 1 from zad_pharmacy_items where name = 'فولتارين' and user_id = '44444444-4444-4444-4444-444444444444'), 'in her pharmacy');
select pg_temp.check(pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"pharmacy.added","client_event_id":"p3","payload":{"owner_id":"22222222-2222-2222-2222-222222222222","name":"فيتامين د"}}') ->> 'reason' = 'member_not_granted', 'no consent, no write');
select pg_temp.check(pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"pharmacy.added","client_event_id":"p4","payload":{"owner_id":"33333333-3333-3333-3333-333333333333","name":"فيتامين د"}}') ->> 'reason' = 'member_not_granted', 'outside the family');
select pg_temp.check(not exists (select 1 from zad_pharmacy_items where name = 'فيتامين د'), 'nothing written');
select pg_temp.check((select count(*) from zad_guard_events where reason = 'member_not_granted') = 2, 'both refusals logged');

-- ٣) التعديل: الحقول المعروفة بس، والقديم في الحدث.
select pg_temp.check((pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"pharmacy.updated","client_event_id":"p5","payload":{"item_id":"c0000000-0000-0000-0000-000000000001","patch":{"dose_times":"08:00,14:00,22:00","remaining_quantity":20}}}') ->> 'ok')::boolean, 'update own');
select pg_temp.check((select dose_times = '08:00,14:00,22:00' and daily_dose_count = 3 and remaining_quantity = 20 from zad_pharmacy_items where id = 'c0000000-0000-0000-0000-000000000001'), 'patched, count from times');
select pg_temp.check((select payload -> 'before' ->> 'dose_times' = '08:00' and (payload -> 'before' ->> 'remaining_quantity')::int = 10 from zad_events where client_event_id = 'p5'), 'event keeps the old values');
select pg_temp.check(pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"pharmacy.updated","client_event_id":"p6","payload":{"item_id":"c0000000-0000-0000-0000-000000000001","patch":{"user_id":"33333333-3333-3333-3333-333333333333"}}}') ->> 'reason' = 'patch_field_unknown', 'owner cannot be patched');
select pg_temp.check(pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"pharmacy.updated","client_event_id":"p7","payload":{"item_id":"c0000000-0000-0000-0000-000000000001","patch":{"dose_times":"24:00"}}}') ->> 'reason' = 'dose_times_invalid', '24:00 is not a time');
select pg_temp.check(pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"pharmacy.updated","client_event_id":"p8","payload":{"item_id":"c0000000-0000-0000-0000-000000000001","patch":{"remaining_quantity":-3}}}') ->> 'reason' = 'qty_invalid', 'negative stock');
select pg_temp.check(pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"pharmacy.updated","client_event_id":"p9","payload":{"item_id":"c0000000-0000-0000-0000-000000000001","patch":{}}}') ->> 'reason' = 'patch_empty', 'empty patch');
select pg_temp.check(pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"pharmacy.updated","client_event_id":"p10","payload":{"item_id":"c0000000-0000-0000-0000-000000000002","patch":{"remaining_quantity":0}}}') ->> 'reason' = 'item_not_found', 'a non-consenting member''s medicine');
select pg_temp.check((select remaining_quantity from zad_pharmacy_items where id = 'c0000000-0000-0000-0000-000000000002') = 5, 'untouched');

-- ٤) الجرعة: الكمية بتنزل مرة واحدة، والتكرار في نص ساعة مرفوض ومتسجل.
select pg_temp.check((pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"pharmacy.dose_taken","client_event_id":"p11","payload":{"item_id":"c0000000-0000-0000-0000-000000000001"}}') -> 'payload' ->> 'after')::int = 19, 'dose: 20 -> 19');
select pg_temp.check(pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"pharmacy.dose_taken","client_event_id":"p12","payload":{"item_id":"c0000000-0000-0000-0000-000000000001"}}') ->> 'reason' = 'dose_already_logged', 'second dose in the window refused');
select pg_temp.check((select remaining_quantity from zad_pharmacy_items where id = 'c0000000-0000-0000-0000-000000000001') = 19, 'stock taken once');
-- جرعة على دوا ماما: لأ (الجرعة لصاحبها بس، زي الأداة).
select pg_temp.check(pg_temp.ci(format('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"pharmacy.dose_taken","client_event_id":"p13","payload":{"item_id":"%s"}}',
  (select id from zad_pharmacy_items where name = 'فولتارين'))) ->> 'reason' = 'item_not_found', 'dose only on own medicine');

-- ٥) الحذف، والبيت التاني.
select pg_temp.check((pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"pharmacy.deleted","client_event_id":"p14","payload":{"item_id":"c0000000-0000-0000-0000-000000000001"}}') ->> 'ok')::boolean, 'delete own');
select pg_temp.check((select payload -> 'before' ->> 'name' = 'كونكور' from zad_events where client_event_id = 'p14'), 'event keeps the row');
select pg_temp.check(pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"pharmacy.deleted","client_event_id":"p15","payload":{"item_id":"c0000000-0000-0000-0000-000000000003"}}') ->> 'reason' = 'item_not_found', 'other household refused');
select pg_temp.check(exists (select 1 from zad_pharmacy_items where id = 'c0000000-0000-0000-0000-000000000003'), 'other household untouched');

-- ٦) المجالات التانية لسه شغالة، ودوال المجال مقفولة.
select pg_temp.check((pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"shopping.added","client_event_id":"p16","payload":{"item_name":"شاش","quantity":1}}') ->> 'ok')::boolean, 'shopping still works');
set role service_role;
do $$ begin
  perform zad_intent_pharmacy('11111111-1111-1111-1111-111111111111', 'pharmacy.deleted', '{}'::jsonb, now());
  raise exception 'FAILED: service_role can call zad_intent_pharmacy';
exception when insufficient_privilege then null;
end $$;
do $$ begin
  perform zad_intent_pharmacy_can_write('11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444444');
  raise exception 'FAILED: service_role can call zad_intent_pharmacy_can_write';
exception when insufficient_privilege then null;
end $$;
reset role;

select 'commit_intent_pharmacy: all checks passed';
