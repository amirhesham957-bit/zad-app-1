-- ZAD_OR_PLAN م٢.٤. بعد commit_intent_scaffold.sql والباب (آخر نسخة: every_domain) و20261122210000_commit_my_intent.sql.
-- بيثبت إن الموبايل بينده الغلاف بصفة auth.uid() بس، ومفيش طريقة يكتب بيها لمستخدم تاني.
\set ON_ERROR_STOP on

create function pg_temp.check(ok boolean, msg text) returns void language plpgsql as $$
begin if ok is not true then raise exception 'FAILED: %', msg; end if; end $$;

insert into auth.users values ('44444444-4444-4444-4444-444444444444');
insert into public.zad_users values ('44444444-4444-4444-4444-444444444444', 'أنا');
insert into public.zad_inventory (id, user_id, item_name, category, quantity, unit) values
  ('b0000000-0000-0000-0000-000000000001', '44444444-4444-4444-4444-444444444444', 'رز', 'البقالة', 5, 'كيلو'),
  ('b0000000-0000-0000-0000-000000000002', '33333333-3333-3333-3333-333333333333', 'سكر الجار', 'البقالة', 5, 'كيلو');

-- ١) من غير JWT أو بـJWT من غير sub: مرفوض. وبصفة authenticated من غير sub برضو.
select pg_temp.check(public.zad_commit_my_intent('inventory.added', 'w0', '{"item_name":"زيت","quantity":1,"category":"البقالة"}') ->> 'reason' = 'not_authenticated', 'no JWT refused');
select set_config('request.jwt.claims', '{"role":"authenticated"}', false);
select pg_temp.check(public.zad_commit_my_intent('inventory.added', 'w0', '{"item_name":"زيت","quantity":1,"category":"البقالة"}') ->> 'reason' = 'not_authenticated', 'JWT without sub refused');

-- ٢) الأنواع التلاتة بتشتغل على صاحب الـJWT، والمصدر manual دايماً.
select set_config('request.jwt.claims', '{"role":"authenticated","sub":"44444444-4444-4444-4444-444444444444"}', false);
select pg_temp.check((public.zad_commit_my_intent('inventory.added', 'w1', '{"item_name":"زيت","quantity":2,"category":"البقالة"}') ->> 'ok')::boolean, 'added');
select pg_temp.check((select user_id from public.zad_inventory where item_name = 'زيت') = '44444444-4444-4444-4444-444444444444', 'added row belongs to the JWT user');
select pg_temp.check((public.zad_commit_my_intent('inventory.consumed', 'w2', '{"item_id":"b0000000-0000-0000-0000-000000000001","amount":1}') ->> 'ok')::boolean, 'consumed');
select pg_temp.check((select quantity from public.zad_inventory where id = 'b0000000-0000-0000-0000-000000000001') = 4, 'consumed took 1');
select pg_temp.check((public.zad_commit_my_intent('inventory.quantity_set', 'w3', '{"item_id":"b0000000-0000-0000-0000-000000000001","quantity":3}') ->> 'ok')::boolean, 'quantity_set');
select pg_temp.check((select quantity from public.zad_inventory where id = 'b0000000-0000-0000-0000-000000000001') = 3, 'quantity set to 3');
select pg_temp.check((select count(*) from public.zad_events where client_event_id in ('w1', 'w2', 'w3') and source = 'manual' and user_id = '44444444-4444-4444-4444-444444444444') = 3, 'three manual events for the JWT user');

-- ٣) العزل: user_id في الـpayload أو النية مالوش أثر، وصنف مستخدم تاني مارفوض ومش اتلمس.
select pg_temp.check(public.zad_commit_my_intent('inventory.consumed', 'w4', '{"item_id":"b0000000-0000-0000-0000-000000000002","amount":1,"user_id":"33333333-3333-3333-3333-333333333333"}') ->> 'reason' = 'item_not_found', 'other user item refused');
select pg_temp.check((select quantity from public.zad_inventory where id = 'b0000000-0000-0000-0000-000000000002') = 5, 'other user item untouched');
select pg_temp.check(public.zad_commit_my_intent('inventory.quantity_set', 'w5', '{"item_id":"b0000000-0000-0000-0000-000000000002","quantity":0}') ->> 'reason' = 'item_not_found', 'other user quantity_set refused');
select pg_temp.check((select count(*) from public.zad_events where user_id = '33333333-3333-3333-3333-333333333333') = 0, 'no event written for the other user');
select pg_temp.check((select count(*) from public.zad_guard_events where user_id = '44444444-4444-4444-4444-444444444444' and reason = 'item_not_found') = 2, 'the refusals are logged against the caller');

-- ٤) التكرار: نفس المفتاح = نفس النتيجة من غير تطبيق تاني.
select pg_temp.check((public.zad_commit_my_intent('inventory.consumed', 'w2', '{"item_id":"b0000000-0000-0000-0000-000000000001","amount":1}') ->> 'duplicate')::boolean, 'replay is duplicate');
select pg_temp.check((select quantity from public.zad_inventory where id = 'b0000000-0000-0000-0000-000000000001') = 3, 'replay did not consume again');

-- ٥) الأنواع التانية مرفوضة (مش من المخزن التلاتة).
select pg_temp.check(public.zad_commit_my_intent('inventory.deleted', 'w6', '{"item_id":"b0000000-0000-0000-0000-000000000001"}') ->> 'reason' = 'unknown_kind', 'deleted not exposed yet');
select pg_temp.check(public.zad_commit_my_intent('money.spent', 'w7', '{}') ->> 'reason' = 'unknown_kind', 'other domain not exposed');
select pg_temp.check((select count(*) from public.zad_inventory where id = 'b0000000-0000-0000-0000-000000000001') = 1, 'item still there');

-- ٦) وقت في المستقبل البعيد مرفوض، وفي الماضي (أوفلاين) مقبول.
select pg_temp.check(public.zad_commit_my_intent('inventory.consumed', 'w8', '{"item_id":"b0000000-0000-0000-0000-000000000001","amount":1}', now() + interval '1 day') ->> 'reason' = 'bad_shape', 'future occurred_at refused');
select pg_temp.check((public.zad_commit_my_intent('inventory.consumed', 'w9', '{"item_id":"b0000000-0000-0000-0000-000000000001","amount":1}', now() - interval '2 days') ->> 'ok')::boolean, 'offline past occurred_at accepted');
select set_config('request.jwt.claims', '{}', false);

-- ٧) الصلاحيات: authenticated بينده الغلاف ومش الباب، وanon مايندهوش خالص.
set role authenticated;
select set_config('request.jwt.claims', '{"role":"authenticated","sub":"44444444-4444-4444-4444-444444444444"}', false);
select pg_temp.check((public.zad_commit_my_intent('inventory.quantity_set', 'w10', '{"item_id":"b0000000-0000-0000-0000-000000000001","quantity":6}') ->> 'ok')::boolean, 'authenticated role can call the wrapper');
do $$ begin
  perform public.zad_commit_intent('{}'::jsonb);
  raise exception 'FAILED: authenticated can call zad_commit_intent';
exception when insufficient_privilege then null;
end $$;
reset role;
set role anon;
do $$ begin
  perform public.zad_commit_my_intent('inventory.added', 'w11', '{}');
  raise exception 'FAILED: anon can call the wrapper';
exception when insufficient_privilege then null;
end $$;
reset role;

select 'commit_my_intent_test ok';
