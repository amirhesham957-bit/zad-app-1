-- ZAD_OR_PLAN م٢.٥: الباب متقسم لمجالات — حذف الصنف وعلامة «أساسي / على فترات» من الباب، ودوال المجال مقفولة.
\set ON_ERROR_STOP on
create or replace function pg_temp.check(cond boolean, what text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAILED: %', what; end if; end $$;
create or replace function pg_temp.ci(j text) returns jsonb language sql as $$ select zad_commit_intent(j::jsonb) $$;

insert into family_members values ('f0000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111'),
                                  ('f0000000-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222');
insert into zad_inventory (id, user_id, item_name, quantity, unit, family_id) values
  ('a0000000-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 'لبن', 3, 'علبة', 'f0000000-0000-0000-0000-000000000001'),
  ('a0000000-0000-0000-0000-000000000002', '33333333-3333-3333-3333-333333333333', 'رز', 5, 'كيلو', null),
  ('a0000000-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111', 'كمون', 1, 'علبة', null);

-- ١) العلامة على صنف العيلة: الصف اتعدل، والحدث فيه القديم والجديد.
select pg_temp.check((pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"inventory.restock_mode_set","client_event_id":"d1","payload":{"item_id":"a0000000-0000-0000-0000-000000000001","restock_mode":"occasional"}}') ->> 'ok')::boolean, 'mode set');
select pg_temp.check((select restock_mode from zad_inventory where id = 'a0000000-0000-0000-0000-000000000001') = 'occasional', 'row has the mode');
select pg_temp.check((select payload ->> 'before' is null and payload ->> 'after' = 'occasional' from zad_events where client_event_id = 'd1'), 'event before/after');
select pg_temp.check(pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"inventory.restock_mode_set","client_event_id":"d2","payload":{"item_id":"a0000000-0000-0000-0000-000000000001","restock_mode":"forever"}}') ->> 'reason' = 'restock_mode_unknown', 'mode list');
select pg_temp.check(exists (select 1 from zad_guard_events where reason = 'restock_mode_unknown'), 'mode refusal logged');

-- ٢) الحذف: الصف اتمسح، والحدث شايل الصف كامل.
select pg_temp.check((pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"inventory.deleted","client_event_id":"d3","payload":{"item_id":"a0000000-0000-0000-0000-000000000003"}}') ->> 'ok')::boolean, 'delete ok');
select pg_temp.check(not exists (select 1 from zad_inventory where id = 'a0000000-0000-0000-0000-000000000003'), 'row gone');
select pg_temp.check((select payload -> 'before' ->> 'item_name' = 'كمون' from zad_events where client_event_id = 'd3'), 'event keeps the whole row');
-- نفس الطلب تاني: duplicate، مش «مش موجود».
select pg_temp.check((pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"inventory.deleted","client_event_id":"d3","payload":{"item_id":"a0000000-0000-0000-0000-000000000003"}}') ->> 'duplicate')::boolean, 'repeat delete is a duplicate');

-- ٣) بيت تاني: لا حذف ولا علامة.
select pg_temp.check(pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"inventory.deleted","client_event_id":"d4","payload":{"item_id":"a0000000-0000-0000-0000-000000000002"}}') ->> 'reason' = 'item_not_found', 'other household delete refused');
select pg_temp.check(exists (select 1 from zad_inventory where id = 'a0000000-0000-0000-0000-000000000002'), 'other household row still there');
select pg_temp.check(pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"inventory.deleted","client_event_id":"d5","payload":{"item_id":"not-a-uuid"}}') ->> 'reason' = 'item_not_found', 'bad id is not found, no crash');

-- ٤) نوع مش معروف جوه مجال معروف: مرفوض ومتسجل، ومفيش حدث.
select pg_temp.check(pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"inventory.teleported","client_event_id":"d6","payload":{}}') ->> 'reason' = 'unknown_kind', 'unknown inventory kind');
select pg_temp.check(not exists (select 1 from zad_events where client_event_id = 'd6'), 'no event for it');

-- ٥) دوال المجال: السيرفر نفسه مايقدرش يناديها (كتابة من غير حدث).
set role service_role;
do $$ begin
  perform zad_intent_inventory('11111111-1111-1111-1111-111111111111', 'inventory.deleted', '{}'::jsonb, now());
  raise exception 'FAILED: service_role can call zad_intent_inventory';
exception when insufficient_privilege then null;
end $$;
do $$ begin
  perform zad_intent_household_item('11111111-1111-1111-1111-111111111111', 'a0000000-0000-0000-0000-000000000001');
  raise exception 'FAILED: service_role can call zad_intent_household_item';
exception when insufficient_privilege then null;
end $$;
select pg_temp.check((zad_commit_intent('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"inventory.restock_mode_set","client_event_id":"d7","payload":{"item_id":"a0000000-0000-0000-0000-000000000001","restock_mode":"staple"}}') ->> 'ok')::boolean, 'service_role still goes through the door');
reset role;

select 'commit_intent_domains: all checks passed';
