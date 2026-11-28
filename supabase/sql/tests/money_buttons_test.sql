-- P1.6b (فلوس). بعد سلسلة الباب (money + trace) و20261128210000_money_buttons_door.sql.
-- بيثبت إن أزرار الفلوس بتعدي من zad_commit_my_intent بصفة auth.uid() بس، بمصدر manual وtrace_id.
\set ON_ERROR_STOP on

create function pg_temp.check(ok boolean, msg text) returns void language plpgsql as $$
begin if ok is not true then raise exception 'FAILED: %', msg; end if; end $$;

insert into auth.users values ('55555555-5555-5555-5555-555555555555'), ('66666666-6666-6666-6666-666666666666');
insert into public.zad_users (id, name) values ('55555555-5555-5555-5555-555555555555', 'أنا'), ('66666666-6666-6666-6666-666666666666', 'غيري');
select set_config('request.jwt.claims', '{"role":"authenticated","sub":"55555555-5555-5555-5555-555555555555"}', false);

-- ١) money.logged بـid من العميل + trace_id
select pg_temp.check((public.zad_commit_my_intent('money.logged', 'txn:a1',
  '{"item_id":"c0000000-0000-0000-0000-0000000000a1","amount":50,"title":"قهوة","category":"مطاعم","txn_kind":"expense","wallet":"cash","currency":"EGP"}',
  null, 'trace-money-0001') ->> 'ok')::boolean, 'logged ok');
select pg_temp.check((select user_id from public.zad_transactions where id = 'c0000000-0000-0000-0000-0000000000a1') = '55555555-5555-5555-5555-555555555555', 'row has the client id and the JWT user');
select pg_temp.check((select source from public.zad_events where client_event_id = 'txn:a1') = 'manual', 'event is manual');
select pg_temp.check((select trace_id from public.zad_events where client_event_id = 'txn:a1') = 'trace-money-0001', 'trace id written to the ledger');

-- ٢) التكرار بنفس المفتاح، وبمفتاح تاني لنفس الـid = من غير صف تاني
select pg_temp.check((public.zad_commit_my_intent('money.logged', 'txn:a1',
  '{"item_id":"c0000000-0000-0000-0000-0000000000a1","amount":50,"title":"قهوة","txn_kind":"expense"}') ->> 'duplicate')::boolean, 'same key is duplicate');
select pg_temp.check((public.zad_commit_my_intent('money.logged', 'txn:a1-retry',
  '{"item_id":"c0000000-0000-0000-0000-0000000000a1","amount":50,"title":"قهوة","txn_kind":"expense"}') ->> 'ok')::boolean, 'same id new key ok');
select pg_temp.check((select count(*) from public.zad_transactions where title = 'قهوة') = 1, 'no second row');

-- ٣) id صف مستخدم تاني أو مش UUID = item_not_found وماتلمسش
insert into public.zad_transactions (id, user_id, amount, title) values ('c0000000-0000-0000-0000-0000000000b1', '66666666-6666-6666-6666-666666666666', 9, 'بتاع الجار');
select pg_temp.check(public.zad_commit_my_intent('money.logged', 'txn:b1',
  '{"item_id":"c0000000-0000-0000-0000-0000000000b1","amount":50,"title":"x","txn_kind":"expense"}') ->> 'reason' = 'item_not_found', 'other user id refused');
select pg_temp.check(public.zad_commit_my_intent('money.logged', 'txn:b2',
  '{"item_id":"nope","amount":50,"title":"x","txn_kind":"expense"}') ->> 'reason' = 'item_not_found', 'bad uuid refused');
select pg_temp.check(public.zad_commit_my_intent('money.updated', 'txn:b3',
  '{"item_id":"c0000000-0000-0000-0000-0000000000b1","patch":{"amount":1}}') ->> 'reason' = 'item_not_found', 'other user update refused');
select pg_temp.check((select amount from public.zad_transactions where id = 'c0000000-0000-0000-0000-0000000000b1') = 9, 'other user row untouched');

-- ٤) تعديل ومسح
select pg_temp.check((public.zad_commit_my_intent('money.updated', 'txn_edit:a1:1',
  '{"item_id":"c0000000-0000-0000-0000-0000000000a1","patch":{"amount":75,"title":"قهوة ٢"}}') ->> 'ok')::boolean, 'updated');
select pg_temp.check((select amount from public.zad_transactions where id = 'c0000000-0000-0000-0000-0000000000a1') = 75, 'amount edited');
select pg_temp.check((public.zad_commit_my_intent('money.deleted', 'txn_delete:a1',
  '{"item_id":"c0000000-0000-0000-0000-0000000000a1"}') ->> 'ok')::boolean, 'deleted');
select pg_temp.check((select count(*) from public.zad_transactions where id = 'c0000000-0000-0000-0000-0000000000a1') = 0, 'row gone');

-- ٥) سقف فئة وصندوق طوارئ
select pg_temp.check((public.zad_commit_my_intent('money.category_budget_set', 'cb:1', '{"category":"مطاعم","amount":500}') ->> 'ok')::boolean, 'category budget set');
select pg_temp.check((select amount from public.zad_category_budgets where user_id = '55555555-5555-5555-5555-555555555555' and category = 'مطاعم') = 500, 'ceiling written');
select pg_temp.check((public.zad_commit_my_intent('money.category_budget_set', 'cb:2', '{"category":"مطاعم","amount":0}') ->> 'ok')::boolean, 'category budget cleared');
select pg_temp.check((select count(*) from public.zad_category_budgets where category = 'مطاعم') = 0, 'ceiling removed');
select pg_temp.check((public.zad_commit_my_intent('settings.emergency_fund_set', 'ef:1', '{"balance":1200}') ->> 'ok')::boolean, 'emergency fund set');
select pg_temp.check((select emergency_fund_balance from public.zad_users where id = '55555555-5555-5555-5555-555555555555') = 1200, 'fund written');

-- ٦) نوع برا القايمة، ومن غير JWT
select pg_temp.check(public.zad_commit_my_intent('money.purchase', 'p:1', '{}') ->> 'reason' = 'unknown_kind', 'purchase not exposed');
select set_config('request.jwt.claims', '{}', false);
select pg_temp.check(public.zad_commit_my_intent('money.logged', 'n:1', '{}') ->> 'reason' = 'not_authenticated', 'no JWT refused');

select 'money_buttons_test ok';
