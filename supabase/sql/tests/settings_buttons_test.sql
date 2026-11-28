-- P1.6b (إعدادات الحساب). بعد سلسلة money_buttons + 20261129010000 + settings_buttons_scaffold + 20261128260000 (المراية) + 20261129020000.
-- بيثبت إن الإعدادات بتعدي من zad_commit_my_intent بصفة auth.uid() بس، وإن مراية zad_user_budget بتمشي مع كتابة الباب.
\set ON_ERROR_STOP on

create function pg_temp.check(ok boolean, msg text) returns void language plpgsql as $$
begin if ok is not true then raise exception 'FAILED: %', msg; end if; end $$;

insert into auth.users values ('77777777-7777-7777-7777-777777777777'), ('88888888-8888-8888-8888-888888888888');
insert into public.zad_users (id, name) values ('77777777-7777-7777-7777-777777777777', 'أنا'), ('88888888-8888-8888-8888-888888888888', 'غيري');
select set_config('request.jwt.claims', '{"role":"authenticated","sub":"77777777-7777-7777-7777-777777777777"}', false);

-- ١) الرصيد: limit_set بيكتب الرصيد والتأكيد وبداية العد، والمراية بتتبعه
select pg_temp.check((public.zad_commit_my_intent('money.limit_set', 'st:1', '{"amount":8000}', null, 'trace-set-0001') ->> 'ok')::boolean, 'limit set ok');
select pg_temp.check((select monthly_limit from public.zad_users where id = '77777777-7777-7777-7777-777777777777') = 8000, 'limit written');
select pg_temp.check((select limit_confirmed_at is not null and balance_anchored_at is not null from public.zad_users where id = '77777777-7777-7777-7777-777777777777'), 'confirmed and anchored');
select pg_temp.check((select monthly_limit = 8000 and balance_anchored_at is not null from public.zad_user_budget where user_id = '77777777-7777-7777-7777-777777777777'), 'mirror follows limit_set');
select pg_temp.check((select trace_id from public.zad_events where client_event_id = 'st:1') = 'trace-set-0001', 'trace id on the ledger');
select pg_temp.check((select source from public.zad_events where client_event_id = 'st:1') = 'manual', 'source manual');
select pg_temp.check(public.zad_commit_my_intent('money.limit_set', 'st:1b', '{"amount":0}') ->> 'reason' = 'amount_not_positive', 'zero limit refused');

-- ٢) يوم بداية الدورة، والمسح بـnull، والمراية
select pg_temp.check((public.zad_commit_my_intent('settings.cycle_start_set', 'st:2', '{"day":27}') ->> 'ok')::boolean, 'cycle day set');
select pg_temp.check((select cycle_start_day from public.zad_user_budget where user_id = '77777777-7777-7777-7777-777777777777') = 27, 'mirror follows cycle day');
select pg_temp.check((public.zad_commit_my_intent('settings.cycle_start_set', 'st:3', '{"day":null}') ->> 'ok')::boolean, 'cycle day cleared');
select pg_temp.check((select cycle_start_day is null from public.zad_users where id = '77777777-7777-7777-7777-777777777777'), 'day back to calendar month');
select pg_temp.check((select cycle_start_day is null from public.zad_user_budget where user_id = '77777777-7777-7777-7777-777777777777'), 'mirror follows the clear');
select pg_temp.check(public.zad_commit_my_intent('settings.cycle_start_set', 'st:4', '{"day":40}') ->> 'reason' = 'cycle_day_invalid', 'day 40 refused');
select pg_temp.check(public.zad_commit_my_intent('settings.cycle_start_set', 'st:5', '{}') ->> 'reason' = 'cycle_day_invalid', 'missing day refused, not a clear');

-- ٣) السوق
select pg_temp.check((public.zad_commit_my_intent('settings.market_set', 'st:6', '{"currency":"SAR","country":"SA"}') ->> 'ok')::boolean, 'market set');
select pg_temp.check((select country = 'SA' and currency = 'SAR' from public.zad_users where id = '77777777-7777-7777-7777-777777777777'), 'market written');
select pg_temp.check(public.zad_commit_my_intent('settings.market_set', 'st:7', '{"currency":"sar","country":"SA"}') ->> 'reason' = 'currency_invalid', 'lowercase currency refused');

-- ٤) فلاجات التطبيق
select pg_temp.check((public.zad_commit_my_intent('settings.app_flag_set', 'st:8', '{"setting":"pet_calls","on":false}') ->> 'ok')::boolean, 'pet calls off');
select pg_temp.check((select pet_calls_enabled = false from public.zad_users where id = '77777777-7777-7777-7777-777777777777'), 'pet calls written');
select pg_temp.check((public.zad_commit_my_intent('settings.app_flag_set', 'st:9', '{"setting":"food_pattern","on":true}') ->> 'ok')::boolean, 'food pattern on');
select pg_temp.check(public.zad_commit_my_intent('settings.app_flag_set', 'st:10', '{"setting":"other","on":true}') ->> 'reason' = 'setting_unknown', 'unknown flag refused');

-- ٥) التكرار من غير كتابة، والصف بتاع واحد تاني ماتلمسش
select pg_temp.check((public.zad_commit_my_intent('settings.app_flag_set', 'st:9', '{"setting":"food_pattern","on":true}') ->> 'duplicate')::boolean, 'same key is duplicate');
select pg_temp.check((select monthly_limit is null and country is null from public.zad_users where id = '88888888-8888-8888-8888-888888888888'), 'other user untouched');
select pg_temp.check((select count(*) from public.zad_user_budget where user_id = '88888888-8888-8888-8888-888888888888' and monthly_limit is not null) = 0, 'other mirror untouched');

-- ٦) أنواع النوم والصندوق مش جاية من الغلاف، ومن غير JWT
select pg_temp.check(public.zad_commit_my_intent('settings.sleep_set', 'st:11', '{"bed":"23:00","wake":"07:00"}') ->> 'reason' = 'unknown_kind', 'sleep not exposed');
select set_config('request.jwt.claims', '{}', false);
select pg_temp.check(public.zad_commit_my_intent('settings.market_set', 'st:12', '{}') ->> 'reason' = 'not_authenticated', 'no JWT refused');

select 'settings_buttons_test ok';
