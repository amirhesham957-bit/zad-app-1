-- ZAD_OR_PLAN م٢.٥: الاشتراكات والديون والالتزامات من الباب — كل نوع: نجاح، كل كود رفض، صف حد تاني ماتلمسش،
-- والقديم محفوظ في الحدث، وكل رفض متسجل في zad_guard_events.
\set ON_ERROR_STOP on
create or replace function pg_temp.check(cond boolean, what text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAILED: %', what; end if; end $$;
create or replace function pg_temp.ci(j text) returns jsonb language sql as $$ select zad_commit_intent(j::jsonb) $$;
-- نية جاهزة للعميل ١: pg_temp.me(kind, event_id, payload)
create or replace function pg_temp.me(k text, e text, p text) returns jsonb language sql as $$
  select zad_commit_intent(jsonb_build_object('user_id', '11111111-1111-1111-1111-111111111111', 'kind', k,
                                              'client_event_id', e, 'payload', p::jsonb)) $$;

insert into zad_subscriptions (id, user_id, title, amount, renewal_date) values
  ('a0000000-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 'نتفلكس', 200, '2026-12-01');
insert into zad_debts (id, user_id, name, principal_amount, remaining_balance) values
  ('b0000000-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 'جمعية', 5000, 5000);
insert into zad_obligations (id, user_id, title, amount, kind) values
  ('c0000000-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 'إيجار', 3000, 'rent');

-- ===== الاشتراكات =====
select pg_temp.check((pg_temp.me('subscription.added', 's1', '{"title":"  سبوتيفاي ","amount":99.999,"renewal_date":"2026-12-15","category":"ترفيه"}') ->> 'ok')::boolean, 'sub added');
select pg_temp.check((select amount = 100 and title = 'سبوتيفاي' and billing_cycle = 'MONTHLY' and is_active and category = 'ترفيه'
                        from zad_subscriptions where user_id = '11111111-1111-1111-1111-111111111111'), 'sub: trimmed, rounded, defaults');
select pg_temp.check((pg_temp.me('subscription.added', 's1', '{"title":"سبوتيفاي","amount":100}') ->> 'duplicate')::boolean, 'sub: repeat is a duplicate');
select pg_temp.check((select count(*) = 1 from zad_subscriptions where user_id = '11111111-1111-1111-1111-111111111111'), 'sub: one row');
select pg_temp.check(pg_temp.me('subscription.added', 's2', '{"title":"ن","amount":10}') ->> 'reason' = 'subscription_title_invalid', 'sub title');
select pg_temp.check(pg_temp.me('subscription.added', 's3', '{"title":"أنغامي","amount":0}') ->> 'reason' = 'amount_not_positive', 'sub amount zero');
select pg_temp.check(pg_temp.me('subscription.added', 's4', '{"title":"أنغامي","amount":200000000}') ->> 'reason' = 'amount_over_cap', 'sub amount cap');
select pg_temp.check(pg_temp.me('subscription.added', 's5', '{"title":"أنغامي","amount":10,"renewal_date":"2026-13-45"}') ->> 'reason' = 'renewal_date_invalid', 'sub bad date');
select pg_temp.check(pg_temp.me('subscription.added', 's6', '{"title":"أنغامي","amount":10,"renewal_date":"15/12/2026"}') ->> 'reason' = 'renewal_date_invalid', 'sub date format');
select pg_temp.check(pg_temp.me('subscription.added', 's7', '{"title":"أنغامي","amount":10,"billing_cycle":"WEEKLY"}') ->> 'reason' = 'billing_cycle_invalid', 'sub cycle');
select pg_temp.check((select count(*) = 1 from zad_subscriptions where user_id = '11111111-1111-1111-1111-111111111111'), 'sub: refusals wrote nothing');

-- تعديل: المبلغ والتاريخ، والقديم في الحدث.
select pg_temp.check((select id from zad_subscriptions where title = 'سبوتيفاي') is not null, 'have the sub');
create temp table t_sub as select id from zad_subscriptions where title = 'سبوتيفاي';
select pg_temp.check((pg_temp.me('subscription.updated', 's8', format('{"item_id":"%s","patch":{"amount":120,"renewal_date":"2027-01-15","due_day":15}}', (select id from t_sub))) ->> 'ok')::boolean, 'sub updated');
select pg_temp.check((select amount = 120 and renewal_date = '2027-01-15' and due_day = 15 and title = 'سبوتيفاي' from zad_subscriptions where id = (select id from t_sub)), 'sub: patched fields only');
select pg_temp.check((select (payload -> 'before' ->> 'amount')::numeric = 100 and (payload -> 'after' ->> 'amount')::numeric = 120
                        from zad_events where client_event_id = 's8'), 'sub event keeps before and after');
select pg_temp.check((pg_temp.me('subscription.updated', 's9', format('{"item_id":"%s","patch":{"is_active":false,"title":"سبوتيفاي - أخير"}}', (select id from t_sub))) ->> 'ok')::boolean, 'sub deactivated through update');
select pg_temp.check((select not is_active and title = 'سبوتيفاي - أخير' from zad_subscriptions where id = (select id from t_sub)), 'sub: inactive, renamed');
select pg_temp.check(pg_temp.me('subscription.updated', 's10', format('{"item_id":"%s","patch":{}}', (select id from t_sub))) ->> 'reason' = 'patch_empty', 'sub empty patch');
select pg_temp.check(pg_temp.me('subscription.updated', 's11', format('{"item_id":"%s","patch":{"user_id":"22222222-2222-2222-2222-222222222222"}}', (select id from t_sub))) ->> 'reason' = 'patch_field_unknown', 'sub unknown field');
select pg_temp.check(pg_temp.me('subscription.updated', 's12', format('{"item_id":"%s","patch":{"amount":-5}}', (select id from t_sub))) ->> 'reason' = 'amount_not_positive', 'sub patch amount');
select pg_temp.check(pg_temp.me('subscription.updated', 's13', format('{"item_id":"%s","patch":{"renewal_date":"غدا"}}', (select id from t_sub))) ->> 'reason' = 'renewal_date_invalid', 'sub patch date');
select pg_temp.check(pg_temp.me('subscription.updated', 's14', format('{"item_id":"%s","patch":{"due_day":32}}', (select id from t_sub))) ->> 'reason' = 'due_day_invalid', 'sub patch day');
select pg_temp.check(pg_temp.me('subscription.updated', 's15', format('{"item_id":"%s","patch":{"title":"x"}}', (select id from t_sub))) ->> 'reason' = 'subscription_title_invalid', 'sub patch title');
select pg_temp.check(pg_temp.me('subscription.updated', 's16', format('{"item_id":"%s","patch":{"is_active":"yes"}}', (select id from t_sub))) ->> 'reason' = 'is_active_invalid', 'sub patch is_active');
-- صف حد تاني: item_not_found وماتلمسش.
select pg_temp.check(pg_temp.me('subscription.updated', 's17', '{"item_id":"a0000000-0000-0000-0000-000000000001","patch":{"amount":1}}') ->> 'reason' = 'item_not_found', 'sub: other user update');
select pg_temp.check(pg_temp.me('subscription.deleted', 's18', '{"item_id":"a0000000-0000-0000-0000-000000000001"}') ->> 'reason' = 'item_not_found', 'sub: other user delete');
select pg_temp.check(pg_temp.me('subscription.deleted', 's19', '{"item_id":"not-a-uuid"}') ->> 'reason' = 'item_not_found', 'sub: bad id');
select pg_temp.check((select amount = 200 and is_active from zad_subscriptions where id = 'a0000000-0000-0000-0000-000000000001'), 'sub: other user untouched');
-- حذف: الصف كامل في الحدث.
select pg_temp.check((pg_temp.me('subscription.deleted', 's20', format('{"item_id":"%s"}', (select id from t_sub))) ->> 'ok')::boolean, 'sub deleted');
select pg_temp.check(not exists (select 1 from zad_subscriptions where id = (select id from t_sub)), 'sub: gone');
select pg_temp.check((select payload -> 'before' ->> 'title' = 'سبوتيفاي - أخير' and payload -> 'after' = 'null'::jsonb from zad_events where client_event_id = 's20'), 'sub delete: full row in before');

-- ===== الديون =====
select pg_temp.check((pg_temp.me('debt.added', 'd1', '{"name":" سلفة أحمد ","remaining_balance":1500.456,"minimum_payment":100,"interest_rate":2.5,"due_day":10}') ->> 'ok')::boolean, 'debt added');
select pg_temp.check((select principal_amount = 1500.46 and remaining_balance = 1500.46 and minimum_payment = 100 and interest_rate = 2.5 and due_day = 10 and is_active and name = 'سلفة أحمد'
                        from zad_debts where user_id = '11111111-1111-1111-1111-111111111111'), 'debt: principal = balance, trimmed');
select pg_temp.check((pg_temp.me('debt.added', 'd1', '{"name":"سلفة أحمد","remaining_balance":1}') ->> 'duplicate')::boolean, 'debt: duplicate');
select pg_temp.check((pg_temp.me('debt.added', 'd1b', '{"name":"قرض بسيط","remaining_balance":900}') ->> 'ok')::boolean, 'debt added: defaults');
select pg_temp.check((select minimum_payment = 0 and interest_rate = 0 and due_day is null from zad_debts where name = 'قرض بسيط'), 'debt: defaults 0/0/null');
select pg_temp.check(pg_temp.me('debt.added', 'd2', '{"name":"د","remaining_balance":10}') ->> 'reason' = 'debt_name_invalid', 'debt name');
select pg_temp.check(pg_temp.me('debt.added', 'd3', '{"name":"قرض","remaining_balance":0}') ->> 'reason' = 'amount_not_positive', 'debt zero balance');
select pg_temp.check(pg_temp.me('debt.added', 'd4', '{"name":"قرض","remaining_balance":200000000}') ->> 'reason' = 'amount_over_cap', 'debt cap');
select pg_temp.check(pg_temp.me('debt.added', 'd5', '{"name":"قرض","remaining_balance":10,"minimum_payment":-1}') ->> 'reason' = 'minimum_invalid', 'debt minimum');
select pg_temp.check(pg_temp.me('debt.added', 'd6', '{"name":"قرض","remaining_balance":10,"interest_rate":-3}') ->> 'reason' = 'interest_invalid', 'debt interest');
select pg_temp.check(pg_temp.me('debt.added', 'd7', '{"name":"قرض","remaining_balance":10,"due_day":0}') ->> 'reason' = 'due_day_invalid', 'debt day');
select pg_temp.check((select count(*) = 2 from zad_debts where user_id = '11111111-1111-1111-1111-111111111111'), 'debt: refusals wrote nothing');

create temp table t_debt as select id from zad_debts where name = 'سلفة أحمد';
select pg_temp.check((pg_temp.me('debt.updated', 'd8', format('{"item_id":"%s","patch":{"remaining_balance":1000,"minimum_payment":150}}', (select id from t_debt))) ->> 'ok')::boolean, 'debt updated');
select pg_temp.check((select remaining_balance = 1000 and minimum_payment = 150 and principal_amount = 1500.46 and is_active from zad_debts where id = (select id from t_debt)), 'debt: patched, principal kept');
select pg_temp.check((select (payload -> 'before' ->> 'remaining_balance')::numeric = 1500.46 from zad_events where client_event_id = 'd8'), 'debt event keeps before');
select pg_temp.check((pg_temp.me('debt.updated', 'd9', format('{"item_id":"%s","patch":{"remaining_balance":0,"is_active":false}}', (select id from t_debt))) ->> 'ok')::boolean, 'debt closed at zero');
select pg_temp.check((select remaining_balance = 0 and not is_active from zad_debts where id = (select id from t_debt)), 'debt: zero and inactive');
select pg_temp.check(pg_temp.me('debt.updated', 'd10', format('{"item_id":"%s","patch":{"remaining_balance":-1}}', (select id from t_debt))) ->> 'reason' = 'balance_negative', 'debt negative balance');
select pg_temp.check(pg_temp.me('debt.updated', 'd11', format('{"item_id":"%s","patch":{"minimum_payment":-1}}', (select id from t_debt))) ->> 'reason' = 'minimum_invalid', 'debt patch minimum');
select pg_temp.check(pg_temp.me('debt.updated', 'd12', format('{"item_id":"%s","patch":{}}', (select id from t_debt))) ->> 'reason' = 'patch_empty', 'debt empty patch');
select pg_temp.check(pg_temp.me('debt.updated', 'd13', format('{"item_id":"%s","patch":{"name":"x"}}', (select id from t_debt))) ->> 'reason' = 'patch_field_unknown', 'debt unknown field');
select pg_temp.check(pg_temp.me('debt.updated', 'd14', format('{"item_id":"%s","patch":{"is_active":1}}', (select id from t_debt))) ->> 'reason' = 'is_active_invalid', 'debt is_active');
select pg_temp.check(pg_temp.me('debt.updated', 'd15', '{"item_id":"b0000000-0000-0000-0000-000000000001","patch":{"remaining_balance":1}}') ->> 'reason' = 'item_not_found', 'debt: other user update');
select pg_temp.check(pg_temp.me('debt.deleted', 'd16', '{"item_id":"b0000000-0000-0000-0000-000000000001"}') ->> 'reason' = 'item_not_found', 'debt: other user delete');
select pg_temp.check((select remaining_balance = 5000 and is_active from zad_debts where id = 'b0000000-0000-0000-0000-000000000001'), 'debt: other user untouched');
select pg_temp.check((pg_temp.me('debt.deleted', 'd17', format('{"item_id":"%s"}', (select id from t_debt))) ->> 'ok')::boolean, 'debt deleted');
select pg_temp.check(not exists (select 1 from zad_debts where id = (select id from t_debt)), 'debt: gone');
select pg_temp.check((select payload -> 'before' ->> 'name' = 'سلفة أحمد' and payload -> 'after' = 'null'::jsonb from zad_events where client_event_id = 'd17'), 'debt delete: full row in before');

-- ===== الالتزامات =====
select pg_temp.check((pg_temp.me('obligation.added', 'o1', '{"title":"إيجار الشقة","amount":3500,"kind":"rent","due_day":1}') ->> 'ok')::boolean, 'obligation added');
select pg_temp.check((select recurrence = 'monthly' and not auto_detected and confirmed and active and provider is null and total_installments is null
                        from zad_obligations where title = 'إيجار الشقة'), 'obligation: defaults');
select pg_temp.check((pg_temp.me('obligation.added', 'o1', '{"title":"إيجار الشقة","amount":3500,"kind":"rent"}') ->> 'duplicate')::boolean, 'obligation: duplicate');
select pg_temp.check((pg_temp.me('obligation.added', 'o2', '{"title":"قسط تابي","amount":250,"kind":"installment","recurrence":"monthly","provider":"تابي","total_installments":6.2,"auto_detected":true}') ->> 'ok')::boolean, 'bnpl obligation');
select pg_temp.check((select provider = 'تابي' and total_installments = 6 and remaining_installments = 6 and auto_detected from zad_obligations where title = 'قسط تابي'), 'bnpl: installments start full');
select pg_temp.check((pg_temp.me('obligation.added', 'o3', '{"title":"مصاريف مدرسة","amount":9000,"kind":"tuition","provider":"محل","total_installments":4}') ->> 'ok')::boolean, 'unknown provider is dropped');
select pg_temp.check((select provider is null and total_installments is null from zad_obligations where title = 'مصاريف مدرسة'), 'unknown provider: no installments either');
select pg_temp.check(pg_temp.me('obligation.added', 'o4', '{"title":"ا","amount":10,"kind":"rent"}') ->> 'reason' = 'obligation_title_invalid', 'obligation title');
select pg_temp.check(pg_temp.me('obligation.added', 'o5', '{"title":"فاتورة","amount":0,"kind":"utility"}') ->> 'reason' = 'amount_not_positive', 'obligation amount');
select pg_temp.check(pg_temp.me('obligation.added', 'o6', '{"title":"فاتورة","amount":200000000,"kind":"utility"}') ->> 'reason' = 'amount_over_cap', 'obligation cap');
select pg_temp.check(pg_temp.me('obligation.added', 'o7', '{"title":"فاتورة","amount":10,"kind":"gift"}') ->> 'reason' = 'obligation_kind_invalid', 'obligation kind');
select pg_temp.check(pg_temp.me('obligation.added', 'o8', '{"title":"فاتورة","amount":10,"kind":"utility","recurrence":"weekly"}') ->> 'reason' = 'recurrence_invalid', 'obligation recurrence');
select pg_temp.check(pg_temp.me('obligation.added', 'o9', '{"title":"فاتورة","amount":10,"kind":"utility","due_day":40}') ->> 'reason' = 'due_day_invalid', 'obligation day');
select pg_temp.check(pg_temp.me('obligation.added', 'o10', '{"title":"قسط","amount":10,"kind":"installment","provider":"تابي","total_installments":0}') ->> 'reason' = 'installments_invalid', 'obligation installments');
select pg_temp.check((select count(*) = 3 from zad_obligations where user_id = '11111111-1111-1111-1111-111111111111'), 'obligation: refusals wrote nothing');

create temp table t_obl as select id from zad_obligations where title = 'إيجار الشقة';
select pg_temp.check((pg_temp.me('obligation.updated', 'o11', format('{"item_id":"%s","patch":{"amount":3800,"due_day":5}}', (select id from t_obl))) ->> 'ok')::boolean, 'obligation updated');
select pg_temp.check((select amount = 3800 and due_day = 5 and active from zad_obligations where id = (select id from t_obl)), 'obligation: patched');
select pg_temp.check((select (payload -> 'before' ->> 'amount')::numeric = 3500 from zad_events where client_event_id = 'o11'), 'obligation event keeps before');
select pg_temp.check(pg_temp.me('obligation.updated', 'o12', format('{"item_id":"%s","patch":{}}', (select id from t_obl))) ->> 'reason' = 'patch_empty', 'obligation empty patch');
select pg_temp.check(pg_temp.me('obligation.updated', 'o13', format('{"item_id":"%s","patch":{"kind":"other"}}', (select id from t_obl))) ->> 'reason' = 'patch_field_unknown', 'obligation unknown field');
select pg_temp.check(pg_temp.me('obligation.updated', 'o14', format('{"item_id":"%s","patch":{"amount":0}}', (select id from t_obl))) ->> 'reason' = 'amount_not_positive', 'obligation patch amount');
select pg_temp.check(pg_temp.me('obligation.updated', 'o15', format('{"item_id":"%s","patch":{"due_day":0}}', (select id from t_obl))) ->> 'reason' = 'due_day_invalid', 'obligation patch day');
select pg_temp.check(pg_temp.me('obligation.updated', 'o16', '{"item_id":"c0000000-0000-0000-0000-000000000001","patch":{"amount":1}}') ->> 'reason' = 'item_not_found', 'obligation: other user update');
select pg_temp.check(pg_temp.me('obligation.deactivated', 'o17', '{"item_id":"c0000000-0000-0000-0000-000000000001"}') ->> 'reason' = 'item_not_found', 'obligation: other user deactivate');
select pg_temp.check((select amount = 3000 and active from zad_obligations where id = 'c0000000-0000-0000-0000-000000000001'), 'obligation: other user untouched');
-- حذف ناعم: الصف يفضل بـactive=false، والحدث شايل الصف قبل.
select pg_temp.check((pg_temp.me('obligation.deactivated', 'o18', format('{"item_id":"%s"}', (select id from t_obl))) ->> 'ok')::boolean, 'obligation deactivated');
select pg_temp.check((select not active and amount = 3800 from zad_obligations where id = (select id from t_obl)), 'obligation: soft, row stays');
select pg_temp.check((select (payload -> 'before' ->> 'active')::boolean and not (payload -> 'after' ->> 'active')::boolean from zad_events where client_event_id = 'o18'), 'obligation event: active before, inactive after');
select pg_temp.check(pg_temp.me('obligation.deactivated', 'o19', format('{"item_id":"%s"}', (select id from t_obl))) ->> 'reason' = 'already_inactive', 'obligation: twice');

-- ===== كل رفض اتسجل =====
select pg_temp.check((select count(*) from zad_guard_events where intent ->> 'client_event_id' in
  ('s2','s3','s4','s5','s6','s7','s10','s11','s12','s13','s14','s15','s16','s17','s18','s19',
   'd2','d3','d4','d5','d6','d7','d10','d11','d12','d13','d14','d15','d16',
   'o4','o5','o6','o7','o8','o9','o10','o12','o13','o14','o15','o16','o17','o19')) = 43, 'every refusal logged');
select pg_temp.check((select count(*) = 1 from zad_guard_events where intent ->> 'client_event_id' = 's17' and reason = 'item_not_found'), 'refusal carries its reason');

select 'commit_intent_life_money: all checks passed';
