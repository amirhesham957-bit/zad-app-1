-- P1.6b (تيليجرام والإشعارات). بعد سلسلة settings_buttons + telegram_notifications_scaffold + 20261129060000.
-- بيثبت إن مفاتيح قراءة الإشعارات وفك الربط بيعدوا من zad_commit_my_intent بصفة auth.uid() بس.
\set ON_ERROR_STOP on

create function pg_temp.check(ok boolean, msg text) returns void language plpgsql as $$
begin if ok is not true then raise exception 'FAILED: %', msg; end if; end $$;

insert into auth.users values ('99999999-9999-9999-9999-999999999991'), ('99999999-9999-9999-9999-999999999992');
insert into public.zad_users (id, name) values ('99999999-9999-9999-9999-999999999991', 'أنا'), ('99999999-9999-9999-9999-999999999992', 'غيري');
select set_config('request.jwt.claims', '{"role":"authenticated","sub":"99999999-9999-9999-9999-999999999991"}', false);

-- ١) المفتاح: تشغيل ثم إطفاء، الصف واحد، enabled_at بيتمسح عند الإطفاء
select pg_temp.check((public.zad_commit_my_intent('settings.notification_switch_set', 'tn:1', '{"kind":"trip","enabled":true}', null, 'trace-tn-00001') ->> 'ok')::boolean, 'switch on');
select pg_temp.check((select enabled and enabled_at is not null from public.zad_notification_switches where user_id = '99999999-9999-9999-9999-999999999991' and kind = 'trip'), 'switch written');
select pg_temp.check((select trace_id from public.zad_events where client_event_id = 'tn:1') = 'trace-tn-00001', 'trace id on the ledger');
select pg_temp.check((public.zad_commit_my_intent('settings.notification_switch_set', 'tn:2', '{"kind":"trip","enabled":false}') ->> 'ok')::boolean, 'switch off');
select pg_temp.check((select count(*) = 1 and bool_and(not enabled and enabled_at is null) from public.zad_notification_switches where user_id = '99999999-9999-9999-9999-999999999991'), 'one row, off, no stamp');
select pg_temp.check(public.zad_commit_my_intent('settings.notification_switch_set', 'tn:3', '{"kind":"other","enabled":true}') ->> 'reason' = 'notification_kind_invalid', 'unknown kind refused');
select pg_temp.check(public.zad_commit_my_intent('settings.notification_switch_set', 'tn:4', '{"kind":"trip","enabled":"yes"}') ->> 'reason' = 'bad_payload', 'non-boolean refused');
select pg_temp.check((public.zad_commit_my_intent('settings.notification_switch_set', 'tn:2', '{"kind":"trip","enabled":false}') ->> 'duplicate')::boolean, 'same key is duplicate');

-- ٢) فك الربط: بتاعي بس
insert into public.telegram_bindings (user_id, chat_id, binding_code, code_expires_at, bound_at) values
  ('99999999-9999-9999-9999-999999999991', 5551, 'AAAAAAAA', now() + interval '10 minutes', now()),
  ('99999999-9999-9999-9999-999999999992', 5552, 'BBBBBBBB', now() + interval '10 minutes', now());
select pg_temp.check((public.zad_commit_my_intent('settings.telegram_unlinked', 'tn:5', '{}') ->> 'ok')::boolean, 'unlink ok');
select pg_temp.check((select count(*) from public.telegram_bindings where user_id = '99999999-9999-9999-9999-999999999991') = 0, 'mine gone');
select pg_temp.check((select count(*) from public.telegram_bindings where user_id = '99999999-9999-9999-9999-999999999992') = 1, 'other binding untouched');
select pg_temp.check((select payload::text not like '%AAAAAAAA%' and payload::text not like '%5551%' from public.zad_events where client_event_id = 'tn:5'), 'no code or chat id in the ledger');

-- ٣) مفتاح حد تاني ماتلمسش، ومن غير JWT
select pg_temp.check((select count(*) from public.zad_notification_switches where user_id = '99999999-9999-9999-9999-999999999992') = 0, 'other switches untouched');
select set_config('request.jwt.claims', '{}', false);
select pg_temp.check(public.zad_commit_my_intent('settings.telegram_unlinked', 'tn:6', '{}') ->> 'reason' = 'not_authenticated', 'no JWT refused');

select 'telegram_notifications_test ok';
