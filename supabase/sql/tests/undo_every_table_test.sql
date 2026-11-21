-- ZAD_OR_PLAN م١.٦: التراجع يرجّع حذف الاشتراك والذاكرة، ويرجّع «حذف» الالتزام الناعم (active=false)،
-- ويقفل صف السلة، ومايرجعش صف حد تاني.
\set ON_ERROR_STOP on
create or replace function pg_temp.check(cond boolean, what text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAILED: %', what; end if; end $$;

select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111"}', false);

-- ١) اشتراك اتمسح بأداة العقل: التراجع بيرجّعه بنفس الـid ويقفل صف السلة.
insert into zad_trash (table_name, row_id, user_id, row_data) values
  ('zad_subscriptions', 'aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
   '{"id":"aaaaaaaa-0000-0000-0000-000000000001","user_id":"11111111-1111-1111-1111-111111111111","name":"نتفلكس","amount":200}');
insert into agent_actions (id, user_id, tool_name, target_table, target_id, previous_state, new_state) values
  ('bbbbbbbb-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'delete_subscription', 'zad_subscriptions',
   'aaaaaaaa-0000-0000-0000-000000000001',
   '{"id":"aaaaaaaa-0000-0000-0000-000000000001","user_id":"11111111-1111-1111-1111-111111111111","name":"نتفلكس","amount":200}', null);
select pg_temp.check((zad_agent_undo('bbbbbbbb-0000-0000-0000-000000000001') ->> 'ok')::boolean, 'subscription delete undone');
select pg_temp.check(exists (select 1 from zad_subscriptions where id = 'aaaaaaaa-0000-0000-0000-000000000001' and name = 'نتفلكس'), 'subscription row is back');
select pg_temp.check((select restored_at is not null from zad_trash where row_id = 'aaaaaaaa-0000-0000-0000-000000000001'), 'trash row closed');
select pg_temp.check((select status from agent_actions where id = 'bbbbbbbb-0000-0000-0000-000000000001') = 'undone', 'action marked undone');
select pg_temp.check(zad_agent_undo('bbbbbbbb-0000-0000-0000-000000000001') ->> 'error' = 'already_undone', 'no second undo');

-- ٢) الالتزام «اتمسح» بـactive=false والصف لسه موجود: التراجع بيرجّع active=true بدل insert يقع.
insert into zad_obligations values ('aaaaaaaa-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'إيجار', false);
insert into agent_actions (id, user_id, tool_name, target_table, target_id, previous_state, new_state) values
  ('bbbbbbbb-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'delete_obligation', 'zad_obligations',
   'aaaaaaaa-0000-0000-0000-000000000002',
   '{"id":"aaaaaaaa-0000-0000-0000-000000000002","user_id":"11111111-1111-1111-1111-111111111111","title":"إيجار","active":true}', null);
select pg_temp.check((zad_agent_undo('bbbbbbbb-0000-0000-0000-000000000002') ->> 'ok')::boolean, 'soft obligation delete undone');
select pg_temp.check((select active from zad_obligations where id = 'aaaaaaaa-0000-0000-0000-000000000002'), 'obligation active again');

-- ٣) الصف اترجع قبل كده من السلة: row_exists مش وقوع... والصف ده اتغير بعد كده فمايتدهسش.
insert into zad_memory values ('aaaaaaaa-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111', null, 'بيحب القهوة');
insert into agent_actions (id, user_id, tool_name, target_table, target_id, previous_state, new_state) values
  ('bbbbbbbb-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111', 'delete_memory', 'zad_memory',
   'aaaaaaaa-0000-0000-0000-000000000003',
   '{"id":"aaaaaaaa-0000-0000-0000-000000000003","user_id":"11111111-1111-1111-1111-111111111111","content":"بيحب القهوة"}', null);
select pg_temp.check((zad_agent_undo('bbbbbbbb-0000-0000-0000-000000000003') ->> 'ok')::boolean, 'memory present: columns restored, no crash');

-- ٤) فعل حد تاني: مايتلمسش (الفعل مش بتاعه = no_action_to_undo).
insert into zad_debts values ('aaaaaaaa-0000-0000-0000-000000000004', '22222222-2222-2222-2222-222222222222');
insert into agent_actions (id, user_id, tool_name, target_table, target_id, previous_state, new_state) values
  ('bbbbbbbb-0000-0000-0000-000000000004', '22222222-2222-2222-2222-222222222222', 'add_debt', 'zad_debts',
   'aaaaaaaa-0000-0000-0000-000000000004', null, '{}');
select pg_temp.check(zad_agent_undo('bbbbbbbb-0000-0000-0000-000000000004') ->> 'error' = 'no_action_to_undo', 'other user action refused');
select pg_temp.check(exists (select 1 from zad_debts where id = 'aaaaaaaa-0000-0000-0000-000000000004'), 'other user row untouched');

-- ٥) صف اتكتب في previous_state بـuser_id حد تاني (فعل مزوّر): ownership_mismatch.
insert into agent_actions (id, user_id, tool_name, target_table, target_id, previous_state, new_state) values
  ('bbbbbbbb-0000-0000-0000-000000000005', '11111111-1111-1111-1111-111111111111', 'delete_appointment', 'zad_appointments',
   'aaaaaaaa-0000-0000-0000-000000000005',
   '{"id":"aaaaaaaa-0000-0000-0000-000000000005","user_id":"22222222-2222-2222-2222-222222222222"}', null);
select pg_temp.check(zad_agent_undo('bbbbbbbb-0000-0000-0000-000000000005') ->> 'error' = 'ownership_mismatch', 'foreign row not inserted');
select pg_temp.check(not exists (select 1 from zad_appointments), 'no appointment written');

-- ٦) إضافة موعد (٥٠٧ فعل على الحي): التراجع بيمسحه.
insert into zad_appointments values ('aaaaaaaa-0000-0000-0000-000000000006', '11111111-1111-1111-1111-111111111111');
insert into agent_actions (id, user_id, tool_name, target_table, target_id, previous_state, new_state) values
  ('bbbbbbbb-0000-0000-0000-000000000006', '11111111-1111-1111-1111-111111111111', 'add_appointment', 'zad_appointments',
   'aaaaaaaa-0000-0000-0000-000000000006', null, '{}');
select pg_temp.check((zad_agent_undo('bbbbbbbb-0000-0000-0000-000000000006') ->> 'ok')::boolean, 'appointment add undone');
select pg_temp.check(not exists (select 1 from zad_appointments where id = 'aaaaaaaa-0000-0000-0000-000000000006'), 'appointment gone');

select 'undo_every_table: all checks passed';
