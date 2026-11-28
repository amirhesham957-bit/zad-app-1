-- P1.6b (ديون/التزامات/اشتراكات). بعد سلسلة الباب (money + life_money + trace) و20261129010000_debts_obligations_subscriptions_door.sql.
-- بيثبت إن الأزرار بتعدي من zad_commit_my_intent بصفة auth.uid() بس، بمصدر manual وtrace_id، وإن تكرار الإضافة بنفس الـid مابيعملش صف تاني.
\set ON_ERROR_STOP on

create function pg_temp.check(ok boolean, msg text) returns void language plpgsql as $$
begin if ok is not true then raise exception 'FAILED: %', msg; end if; end $$;

insert into auth.users values ('55555555-5555-5555-5555-555555555555'), ('66666666-6666-6666-6666-666666666666');
insert into public.zad_users (id, name) values ('55555555-5555-5555-5555-555555555555', 'أنا'), ('66666666-6666-6666-6666-666666666666', 'غيري');
select set_config('request.jwt.claims', '{"role":"authenticated","sub":"55555555-5555-5555-5555-555555555555"}', false);

-- ١) ديون: إضافة بـtrace_id، دفع، مسح
select pg_temp.check((public.zad_commit_my_intent('debt.added', 'debt_add:1',
  '{"name":"قرض العربية","remaining_balance":5000,"minimum_payment":400,"interest_rate":12}', null, 'trace-debt-0001') ->> 'ok')::boolean, 'debt added');
select pg_temp.check((select count(*) from public.zad_debts where user_id = '55555555-5555-5555-5555-555555555555' and name = 'قرض العربية'
                        and principal_amount = 5000 and remaining_balance = 5000) = 1, 'debt row written for the JWT user');
select pg_temp.check((select source from public.zad_events where client_event_id = 'debt_add:1') = 'manual', 'debt event is manual');
select pg_temp.check((select trace_id from public.zad_events where client_event_id = 'debt_add:1') = 'trace-debt-0001', 'trace id written to the ledger');
select pg_temp.check((public.zad_commit_my_intent('debt.added', 'debt_add:1',
  '{"name":"قرض العربية","remaining_balance":5000}') ->> 'duplicate')::boolean, 'same key is duplicate');
select pg_temp.check((select count(*) from public.zad_debts where name = 'قرض العربية') = 1, 'no second debt row');

select pg_temp.check((public.zad_commit_my_intent('debt.updated', 'debt_pay:1',
  jsonb_build_object('item_id', (select id from public.zad_debts where name = 'قرض العربية'), 'patch', '{"remaining_balance":4000}'::jsonb)) ->> 'ok')::boolean, 'debt paid');
select pg_temp.check((select remaining_balance from public.zad_debts where name = 'قرض العربية') = 4000, 'balance edited');
select pg_temp.check((public.zad_commit_my_intent('debt.deleted', 'debt_delete:1',
  jsonb_build_object('item_id', (select id from public.zad_debts where name = 'قرض العربية'))) ->> 'ok')::boolean, 'debt deleted');
select pg_temp.check((select count(*) from public.zad_debts where name = 'قرض العربية') = 0, 'debt row gone');

-- ديون الجار ماتتلمسش
insert into public.zad_debts (id, user_id, name, principal_amount, remaining_balance)
values ('d0000000-0000-0000-0000-0000000000b1', '66666666-6666-6666-6666-666666666666', 'دين الجار', 900, 900);
select pg_temp.check(public.zad_commit_my_intent('debt.deleted', 'debt_delete:b1',
  '{"item_id":"d0000000-0000-0000-0000-0000000000b1"}') ->> 'reason' = 'item_not_found', 'other user debt refused');
select pg_temp.check((select remaining_balance from public.zad_debts where id = 'd0000000-0000-0000-0000-0000000000b1') = 900, 'other user debt untouched');

