-- ZAD_OR_PLAN م٢.٥: المعاملات من الباب — تسجيل وتعديل بحقول معروفة وحذف وشرا بأصناف، معاملات العميل نفسه بس.
\set ON_ERROR_STOP on
create or replace function pg_temp.check(cond boolean, what text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAILED: %', what; end if; end $$;
create or replace function pg_temp.ci(j text) returns jsonb language sql as $$ select zad_commit_intent(j::jsonb) $$;

insert into zad_transactions (id, user_id, amount, title, txn_kind, is_expense, created_at) values
  ('d0000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 120, 'بقالة', 'expense', true, now() - interval '2 days'),
  ('d0000000-0000-0000-0000-000000000002', '22222222-2222-2222-2222-222222222222', 300, 'إيجار', 'expense', true, now() - interval '2 days');

-- ١) تسجيل: المبلغ بيتقرّب، العمودين مع بعض، ومفيش «لمين» على دخل.
select pg_temp.check((pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"money.logged","client_event_id":"m1","payload":{"amount":50.555,"title":"قهوة","txn_kind":"expense","category":"مطاعم","for_person":"ماما"}}') ->> 'ok')::boolean, 'expense logged');
select pg_temp.check((select amount = 50.56 and is_expense and wallet = 'card' and for_person = 'ماما' from zad_transactions where title = 'قهوة'), 'rounded, both columns, for_person');
select pg_temp.check((pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"money.logged","client_event_id":"m2","payload":{"amount":10000,"title":"راتب","txn_kind":"income","for_person":"ماما"}}') ->> 'ok')::boolean, 'income logged');
select pg_temp.check((select not is_expense and for_person is null from zad_transactions where title = 'راتب'), 'income: not an expense, no for_person');
-- نفس الطلب تاني (الراتب اللي اتسجل ٣ مرات ١٥/٨): مرة واحدة.
select pg_temp.check((pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"money.logged","client_event_id":"m2","payload":{"amount":10000,"title":"راتب","txn_kind":"income"}}') ->> 'duplicate')::boolean, 'repeat is a duplicate');
select pg_temp.check((select count(*) from zad_transactions where title = 'راتب') = 1, 'one salary row');
-- تسوية الكاش: تحويل لازم يقول رايح فين.
select pg_temp.check((pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"money.logged","client_event_id":"m3","payload":{"amount":200,"title":"تسوية كاش","txn_kind":"transfer","transfer_to":"cash","wallet":"cash"}}') ->> 'ok')::boolean, 'transfer with a target');
select pg_temp.check(pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"money.logged","client_event_id":"m4","payload":{"amount":200,"title":"تسوية","txn_kind":"transfer"}}') ->> 'reason' = 'transfer_to_missing', 'transfer without a target');

-- ٢) القيود.
select pg_temp.check(pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"money.logged","client_event_id":"m5","payload":{"amount":-5,"title":"غلط","txn_kind":"expense"}}') ->> 'reason' = 'amount_not_positive', 'negative');
select pg_temp.check(pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"money.logged","client_event_id":"m6","payload":{"amount":2000000,"title":"شقة","txn_kind":"expense"}}') ->> 'reason' = 'amount_over_cap', 'too large');
select pg_temp.check(pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"money.logged","client_event_id":"m7","payload":{"amount":100,"title":"مصروف صلاة العصر - مثلا صدقة؟","txn_kind":"expense"}}') ->> 'reason' = 'title_guessed', 'a guessed title (29/9)');
select pg_temp.check(pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"money.logged","client_event_id":"m8","payload":{"amount":100,"title":"هدية","txn_kind":"gift"}}') ->> 'reason' = 'txn_kind_unknown', 'kind list');
select pg_temp.check(pg_temp.ci(format('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"money.logged","client_event_id":"m9","payload":{"amount":100,"title":"بكرة","txn_kind":"expense","created_at":"%s"}}', now() + interval '2 days')) ->> 'reason' = 'date_invalid', 'future date');
select pg_temp.check((select count(*) from zad_guard_events where intent ->> 'client_event_id' in ('m4','m5','m6','m7','m8','m9')) = 6, 'every refusal logged');

-- ٣) التعديل: الحقول المعروفة بس، النوع بيجرّ is_expense، والقديم في الحدث.
select pg_temp.check((pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"money.updated","client_event_id":"m10","payload":{"item_id":"d0000000-0000-0000-0000-000000000001","patch":{"amount":125,"txn_kind":"income"}}}') ->> 'ok')::boolean, 'update own');
select pg_temp.check((select amount = 125 and txn_kind = 'income' and not is_expense from zad_transactions where id = 'd0000000-0000-0000-0000-000000000001'), 'kind and is_expense move together');
select pg_temp.check((select (payload -> 'before' ->> 'amount')::numeric = 120 and payload -> 'before' ->> 'txn_kind' = 'expense' from zad_events where client_event_id = 'm10'), 'event keeps the old values');
select pg_temp.check(pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"money.updated","client_event_id":"m11","payload":{"item_id":"d0000000-0000-0000-0000-000000000001","patch":{"user_id":"22222222-2222-2222-2222-222222222222"}}}') ->> 'reason' = 'patch_field_unknown', 'owner cannot be patched');
select pg_temp.check(pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"money.updated","client_event_id":"m12","payload":{"item_id":"d0000000-0000-0000-0000-000000000001","patch":{"txn_kind":"transfer"}}}') ->> 'reason' = 'transfer_change_unsupported', 'no transfer by patch');
select pg_temp.check(pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"money.updated","client_event_id":"m13","payload":{"item_id":"d0000000-0000-0000-0000-000000000002","patch":{"amount":1}}}') ->> 'reason' = 'item_not_found', 'someone else''s transaction');
select pg_temp.check((select amount from zad_transactions where id = 'd0000000-0000-0000-0000-000000000002') = 300, 'untouched');
select pg_temp.check((pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"money.updated","client_event_id":"m14","payload":{"item_id":"d0000000-0000-0000-0000-000000000001","patch":{"counts_toward_budget":false}}}') ->> 'ok')::boolean, 'allocate income');

-- ٤) الحذف.
select pg_temp.check((pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"money.deleted","client_event_id":"m15","payload":{"item_id":"d0000000-0000-0000-0000-000000000001"}}') ->> 'ok')::boolean, 'delete own');
select pg_temp.check((select payload -> 'before' ->> 'title' = 'بقالة' from zad_events where client_event_id = 'm15'), 'event keeps the row');
select pg_temp.check(pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"money.deleted","client_event_id":"m16","payload":{"item_id":"d0000000-0000-0000-0000-000000000002"}}') ->> 'reason' = 'item_not_found', 'not someone else''s');

-- ٥) شرا بأصناف من باب الشرا، والرفض بتاعه بيرجع بتفاصيله.
select pg_temp.check((pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"money.purchase","client_event_id":"m17","payload":{"purchase":{"amount":75,"title":"خضار","lines":[{"name":"طماطم"}]}}}') -> 'payload' -> 'after' ->> 'ok')::boolean, 'purchase recorded');
select pg_temp.check((select (r ->> 'reason') = 'purchase_duplicate_suspected' and r -> 'detail' -> 'twin' ->> 'title' = 'خضار'
                      from (select pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"money.purchase","client_event_id":"m18","payload":{"purchase":{"amount":75,"title":"خضار تاني","lines":[{"name":"خيار"}]}}}') r) x),
                     'purchase door refusal comes back with its detail');
select pg_temp.check(pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"money.purchase","client_event_id":"m19","payload":{"purchase":{"amount":75,"title":"يمكن خضار؟","lines":[{"name":"خيار"}]}}}') ->> 'reason' = 'title_guessed', 'purchase title checked before the purchase door');

-- ٦) المجالات التانية، ودوال المجال مقفولة.
select pg_temp.check((pg_temp.ci('{"user_id":"11111111-1111-1111-1111-111111111111","kind":"pharmacy.added","client_event_id":"m20","payload":{"name":"بنادول"}}') ->> 'ok')::boolean, 'pharmacy still works');
set role service_role;
do $$ begin
  perform zad_intent_money('11111111-1111-1111-1111-111111111111', 'money.deleted', '{}'::jsonb, now());
  raise exception 'FAILED: service_role can call zad_intent_money';
exception when insufficient_privilege then null;
end $$;
reset role;

select 'commit_intent_money: all checks passed';
