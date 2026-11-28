-- P3.12: محفظة الكاش من الباب. بعد سلسلة باب الفلوس + 20260726060000 (zad_cash_balance) + السقالة + 20261128210000.
-- حالة المالك ٢٨/١١: سحب كاش، ودفع فيزا إشعاره وصل ومعاه فاتورته، وصرف كاش.
\set ON_ERROR_STOP on
create or replace function pg_temp.check(cond boolean, what text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAILED: %', what; end if; end $$;
create or replace function pg_temp.ci(j text) returns jsonb language sql as $$ select zad_commit_intent(j::jsonb) $$;
create or replace function pg_temp.cash(u text) returns numeric language sql as $$ select zad_cash_balance(u::uuid) $$;

-- ١) سحب ATM: تحويل مش مصروف، الكاش بيزيد بس، والمصروف صفر.
select pg_temp.check((pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"money.cash_withdrawn","client_event_id":"c1","payload":{"amount":1000,"title":"سحب كاش — bdc"}}') ->> 'ok')::boolean, 'withdrawal recorded');
select pg_temp.check((select txn_kind = 'transfer' and transfer_to = 'cash' and wallet = 'card' from zad_transactions where title = 'سحب كاش — bdc'), 'a transfer to cash, not an expense');
select pg_temp.check(pg_temp.cash('11111111-1111-1111-1111-111111111111') = 1000, 'cash = 1000 after the withdrawal');
select pg_temp.check((select (payload ->> 'cash_before')::numeric = 0 and (payload ->> 'cash_after')::numeric = 1000 from zad_events where client_event_id = 'c1'), 'event carries cash before/after');
select pg_temp.check((select coalesce(sum(amount), 0) from zad_transactions where user_id = '11111111-1111-1111-1111-111111111111' and txn_kind = 'expense') = 0, 'withdrawal is not spend');

-- ٢) نفس السحب جاي تاني (إشعار البنك وبعدين «سحبت ١٠٠٠»): سؤال واحد مش كاش مضاعف.
select pg_temp.check(pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"money.cash_withdrawn","client_event_id":"c2","payload":{"amount":1000}}') ->> 'reason' = 'cash_withdrawal_duplicate_suspected', 'same withdrawal seen twice asks once');
select pg_temp.check(pg_temp.cash('11111111-1111-1111-1111-111111111111') = 1000, 'cash unchanged after the refused twin');
select pg_temp.check((pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"money.cash_withdrawn","client_event_id":"c3","payload":{"amount":1000,"allow_duplicate":true}}') ->> 'ok')::boolean, 'two real withdrawals pass with the answer');
select pg_temp.check(pg_temp.cash('11111111-1111-1111-1111-111111111111') = 2000, 'cash = 2000 after the confirmed second withdrawal');
select pg_temp.check(pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"money.cash_withdrawn","client_event_id":"c4","payload":{"amount":500,"from_wallet":"cash"}}') ->> 'reason' = 'wallet_unknown', 'cannot withdraw from cash');

-- ٣) صرف كاش: بيخصم من الكاش بس.
select pg_temp.check((pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"money.cash_spent","client_event_id":"c5","payload":{"amount":120,"title":"بقالة","category":"بقالة"}}') ->> 'ok')::boolean, 'cash spend recorded');
select pg_temp.check((select wallet = 'cash' and txn_kind = 'expense' and is_expense from zad_transactions where title = 'بقالة'), 'an expense from the cash wallet');
select pg_temp.check(pg_temp.cash('11111111-1111-1111-1111-111111111111') = 1880, 'cash = 1880');

-- ٤) فيزا: إشعار البنك + فاتورة الكارت ما بيلمسوش الكاش.
insert into zad_transactions (user_id, amount, title, category, source_type, wallet, txn_kind, is_expense, created_at)
values ('11111111-1111-1111-1111-111111111111', 245.50, 'BDC', 'أخرى', 'notification_listener', 'card', 'expense', true, now() - interval '20 minutes');
select pg_temp.check(pg_temp.cash('11111111-1111-1111-1111-111111111111') = 1880, 'a card notice does not touch cash');
select pg_temp.check((pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"money.purchase","client_event_id":"c6","payload":{"purchase":{"amount":99,"title":"صيدلية","wallet":"card","lines":[{"name":"فيتامين"}]}}}') ->> 'ok')::boolean, 'card purchase through the purchase door');
select pg_temp.check(pg_temp.cash('11111111-1111-1111-1111-111111111111') = 1880, 'a card purchase does not touch cash');

-- ٥) فاتورة «كاش» بنفس مبلغ إشعار الفيزا: غالباً دفعة واحدة، سؤال واحد، والكاش ماينقصش مرتين.
select pg_temp.check(pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"money.cash_spent","client_event_id":"c7","payload":{"amount":245.50,"title":"سوبرماركت"}}') ->> 'reason' = 'cash_spend_matches_bank_notice', 'cash spend matching a bank notice asks');
select pg_temp.check((pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"money.cash_spent","client_event_id":"c8","payload":{"amount":245.50,"title":"سوبرماركت"}}') -> 'detail' ->> 'title') = 'BDC', 'the question carries the notice');
select pg_temp.check(pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"money.purchase","client_event_id":"c9","payload":{"purchase":{"amount":245.50,"title":"سوبرماركت","wallet":"cash","lines":[{"name":"لبن"}]}}}') ->> 'reason' = 'cash_spend_matches_bank_notice', 'cash receipt matching a bank notice asks');
select pg_temp.check(pg_temp.cash('11111111-1111-1111-1111-111111111111') = 1880, 'cash unchanged after the refused twins');
select pg_temp.check((pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"money.cash_spent","client_event_id":"c10","payload":{"amount":245.50,"title":"سوبرماركت","confirm_cash":true}}') ->> 'ok')::boolean, 'confirmed cash spend goes through');
select pg_temp.check(pg_temp.cash('11111111-1111-1111-1111-111111111111') = 1634.5, 'cash = 1634.5 after the confirmed spend');

-- ٦) القيود والتكرار والعزل.
select pg_temp.check(pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"money.cash_spent","client_event_id":"c11","payload":{"amount":-5,"title":"غلط"}}') ->> 'reason' = 'amount_not_positive', 'negative cash spend');
select pg_temp.check((pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"money.cash_spent","client_event_id":"c5","payload":{"amount":120,"title":"بقالة"}}') ->> 'duplicate')::boolean, 'same client_event_id is a duplicate');
select pg_temp.check(pg_temp.cash('11111111-1111-1111-1111-111111111111') = 1634.5, 'duplicate did not deduct again');
select pg_temp.check(pg_temp.cash('22222222-2222-2222-2222-222222222222') = 0, 'someone else has their own cash');
select pg_temp.check((pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"money.logged","client_event_id":"c12","payload":{"amount":5,"title":"قهوة","txn_kind":"expense"}}') ->> 'ok')::boolean, 'ordinary money kinds still work');
select pg_temp.check(pg_temp.cash('11111111-1111-1111-1111-111111111111') = 1634.5, 'an ordinary card expense does not touch cash');
set role service_role;
do $$ begin
  perform zad_intent_money('11111111-1111-1111-1111-111111111111', 'money.cash_spent', '{}'::jsonb, now());
  raise exception 'FAILED: service_role can call zad_intent_money';
exception when insufficient_privilege then null;
end $$;
reset role;
select 'cash_wallet: all checks passed' as result;