-- ٢) التزامات: إضافة بـid من العميل، تكرار بمفتاح تاني، تعديل، حذف
select pg_temp.check((public.zad_commit_my_intent('obligation.added', 'obligation:a1',
  '{"item_id":"c1000000-0000-0000-0000-0000000000a1","title":"إيجار الشقة","amount":3000,"kind":"rent","recurrence":"monthly","due_day":5,"confirmed":true}',
  null, 'trace-obl-0001') ->> 'ok')::boolean, 'obligation added');
select pg_temp.check((select user_id from public.zad_obligations where id = 'c1000000-0000-0000-0000-0000000000a1') = '55555555-5555-5555-5555-555555555555', 'row has the client id and the JWT user');
select pg_temp.check((select trace_id from public.zad_events where client_event_id = 'obligation:a1') = 'trace-obl-0001', 'obligation trace id in the ledger');
select pg_temp.check((public.zad_commit_my_intent('obligation.added', 'obligation:a1-retry',
  '{"item_id":"c1000000-0000-0000-0000-0000000000a1","title":"إيجار الشقة","amount":3000,"kind":"rent"}') ->> 'ok')::boolean, 'same id new key ok');
select pg_temp.check((select count(*) from public.zad_obligations where title = 'إيجار الشقة') = 1, 'no second obligation row');

select pg_temp.check((public.zad_commit_my_intent('obligation.updated', 'obligation_edit:a1:1',
  '{"item_id":"c1000000-0000-0000-0000-0000000000a1","patch":{"title":"إيجار جديد","amount":3500,"kind":"rent","recurrence":"quarterly","due_day":null,"due_date":"2026-12-20","confirmed":true,"active":true}}') ->> 'ok')::boolean, 'obligation edited');
select pg_temp.check((select amount = 3500 and title = 'إيجار جديد' and recurrence = 'quarterly' and due_day is null and due_date = date '2026-12-20'
                        from public.zad_obligations where id = 'c1000000-0000-0000-0000-0000000000a1'), 'obligation fields edited, due_day cleared');
select pg_temp.check(public.zad_commit_my_intent('obligation.updated', 'obligation_edit:a1:2',
  '{"item_id":"c1000000-0000-0000-0000-0000000000a1","patch":{"kind":"gift"}}') ->> 'reason' = 'obligation_kind_invalid', 'bad kind refused');
select pg_temp.check((public.zad_commit_my_intent('obligation.updated', 'obligation_edit:a1:3',
  '{"item_id":"c1000000-0000-0000-0000-0000000000a1","patch":{"active":false}}') ->> 'ok')::boolean, 'obligation stopped');
select pg_temp.check((select active from public.zad_obligations where id = 'c1000000-0000-0000-0000-0000000000a1') = false, 'active flag written');

insert into public.zad_obligations (id, user_id, title, amount, kind)
values ('c1000000-0000-0000-0000-0000000000b1', '66666666-6666-6666-6666-666666666666', 'إيجار الجار', 700, 'rent');
select pg_temp.check(public.zad_commit_my_intent('obligation.added', 'obligation:b1',
  '{"item_id":"c1000000-0000-0000-0000-0000000000b1","title":"x1","amount":5,"kind":"rent"}') ->> 'reason' = 'item_not_found', 'other user id refused on add');
select pg_temp.check(public.zad_commit_my_intent('obligation.deleted', 'obligation_delete:b1',
  '{"item_id":"c1000000-0000-0000-0000-0000000000b1"}') ->> 'reason' = 'item_not_found', 'other user obligation not deleted');
select pg_temp.check((public.zad_commit_my_intent('obligation.deleted', 'obligation_delete:a1',
  '{"item_id":"c1000000-0000-0000-0000-0000000000a1"}') ->> 'ok')::boolean, 'obligation deleted');
select pg_temp.check((select count(*) from public.zad_obligations where id = 'c1000000-0000-0000-0000-0000000000a1') = 0, 'obligation row gone');
select pg_temp.check((select count(*) from public.zad_obligations where id = 'c1000000-0000-0000-0000-0000000000b1') = 1, 'other user obligation untouched');

