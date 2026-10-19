-- باب شرا واحد (migration 20261019180000). Run after purchase_door_scaffold.sql and the
-- migration, on a scratch database (CI: edge-functions.yml, job sql-tests).

\set ON_ERROR_STOP on

insert into auth.users values
  ('00000000-0000-0000-0000-00000000000a'), ('00000000-0000-0000-0000-00000000000b'),
  ('00000000-0000-0000-0000-00000000000c');
insert into public.family_groups values ('00000000-0000-0000-0000-0000000000f1');
insert into public.family_members values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000f1'),
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000000f1');

-- The family already has milk (B's row) and «توست برانش»; A's list wants milk.
insert into public.zad_inventory (user_id, item_name, quantity, unit) values
  ('00000000-0000-0000-0000-00000000000b', 'اللبن', 1, 'علبة'),
  ('00000000-0000-0000-0000-00000000000b', 'توست برانش', 0, null);
insert into public.zad_shopping_list (user_id, item_name) values
  ('00000000-0000-0000-0000-00000000000a', 'لبن');

-- A, as the app calls it.
set role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}', false);

do $$
declare r jsonb; r2 jsonb;
begin
  r := public.zad_record_purchase(jsonb_build_object(
    'id', '11111111-1111-1111-1111-111111111111',
    'amount', 250.5, 'title', 'كارفور', 'category', 'بقالة', 'merchant_name', 'كارفور',
    'source_type', 'receipt', 'wallet', 'card',
    'lines', jsonb_build_array(
      jsonb_build_object('name', 'لبن', 'quantity', 2, 'unit', 'علبة', 'price', 60, 'to', 'pantry'),
      jsonb_build_object('name', 'برانش توست', 'quantity', 1, 'price', 30, 'to', 'pantry'),
      jsonb_build_object('name', 'جبنة رومي', 'quantity', 1, 'price', 90, 'to', 'pantry'),
      jsonb_build_object('name', 'بنادول', 'quantity', 2, 'unit', 'علبة', 'to', 'pharmacy'),
      jsonb_build_object('name', 'شنطة', 'to', 'none'),
      jsonb_build_object('name', '   ', 'to', 'pantry'))));

  assert r ->> 'ok' = 'true', 'recorded: ' || r::text;
  assert r ->> 'status' = 'recorded', r::text;
  assert r ->> 'transaction_id' = '11111111-1111-1111-1111-111111111111', 'the purchase id is the expense id';
  assert (r -> 'pantry' ->> 'added')::int = 1, 'cheese is new: ' || r::text;
  assert (r -> 'pantry' ->> 'topped_up')::int = 2, 'milk and toast join the family rows: ' || r::text;
  assert (r -> 'pantry' ->> 'ticked')::int = 1, 'milk leaves the list';
  assert (r -> 'pharmacy' ->> 'restocked')::int = 1, r::text;
  assert (r -> 'prices' ->> 'reported')::int = 2, 'two reports, then the cap stops the rest: ' || r::text;
  assert r -> 'skipped' = '[5]'::jsonb, 'the blank line is skipped, not fatal: ' || r::text;

  -- A replay (the outbox retrying) answers the same and writes nothing.
  r2 := public.zad_record_purchase(jsonb_build_object(
    'id', '11111111-1111-1111-1111-111111111111', 'amount', 250.5, 'title', 'كارفور'));
  assert r2 ->> 'replayed' = 'true', r2::text;
  assert (r2 - 'replayed') = r, 'same answer on replay';
end $$;

reset role;

do $$ begin
  assert (select count(*) from public.zad_transactions) = 1, 'one expense';
  assert (select amount from public.zad_transactions) = 250.5;
  assert (select quantity from public.zad_inventory where item_name = 'اللبن') = 3, 'family milk 1 + 2';
  assert (select count(*) from public.zad_inventory where public.zad_inventory_name_key(item_name) = 'لبن') = 1, 'no second milk row';
  assert (select quantity from public.zad_inventory where item_name = 'توست برانش') = 1, 'reordered words are the same item';
  assert (select family_id from public.zad_inventory where item_name = 'جبنة رومي') = '00000000-0000-0000-0000-0000000000f1';
  assert (select is_purchased from public.zad_shopping_list where item_name = 'لبن');
  assert (select remaining_quantity from public.zad_pharmacy_items where name = 'بنادول') = 2;
  -- Readings go under the row owner (B for the family milk), never with a refused source.
  assert (select user_id from public.zad_inventory_observations where item_name = 'اللبن') = '00000000-0000-0000-0000-00000000000b';
  assert (select qty from public.zad_inventory_observations where item_name = 'اللبن') = 3;
  assert (select count(*) from public.test_recomputes) = 3;
  assert (select price from public.test_price_reports where item = 'لبن') = 30, 'unit price = line price / quantity';
  assert (select count(*) from public.zad_purchases) = 1;
end $$;

set role authenticated;

