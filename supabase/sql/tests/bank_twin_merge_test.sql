-- حركة البنك اللي ماحدّش شرحها (migration 20261102060000). Run after the purchase-door chain
-- (scaffolds, 20261019180000, 20261019200000, 20261019220000, 20261020110000) and the migration.
-- The cases are the owner's 1/11: 124.54 from the bank, then the receipt 33 minutes later; 3500
-- from the bank, then «إيجار شقة» in words.

\set ON_ERROR_STOP on

insert into auth.users values ('00000000-0000-0000-0000-00000000000a'), ('00000000-0000-0000-0000-00000000000b');

insert into public.zad_transactions (id, user_id, amount, title, category, source_type, created_at) values
  ('b0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000a', 124.54, 'BDC', 'أخرى', 'notification_listener', now() - interval '33 minutes'),
  ('b0000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-00000000000a', 3500, 'BDC', 'أخرى', 'notification_listener', now() - interval '18 minutes'),
  -- Already explained by the customer: not a twin any more.
  ('b0000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-00000000000a', 80, 'BDC', 'البقالة', 'notification_listener', now() - interval '1 hour'),
  -- Too old.
  ('b0000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-00000000000a', 60, 'BDC', null, 'notification_listener', now() - interval '7 hours'),
  -- Not from the bank.
  ('b0000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-00000000000a', 45, 'قهوة', null, 'telegram', now() - interval '1 hour'),
  -- The bank named a merchant: words are not pulled onto it (20261102070000) — «إيجار شقة» was not etisalat.
  ('b0000000-0000-0000-0000-000000000007', '00000000-0000-0000-0000-00000000000a', 777, 'BDC', 'أخرى', 'notification_listener', now() - interval '20 minutes'),
  ('b0000000-0000-0000-0000-000000000008', '00000000-0000-0000-0000-00000000000a', 888, 'BDC', 'أخرى', 'notification_listener', now() - interval '20 minutes'),
  -- Someone else's.
  ('b0000000-0000-0000-0000-000000000006', '00000000-0000-0000-0000-00000000000b', 200, 'BDC', null, 'notification_listener', now() - interval '1 hour');

select set_config('request.jwt.claims', '{"role":"service_role"}', false);

update public.zad_transactions set merchant_name = 'etisalat' where id = 'b0000000-0000-0000-0000-000000000007';
update public.zad_transactions set merchant_name = 'com.google.android.apps.messaging' where id = 'b0000000-0000-0000-0000-000000000008';
-- The bank's own name as merchant (an InstaPay transfer with no counterparty): no merchant (20261102080000).
insert into public.zad_transactions (id, user_id, amount, title, category, source_type, merchant_name, bank_name, created_at) values
  ('b0000000-0000-0000-0000-000000000009', '00000000-0000-0000-0000-00000000000a', 999, 'BDC', 'أخرى', 'notification_listener', 'BDC', 'bdc', now() - interval '18 minutes');

do $$
declare r jsonb; n int;
begin
  assert public.zad_bank_twin_service('00000000-0000-0000-0000-00000000000a', 777) is null, 'a named merchant is not the words';
  assert public.zad_bank_twin_service('00000000-0000-0000-0000-00000000000a', 999) = 'b0000000-0000-0000-0000-000000000009', 'the bank is not a merchant';
  assert public.zad_bank_twin_service('00000000-0000-0000-0000-00000000000a', 888) = 'b0000000-0000-0000-0000-000000000008', 'the messaging app is not a merchant';
  -- …but a receipt to the piaster still merges into it.
  assert private.zad_bank_twin('00000000-0000-0000-0000-00000000000a', 777, now()) = 'b0000000-0000-0000-0000-000000000007';

  -- The receipt 33 minutes later merges: one row, the shop's name, the bank's amount and time.
  r := public.zad_record_purchase_service('00000000-0000-0000-0000-00000000000a', jsonb_build_object(
    'id', 'c0000000-0000-0000-0000-000000000001', 'amount', 124.54, 'title', 'فتح الله العطار',
    'category', 'البقالة', 'merchant_name', 'فتح الله العطار', 'source_type', 'receipt', 'wallet', 'card',
    'lines', jsonb_build_array(jsonb_build_object('name', 'شعيرية', 'quantity', 1, 'to', 'pantry'))));
  assert r ->> 'status' = 'merged', r::text;
  assert r ->> 'transaction_id' = 'b0000000-0000-0000-0000-000000000001', r::text;
  select count(*) into n from public.zad_transactions where user_id = '00000000-0000-0000-0000-00000000000a' and abs(amount - 124.54) < 0.005;
  assert n = 1, 'one payment, one expense: ' || n;
  assert (select title from public.zad_transactions where id = 'b0000000-0000-0000-0000-000000000001') = 'فتح الله العطار';
  assert (select category from public.zad_transactions where id = 'b0000000-0000-0000-0000-000000000001') = 'البقالة';
  assert (select count(*) from public.zad_inventory where item_name = 'شعيرية') = 1, 'the lines still go in';

  -- Merged once ⇒ explained: the same amount again is not pulled onto it.
  assert private.zad_bank_twin('00000000-0000-0000-0000-00000000000a', 124.54, now()) is null;

  -- The words path asks the same question.
  assert public.zad_bank_twin_service('00000000-0000-0000-0000-00000000000a', 3500) = 'b0000000-0000-0000-0000-000000000002';
  assert public.zad_bank_twin_service('00000000-0000-0000-0000-00000000000a', 80) is null, 'categorised';
  assert public.zad_bank_twin_service('00000000-0000-0000-0000-00000000000a', 60) is null, 'older than 6 hours';
  assert public.zad_bank_twin_service('00000000-0000-0000-0000-00000000000a', 45) is null, 'not the bank';
  assert public.zad_bank_twin_service('00000000-0000-0000-0000-00000000000a', 200) is null, 'not theirs';
  assert public.zad_bank_twin_service('00000000-0000-0000-0000-00000000000a', 3499.99) is null, 'to the piaster';

  -- Cash is not the card's notification: its own expense.
  r := public.zad_record_purchase_service('00000000-0000-0000-0000-00000000000a', jsonb_build_object(
    'id', 'c0000000-0000-0000-0000-000000000002', 'amount', 3500, 'title', 'إيجار كاش', 'wallet', 'cash',
    'allow_duplicate', true, 'lines', '[]'::jsonb));
  assert r ->> 'status' = 'recorded', r::text;

  -- «دي عملية تانية» still gets through.
  r := public.zad_record_purchase_service('00000000-0000-0000-0000-00000000000a', jsonb_build_object(
    'id', 'c0000000-0000-0000-0000-000000000003', 'amount', 3500, 'title', 'تاني', 'wallet', 'card',
    'allow_duplicate', true, 'lines', '[]'::jsonb));
  assert r ->> 'status' = 'recorded', r::text;
  assert (select title from public.zad_transactions where id = 'b0000000-0000-0000-0000-000000000002') = 'BDC', 'untouched';

  -- Lines only («المخزن بس») never touches the money.
  r := public.zad_record_purchase_service('00000000-0000-0000-0000-00000000000a', jsonb_build_object(
    'id', 'c0000000-0000-0000-0000-000000000004', 'title', 'بقالة',
    'lines', jsonb_build_array(jsonb_build_object('name', 'رز', 'quantity', 1, 'to', 'pantry'))));
  assert r ->> 'status' = 'lines_only', r::text;
  assert (select title from public.zad_transactions where id = 'b0000000-0000-0000-0000-000000000002') = 'BDC';
end $$;

select 'bank_twin_merge_test: ok' as result;