-- ٣) اشتراكات: إضافة بكل الحقول، تكرار، تعديل (دورة أسبوعية)، حذف
select pg_temp.check((public.zad_commit_my_intent('subscription.added', 'subscription:a1',
  '{"item_id":"e1000000-0000-0000-0000-0000000000a1","title":"نتفلكس","amount":150,"renewal_date":"2026-12-01","billing_cycle":"MONTHLY","category":"ترفيه","type":"subscription","provider":"netflix","auto_deduct":true,"due_day":1}',
  null, 'trace-sub-0001') ->> 'ok')::boolean, 'subscription added');
select pg_temp.check((select user_id = '55555555-5555-5555-5555-555555555555' and auto_deduct and provider = 'netflix' and type = 'subscription' and due_day = 1
                        from public.zad_subscriptions where id = 'e1000000-0000-0000-0000-0000000000a1'), 'subscription row has every field');
select pg_temp.check((select trace_id from public.zad_events where client_event_id = 'subscription:a1') = 'trace-sub-0001', 'subscription trace id in the ledger');
select pg_temp.check((public.zad_commit_my_intent('subscription.added', 'subscription:a1-retry',
  '{"item_id":"e1000000-0000-0000-0000-0000000000a1","title":"نتفلكس","amount":150}') ->> 'ok')::boolean, 'same id new key ok');
select pg_temp.check((select count(*) from public.zad_subscriptions where title = 'نتفلكس') = 1, 'no second subscription row');

select pg_temp.check((public.zad_commit_my_intent('subscription.updated', 'subscription_edit:a1:1',
  '{"item_id":"e1000000-0000-0000-0000-0000000000a1","patch":{"amount":175,"billing_cycle":"WEEKLY","type":"utility","provider":null,"auto_deduct":false,"category":null,"renewal_date":"2026-12-08","is_active":false}}') ->> 'ok')::boolean, 'subscription edited');
select pg_temp.check((select amount = 175 and billing_cycle = 'WEEKLY' and type = 'utility' and provider is null and not auto_deduct
                             and category is null and renewal_date = '2026-12-08' and not is_active
                        from public.zad_subscriptions where id = 'e1000000-0000-0000-0000-0000000000a1'), 'subscription fields edited');
select pg_temp.check(public.zad_commit_my_intent('subscription.updated', 'subscription_edit:a1:2',
  '{"item_id":"e1000000-0000-0000-0000-0000000000a1","patch":{"owner":"x"}}') ->> 'reason' = 'patch_field_unknown', 'unknown field refused');

insert into public.zad_subscriptions (id, user_id, title, amount) values ('e1000000-0000-0000-0000-0000000000b1', '66666666-6666-6666-6666-666666666666', 'اشتراك الجار', 10);
select pg_temp.check(public.zad_commit_my_intent('subscription.deleted', 'subscription_delete:b1',
  '{"item_id":"e1000000-0000-0000-0000-0000000000b1"}') ->> 'reason' = 'item_not_found', 'other user subscription not deleted');
select pg_temp.check((public.zad_commit_my_intent('subscription.deleted', 'subscription_delete:a1',
  '{"item_id":"e1000000-0000-0000-0000-0000000000a1"}') ->> 'ok')::boolean, 'subscription deleted');
select pg_temp.check((select count(*) from public.zad_subscriptions where id = 'e1000000-0000-0000-0000-0000000000a1') = 0, 'subscription row gone');

-- ٤) الأنواع القديمة لسه شغالة من الغلاف، والفلوس ماتأثرتش
select pg_temp.check((public.zad_commit_my_intent('money.category_budget_set', 'cb:1', '{"category":"مطاعم","amount":500}') ->> 'ok')::boolean, 'money kinds still pass the wrapper');
select pg_temp.check(public.zad_commit_my_intent('obligation.deactivated', 'od:1', '{}') ->> 'reason' = 'unknown_kind', 'deactivate stays off the wrapper');

-- ٥) من غير JWT
select set_config('request.jwt.claims', '{}', false);
select pg_temp.check(public.zad_commit_my_intent('debt.added', 'n:1', '{}') ->> 'reason' = 'not_authenticated', 'no JWT refused');

select 'debts_buttons_test ok';