-- Same amount within ten minutes, no merge, no allow_duplicate: nothing is written.
do $$
declare r jsonb;
begin
  r := public.zad_record_purchase(jsonb_build_object(
    'id', '22222222-2222-2222-2222-222222222222', 'amount', 250.5, 'title', 'كارفور تاني',
    'lines', jsonb_build_array(jsonb_build_object('name', 'عيش', 'to', 'pantry'))));
  assert r ->> 'status' = 'duplicate_suspected', r::text;
  assert r -> 'twin' ->> 'id' = '11111111-1111-1111-1111-111111111111';
  assert not exists (select 1 from public.zad_inventory where item_name = 'عيش'), 'no half purchase';

  -- The customer said «عملية تانية».
  r := public.zad_record_purchase(jsonb_build_object(
    'id', '22222222-2222-2222-2222-222222222222', 'amount', 250.5, 'title', 'كارفور تاني',
    'allow_duplicate', true,
    'lines', jsonb_build_array(jsonb_build_object('name', 'عيش', 'to', 'pantry'))));
  assert r ->> 'status' = 'recorded', r::text;
  assert exists (select 1 from public.zad_inventory where item_name = 'عيش');
end $$;

reset role;

-- The bank already recorded the payment: the receipt merges into it.
insert into public.zad_transactions (id, user_id, amount, title, source_type, created_at) values
  ('33333333-3333-3333-3333-333333333333', '00000000-0000-0000-0000-00000000000a', 99, 'POS 4411', 'notification_listener', now() - interval '2 hours');

set role authenticated;
do $$
declare r jsonb;
begin
  r := public.zad_record_purchase(jsonb_build_object(
    'id', '44444444-4444-4444-4444-444444444444', 'amount', 101, 'title', 'سعودي', 'category', 'بقالة',
    'merchant_name', 'سعودي', 'merge_with', '33333333-3333-3333-3333-333333333333',
    'lines', jsonb_build_array(jsonb_build_object('name', 'رز', 'quantity', 1, 'to', 'pantry'))));
  assert r ->> 'status' = 'merged', r::text;
  assert r ->> 'transaction_id' = '33333333-3333-3333-3333-333333333333';
end $$;
reset role;

do $$ begin
  assert (select amount from public.zad_transactions where id = '33333333-3333-3333-3333-333333333333') = 99, 'the bank keeps its amount';
  assert (select title from public.zad_transactions where id = '33333333-3333-3333-3333-333333333333') = 'سعودي';
  assert not exists (select 1 from public.zad_transactions where id = '44444444-4444-4444-4444-444444444444'), 'no second expense';
end $$;

-- A failure mid-way rolls back the money too: a pharmacy line naming another customer's
-- medicine id by force is not possible, so break the pantry instead.
alter table public.zad_inventory add constraint test_no_poison check (item_name <> 'سم');
set role authenticated;
do $$
declare r jsonb;
begin
  begin
    r := public.zad_record_purchase(jsonb_build_object(
      'id', '55555555-5555-5555-5555-555555555555', 'amount', 17, 'title', 'محل',
      'lines', jsonb_build_array(jsonb_build_object('name', 'سم', 'to', 'pantry'))));
    assert false, 'should have raised';
  exception when check_violation then null;
  end;
end $$;
reset role;
alter table public.zad_inventory drop constraint test_no_poison;
do $$ begin
  assert not exists (select 1 from public.zad_transactions where id = '55555555-5555-5555-5555-555555555555'), 'no money without its lines';
  assert not exists (select 1 from public.zad_purchases where id = '55555555-5555-5555-5555-555555555555');
end $$;

-- Someone else's merge target, a bad input, and a stranger's purchase id.
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000c","role":"authenticated"}', false);
set role authenticated;
do $$
declare r jsonb;
begin
  r := public.zad_record_purchase(jsonb_build_object(
    'id', '66666666-6666-6666-6666-666666666666', 'amount', 5, 'title', 'x',
    'merge_with', '33333333-3333-3333-3333-333333333333'));
  assert r ->> 'reason' = 'merge_target_not_found', r::text;
  r := public.zad_record_purchase(jsonb_build_object('id', 'not-a-uuid', 'amount', 5, 'title', 'x'));
  assert r ->> 'reason' = 'invalid_input', r::text;
  r := public.zad_record_purchase(jsonb_build_object('id', gen_random_uuid(), 'amount', -5, 'title', 'x'));
  assert r ->> 'reason' = 'invalid_input', r::text;
  r := public.zad_record_purchase(jsonb_build_object(
    'id', '11111111-1111-1111-1111-111111111111', 'amount', 5, 'title', 'x'));
  assert r ->> 'reason' = 'id_in_use', 'never another customer''s answer: ' || r::text;

  -- The service door is not open to a customer's session.
  begin
    perform public.zad_record_purchase_service('00000000-0000-0000-0000-00000000000a', '{}'::jsonb);
    assert false, 'service door opened to authenticated';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

-- The service door, as zad-brain calls it.
select set_config('request.jwt.claims', '{"role":"service_role"}', false);
set role service_role;
do $$
declare r jsonb;
begin
  r := public.zad_record_purchase_service('00000000-0000-0000-0000-00000000000c', jsonb_build_object(
    'id', '77777777-7777-7777-7777-777777777777', 'amount', 40, 'title', 'صيدلية', 'source_type', 'telegram',
    'lines', jsonb_build_array(jsonb_build_object('name', 'فيتامين د', 'quantity', 1, 'to', 'pharmacy'))));
  assert r ->> 'status' = 'recorded', r::text;
  assert (r -> 'pharmacy' ->> 'restocked')::int = 1, r::text;
end $$;
reset role;

select 'purchase_door_test: ok' as result;
