-- ZAD_OR_PLAN م٢.٢: الباب الوحيد — القيود، الحدث مع الكتابة، الرفض بسبب، التكرار، ومخزن البيت بس.
\set ON_ERROR_STOP on
create or replace function pg_temp.check(cond boolean, what text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAILED: %', what; end if; end $$;
create or replace function pg_temp.ci(j text) returns jsonb language sql as $$ select zad_commit_intent(j::jsonb) $$;

-- المستخدم ١ (أمير) و٢ في نفس العيلة، و٣ برا. السيرفر من غير JWT عميل.
insert into family_members values ('f0000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111'),
                                  ('f0000000-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222');
insert into zad_inventory (id, user_id, item_name, quantity, unit, family_id) values
  ('a0000000-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 'لبن', 3, 'علبة', 'f0000000-0000-0000-0000-000000000001'),
  ('a0000000-0000-0000-0000-000000000002', '33333333-3333-3333-3333-333333333333', 'رز', 5, 'كيلو', null);

-- ١) إضافة: الصف والحدث مع بعض، والفرد «أنا» تلقائي.
select pg_temp.check((pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"inventory.added","client_event_id":"e1","payload":{"item_name":"زيت","quantity":2,"category":"البقالة","expiry_date":"2027-01-01"}}') ->> 'ok')::boolean, 'add ok');
select pg_temp.check(exists (select 1 from zad_inventory where item_name = 'زيت' and quantity = 2 and unit = 'حبة'), 'row written, unit defaults to حبة');
select pg_temp.check((select member_id = zad_self_member('11111111-1111-1111-1111-111111111111') and source = 'model' from zad_events where client_event_id = 'e1'), 'event by self, source model');

-- ٢) نفس المفتاح تاني: نفس النتيجة، صف واحد بس.
select pg_temp.check((pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"inventory.added","client_event_id":"e1","payload":{"item_name":"زيت","quantity":2,"category":"البقالة"}}') ->> 'duplicate')::boolean, 'duplicate recognised');
select pg_temp.check((select count(*) from zad_inventory where item_name = 'زيت') = 1, 'no second row');

-- ٣) استهلاك من صنف العيلة (بتاع المستخدم ٢): مسموح، والكمية بتقف عند صفر.
select pg_temp.check((pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"inventory.consumed","client_event_id":"e2","payload":{"item_id":"a0000000-0000-0000-0000-000000000001","amount":5}}') ->> 'after')::numeric = 0, 'consumed past zero stops at zero');
select pg_temp.check((select quantity from zad_inventory where id = 'a0000000-0000-0000-0000-000000000001') = 0, 'family row updated');
select pg_temp.check((select (payload ->> 'before')::numeric from zad_events where client_event_id = 'e2') = 3, 'event keeps before');

-- ٤) صنف بيت تاني: مرفوض، مفيش كتابة، والسبب متسجل.
select pg_temp.check(pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"inventory.quantity_set","client_event_id":"e3","payload":{"item_id":"a0000000-0000-0000-0000-000000000002","quantity":0}}') ->> 'reason' = 'item_not_found', 'other household refused');
select pg_temp.check((select quantity from zad_inventory where id = 'a0000000-0000-0000-0000-000000000002') = 5, 'other household untouched');
select pg_temp.check(exists (select 1 from zad_guard_events where reason = 'item_not_found' and user_id = '11111111-1111-1111-1111-111111111111'), 'guard event written');
select pg_temp.check(not exists (select 1 from zad_events where client_event_id = 'e3'), 'no event on refusal');

-- ٥) القيود.
select pg_temp.check(pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"inventory.quantity_set","client_event_id":"e4","payload":{"item_id":"a0000000-0000-0000-0000-000000000001","quantity":-1}}') ->> 'reason' = 'qty_negative', 'negative quantity');
select pg_temp.check(pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"inventory.quantity_set","client_event_id":"e5","payload":{"item_id":"a0000000-0000-0000-0000-000000000001","quantity":101}}') ->> 'reason' = 'qty_too_large', 'quantity jump');
select pg_temp.check(pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"inventory.added","client_event_id":"e6","payload":{"item_name":"تونة","quantity":1,"category":"سلاح"}}') ->> 'reason' = 'category_unknown', 'category list');
select pg_temp.check(pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"inventory.added","client_event_id":"e7","occurred_at":"2026-11-21T10:00:00Z","payload":{"item_name":"زبادي","quantity":1,"category":"الألبان","expiry_date":"2026-11-01"}}') ->> 'reason' = 'expiry_before_purchase', 'expiry before purchase');
select pg_temp.check(pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"inventory.added","client_event_id":"e8","payload":{"item_name":"زبادي","quantity":1,"category":"الألبان","expiry_date":"بكرة"}}') ->> 'reason' = 'expiry_bad_format', 'expiry format');
select pg_temp.check(pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"inventory.consumed","client_event_id":"e9","payload":{"item_id":"a0000000-0000-0000-0000-000000000001","amount":0,"opened":"yes"}}') ->> 'reason' = 'amount_invalid', 'zero amount needs opened=true, no crash on a bad flag');
select pg_temp.check(pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"inventory.deleted","client_event_id":"e10","payload":{}}') ->> 'reason' = 'unknown_kind', 'unknown kind');
select pg_temp.check(pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"inventory.added","client_event_id":"e11","member_id":"' || zad_self_member('33333333-3333-3333-3333-333333333333') || '","payload":{"item_name":"شاي","quantity":1,"category":"المشروبات"}}') ->> 'reason' = 'member_not_in_household', 'member from another house');

