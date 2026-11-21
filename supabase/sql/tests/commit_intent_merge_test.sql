-- ZAD_OR_PLAN م٢.٥: inventory.added بـitem_id = تزويد على صف البيت، مش صف تاني. والباقي زي م٢.٢.
\set ON_ERROR_STOP on
create or replace function pg_temp.check(cond boolean, what text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAILED: %', what; end if; end $$;
create or replace function pg_temp.ci(j text) returns jsonb language sql as $$ select zad_commit_intent(j::jsonb) $$;

insert into family_members values ('f0000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111'),
                                  ('f0000000-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222');
insert into zad_inventory (id, user_id, item_name, quantity, unit, category, expiry_date, family_id) values
  ('a0000000-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 'لبن', 1, 'علبة', 'الألبان', '2026-12-01', 'f0000000-0000-0000-0000-000000000001'),
  ('a0000000-0000-0000-0000-000000000002', '33333333-3333-3333-3333-333333333333', 'رز', 5, 'كيلو', null, null, null),
  ('a0000000-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111', 'عيش', -2, 'رغيف', null, null, null);

-- ١) «اشتريت ٢ لبن» والأم ضافت لبن: نفس الصف بيتزوّد، الفئة القديمة بتفضل، والصلاحية الجديدة بتغلب.
select pg_temp.check((pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"inventory.added","client_event_id":"m1","payload":{"item_id":"a0000000-0000-0000-0000-000000000001","item_name":"لبن","quantity":2,"category":"المشروبات","expiry_date":"2027-01-10"}}') ->> 'after')::numeric = 3, 'merge adds to the row');
select pg_temp.check((select count(*) from zad_inventory where item_name = 'لبن') = 1, 'no second milk row');
select pg_temp.check((select category = 'الألبان' and expiry_date = '2027-01-10' from zad_inventory where id = 'a0000000-0000-0000-0000-000000000001'), 'old category kept, new expiry wins');
select pg_temp.check((select (payload ->> 'before')::numeric = 1 and (payload ->> 'after')::numeric = 3 and payload ->> 'row_id' = 'a0000000-0000-0000-0000-000000000001'
                      from zad_events where client_event_id = 'm1'), 'event keeps before/after/row');

-- ٢) نفس الطلب تاني: مفيش تزويد تاني.
select pg_temp.check((pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"inventory.added","client_event_id":"m1","payload":{"item_id":"a0000000-0000-0000-0000-000000000001","item_name":"لبن","quantity":2,"category":"الألبان"}}') ->> 'duplicate')::boolean, 'duplicate merge recognised');
select pg_temp.check((select quantity from zad_inventory where id = 'a0000000-0000-0000-0000-000000000001') = 3, 'still 3 after the repeat');

-- ٣) من غير تاريخ صلاحية: القديم بيفضل. وكمية سالبة قديمة بتتعامل كصفر.
select pg_temp.check((pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"inventory.added","client_event_id":"m2","payload":{"item_id":"a0000000-0000-0000-0000-000000000003","item_name":"عيش","quantity":4,"category":"البقالة"}}') ->> 'after')::numeric = 4, 'negative stock counts as zero');
select pg_temp.check((select category = 'البقالة' and expiry_date is null from zad_inventory where id = 'a0000000-0000-0000-0000-000000000003'), 'empty category filled, no expiry invented');

-- ٤) صنف بيت تاني بـitem_id: مرفوض، متسجل، ومحدش اتلمس.
select pg_temp.check(pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"inventory.added","client_event_id":"m3","payload":{"item_id":"a0000000-0000-0000-0000-000000000002","item_name":"رز","quantity":1,"category":"البقالة"}}') ->> 'reason' = 'item_not_found', 'other household refused');
select pg_temp.check((select quantity from zad_inventory where id = 'a0000000-0000-0000-0000-000000000002') = 5, 'other household untouched');
select pg_temp.check(exists (select 1 from zad_guard_events where reason = 'item_not_found' and intent ->> 'client_event_id' = 'm3'), 'guard event written');

-- ٥) قيود الإضافة على الكمية المضافة في التزويد كمان.
select pg_temp.check(pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"inventory.added","client_event_id":"m4","payload":{"item_id":"a0000000-0000-0000-0000-000000000001","item_name":"لبن","quantity":5000,"category":"الألبان"}}') ->> 'reason' = 'qty_too_large', 'merge amount capped');
select pg_temp.check((select quantity from zad_inventory where id = 'a0000000-0000-0000-0000-000000000001') = 3, 'capped merge wrote nothing');

-- ٦) من غير item_id: صف جديد زي م٢.٢.
select pg_temp.check((pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"inventory.added","client_event_id":"m5","payload":{"item_name":"زيت","quantity":1,"category":"البقالة"}}') ->> 'ok')::boolean, 'plain add still inserts');
select pg_temp.check((select count(*) from zad_inventory where item_name = 'زيت') = 1, 'one oil row');

select 'commit_intent_merge: all checks passed';
