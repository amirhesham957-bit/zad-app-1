-- ZAD_OR_PLAN م٢.٥: الرصيد وسقوف الفئات من الباب.
\set ON_ERROR_STOP on
create or replace function pg_temp.check(cond boolean, what text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAILED: %', what; end if; end $$;
create or replace function pg_temp.ci(j text) returns jsonb language sql as $$ select zad_commit_intent(j::jsonb) $$;

update zad_users set monthly_limit = 5000 where id = '11111111-1111-1111-1111-111111111111';

-- ١) الرصيد: بيتقرّب، وتاريخ التأكيد بيتكتب، والقديم في الحدث.
select pg_temp.check((pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"money.limit_set","client_event_id":"b1","payload":{"amount":8000.456}}') ->> 'ok')::boolean, 'limit set');
select pg_temp.check((select monthly_limit = 8000.46 and limit_confirmed_at is not null from zad_users where id = '11111111-1111-1111-1111-111111111111'), 'rounded and confirmed');
select pg_temp.check((select (payload -> 'before' ->> 'monthly_limit')::numeric = 5000 from zad_events where client_event_id = 'b1'), 'event keeps the old balance');
select pg_temp.check(pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"money.limit_set","client_event_id":"b2","payload":{"amount":0}}') ->> 'reason' = 'amount_not_positive', 'zero balance');
select pg_temp.check(pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"money.limit_set","client_event_id":"b3","payload":{"amount":200000000}}') ->> 'reason' = 'amount_over_cap', 'absurd balance');
select pg_temp.check((select monthly_limit from zad_users where id = '11111111-1111-1111-1111-111111111111') = 8000.46, 'refusals wrote nothing');
-- الرصيد بتاع العميل نفسه بس: المستخدم ٢ ماتلمسش.
select pg_temp.check((select monthly_limit is null from zad_users where id = '22222222-2222-2222-2222-222222222222'), 'other user untouched');

-- ٢) سقف فئة: جديد، تعديل (مش صف تاني)، شيل بصفر.
select pg_temp.check((pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"money.category_budget_set","client_event_id":"b4","payload":{"category":"مطاعم","amount":1500}}') ->> 'ok')::boolean, 'cap set');
select pg_temp.check((pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"money.category_budget_set","client_event_id":"b5","payload":{"category":"مطاعم","amount":1200}}') ->> 'ok')::boolean, 'cap changed');
select pg_temp.check((select count(*) = 1 and max(amount) = 1200 from zad_category_budgets where category = 'مطاعم'), 'one cap row, new amount');
select pg_temp.check((select (payload -> 'before' ->> 'amount')::numeric = 1500 from zad_events where client_event_id = 'b5'), 'event keeps the old cap');
select pg_temp.check((pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"money.category_budget_set","client_event_id":"b6","payload":{"category":"مطاعم","amount":0}}') ->> 'ok')::boolean, 'cap removed with zero');
select pg_temp.check(not exists (select 1 from zad_category_budgets where category = 'مطاعم'), 'cap gone');
select pg_temp.check(pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"money.category_budget_set","client_event_id":"b7","payload":{"category":"مطاعم","amount":0}}') ->> 'reason' = 'no_category_budget', 'nothing to remove');
select pg_temp.check(pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"money.category_budget_set","client_event_id":"b8","payload":{"category":"م","amount":100}}') ->> 'reason' = 'category_invalid', 'category name');
select pg_temp.check(pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"money.category_budget_set","client_event_id":"b9","payload":{"category":"مطاعم","amount":-1}}') ->> 'reason' = 'amount_not_positive', 'negative cap');
select pg_temp.check((select count(*) from zad_guard_events where intent ->> 'client_event_id' in ('b2','b3','b7','b8','b9')) = 5, 'every refusal logged');

-- ٣) المعاملات لسه شغالة من نفس المجال.
select pg_temp.check((pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"money.logged","client_event_id":"b10","payload":{"amount":20,"title":"عيش","txn_kind":"expense"}}') ->> 'ok')::boolean, 'transactions still work');

select 'commit_intent_budgets: all checks passed';