-- NaN وInfinity: Postgres بيعتبر NaN أكبر من أي رقم، فحدود فوق بتمسكه.
select pg_temp.check(pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"inventory.added","client_event_id":"n1","payload":{"item_name":"ملح","quantity":"NaN","category":"البقالة"}}') ->> 'ok' = 'false', 'NaN quantity refused');
select pg_temp.check(pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"inventory.added","client_event_id":"n2","payload":{"item_name":"ملح","quantity":"Infinity","category":"البقالة"}}') ->> 'ok' = 'false', 'Infinity quantity refused');
select pg_temp.check(pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"inventory.consumed","client_event_id":"n3","payload":{"item_id":"a0000000-0000-0000-0000-000000000001","amount":"NaN"}}') ->> 'ok' = 'false', 'NaN amount refused');
select pg_temp.check(pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"inventory.quantity_set","client_event_id":"n4","payload":{"item_id":"a0000000-0000-0000-0000-000000000001","quantity":"-Infinity"}}') ->> 'ok' = 'false', '-Infinity refused');
select pg_temp.check(not exists (select 1 from zad_inventory where item_name = 'ملح'), 'nothing written');

-- ٦) JWT عميل: user_id اللي في النية مابيتقراش. من غير sub = مرفوض.
select set_config('request.jwt.claims', '{"role":"authenticated"}', false);
select pg_temp.check(pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"inventory.added","client_event_id":"e12","payload":{"item_name":"سكر","quantity":1,"category":"البقالة"}}') ->> 'reason' = 'not_authenticated', 'client JWT without sub refused');
select set_config('request.jwt.claims', '{"role":"authenticated","sub":"33333333-3333-3333-3333-333333333333"}', false);
select pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"inventory.added","client_event_id":"e13","payload":{"item_name":"سكر","quantity":1,"category":"البقالة"}}');
select pg_temp.check((select user_id from zad_inventory where item_name = 'سكر') = '33333333-3333-3333-3333-333333333333', 'client JWT wins over intent user_id');
select set_config('request.jwt.claims', '{}', false);

-- ٧) الموبايل مايقدرش ينادي الباب لسه (م٢.٤).
set role authenticated;
do $$ begin
  perform zad_commit_intent('{}'::jsonb);
  raise exception 'FAILED: authenticated can call zad_commit_intent';
exception when insufficient_privilege then null;
end $$;
reset role;

select 'commit_intent: all checks passed';
