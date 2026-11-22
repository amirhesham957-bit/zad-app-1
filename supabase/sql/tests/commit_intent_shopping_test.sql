-- ZAD_OR_PLAN م٢.٥: قايمة التسوق من الباب — إضافة وتزويد وشطب وحذف، قايمة البيت بس، والتكرار.
\set ON_ERROR_STOP on
create or replace function pg_temp.check(cond boolean, what text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAILED: %', what; end if; end $$;
create or replace function pg_temp.ci(j text) returns jsonb language sql as $$ select zad_commit_intent(j::jsonb) $$;

insert into family_members values ('f0000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111'),
                                  ('f0000000-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222');
insert into zad_shopping_list (id, user_id, item_name, quantity, is_purchased, family_id) values
  ('b0000000-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 'لبن', 1, false, 'f0000000-0000-0000-0000-000000000001'),
  ('b0000000-0000-0000-0000-000000000002', '33333333-3333-3333-3333-333333333333', 'عيش', 1, false, null),
  ('b0000000-0000-0000-0000-000000000003', '22222222-2222-2222-2222-222222222222', 'جبنة', 1, true, 'f0000000-0000-0000-0000-000000000001'),
  -- صف العميل نفسه بعيلة قديمة: لسه بتاعه (RLS بتاعة القايمة بتسمح بصف العميل مهما كانت عيلته).
  ('b0000000-0000-0000-0000-000000000004', '11111111-1111-1111-1111-111111111111', 'سكر', 2, false, 'f0000000-0000-0000-0000-000000000099');

-- ١) سطر جديد: كمية كسر بتتقرّب لفوق.
select pg_temp.check((pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"shopping.added","client_event_id":"s1","payload":{"item_name":"زيت","quantity":1.5}}') ->> 'after')::int = 2, 'new line, 1.5 -> 2');
select pg_temp.check((select quantity = 2 and not is_purchased from zad_shopping_list where item_name = 'زيت'), 'row written');
-- نفس الطلب تاني: مفيش سطر تاني.
select pg_temp.check((pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"shopping.added","client_event_id":"s1","payload":{"item_name":"زيت","quantity":1.5}}') ->> 'duplicate')::boolean, 'repeat is a duplicate');
select pg_temp.check((select count(*) from zad_shopping_list where item_name = 'زيت') = 1, 'one oil line');

-- ٢) تزويد على سطر الأم المفتوح.
select pg_temp.check((pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"shopping.added","client_event_id":"s2","payload":{"item_id":"b0000000-0000-0000-0000-000000000001","item_name":"لبن","quantity":2}}') ->> 'after')::int = 3, 'top-up mom''s line');
-- على سطر اتشطب: مرفوض.
select pg_temp.check(pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"shopping.added","client_event_id":"s3","payload":{"item_id":"b0000000-0000-0000-0000-000000000003","item_name":"جبنة","quantity":1}}') ->> 'reason' = 'already_purchased', 'no top-up on a bought line');

-- ٣) الشطب: مرة واحدة.
select pg_temp.check((pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"shopping.completed","client_event_id":"s4","payload":{"item_id":"b0000000-0000-0000-0000-000000000001"}}') ->> 'ok')::boolean, 'tick ok');
select pg_temp.check((select is_purchased from zad_shopping_list where id = 'b0000000-0000-0000-0000-000000000001'), 'ticked');
select pg_temp.check(pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"shopping.completed","client_event_id":"s5","payload":{"item_id":"b0000000-0000-0000-0000-000000000001"}}') ->> 'reason' = 'already_purchased', 'second tick refused');

-- ٤) الحذف، وصف العميل نفسه بعيلة قديمة لسه بتاعه.
select pg_temp.check((pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"shopping.deleted","client_event_id":"s6","payload":{"item_id":"b0000000-0000-0000-0000-000000000004"}}') ->> 'ok')::boolean, 'own line deleted');
select pg_temp.check((select payload -> 'before' ->> 'item_name' = 'سكر' from zad_events where client_event_id = 's6'), 'event keeps the row');

-- ٥) بيت تاني: لا شطب ولا حذف، والسبب متسجل.
select pg_temp.check(pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"shopping.deleted","client_event_id":"s7","payload":{"item_id":"b0000000-0000-0000-0000-000000000002"}}') ->> 'reason' = 'item_not_found', 'other household refused');
select pg_temp.check(exists (select 1 from zad_shopping_list where id = 'b0000000-0000-0000-0000-000000000002'), 'other household untouched');
select pg_temp.check(exists (select 1 from zad_guard_events where reason = 'item_not_found' and intent ->> 'client_event_id' = 's7'), 'refusal logged');

-- ٦) القيود.
select pg_temp.check(pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"shopping.added","client_event_id":"s8","payload":{"item_name":"بيض","quantity":0}}') ->> 'reason' = 'qty_not_positive', 'zero');
select pg_temp.check(pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"shopping.added","client_event_id":"s9","payload":{"item_name":"بيض","quantity":500}}') ->> 'reason' = 'qty_too_large', 'too many');
select pg_temp.check(pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"shopping.added","client_event_id":"s10","payload":{"item_name":"ب","quantity":1}}') ->> 'reason' = 'name_invalid', 'name');
select pg_temp.check(pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"shopping.emptied","client_event_id":"s11","payload":{}}') ->> 'reason' = 'unknown_kind', 'unknown shopping kind');

-- ٧) المخزن لسه شغال من نفس الباب.
select pg_temp.check((pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"inventory.added","client_event_id":"s12","payload":{"item_name":"زيت","quantity":1,"category":"البقالة"}}') ->> 'ok')::boolean, 'pantry still through the door');

-- ٨) دالة المجال مقفولة على السيرفر.
set role service_role;
do $$ begin
  perform zad_intent_shopping('11111111-1111-1111-1111-111111111111', 'shopping.deleted', '{}'::jsonb, now());
  raise exception 'FAILED: service_role can call zad_intent_shopping';
exception when insufficient_privilege then null;
end $$;
reset role;

select 'commit_intent_shopping: all checks passed';
