-- باب شرا واحد: وضع «أصناف بس» (migration 20261019220000). Run after both scaffolds and the
-- three purchase-door migrations (CI: job sql-tests).

\set ON_ERROR_STOP on

insert into auth.users values ('00000000-0000-0000-0000-00000000000a');

select set_config('request.jwt.claims', '{"role":"service_role"}', false);
set role service_role;
do $$
declare r jsonb;
begin
  -- «المخزن بس»: no amount, the lines go in, no expense.
  r := public.zad_record_purchase_service('00000000-0000-0000-0000-00000000000a', jsonb_build_object(
    'id', '31111111-1111-1111-1111-111111111111', 'title', 'كارفور', 'source_type', 'telegram',
    'lines', jsonb_build_array(
      jsonb_build_object('name', 'لبن', 'quantity', 2, 'to', 'pantry'),
      jsonb_build_object('name', 'بنادول', 'quantity', 1, 'to', 'pharmacy'))));
  assert r ->> 'ok' = 'true', r::text;
  assert r ->> 'status' = 'lines_only', r::text;
  assert r -> 'transaction_id' = 'null'::jsonb, 'no expense: ' || r::text;
  assert (r -> 'pantry' ->> 'added')::int = 1, r::text;
  assert (r -> 'pharmacy' ->> 'restocked')::int = 1, r::text;

  -- The replay answers the same and writes nothing.
  r := public.zad_record_purchase_service('00000000-0000-0000-0000-00000000000a', jsonb_build_object(
    'id', '31111111-1111-1111-1111-111111111111', 'title', 'كارفور',
    'lines', jsonb_build_array(jsonb_build_object('name', 'لبن', 'quantity', 2, 'to', 'pantry'))));
  assert r ->> 'replayed' = 'true', r::text;

  -- No amount and no lines is nothing to record; no amount with a merge is a contradiction.
  r := public.zad_record_purchase_service('00000000-0000-0000-0000-00000000000a', jsonb_build_object(
    'id', gen_random_uuid(), 'title', 'x'));
  assert r ->> 'reason' = 'invalid_input', r::text;
  r := public.zad_record_purchase_service('00000000-0000-0000-0000-00000000000a', jsonb_build_object(
    'id', gen_random_uuid(), 'title', 'x', 'merge_with', gen_random_uuid(),
    'lines', jsonb_build_array(jsonb_build_object('name', 'عيش', 'to', 'pantry'))));
  assert r ->> 'reason' = 'invalid_input', r::text;
  -- An amount that is there must still be real.
  r := public.zad_record_purchase_service('00000000-0000-0000-0000-00000000000a', jsonb_build_object(
    'id', gen_random_uuid(), 'title', 'x', 'amount', 0,
    'lines', jsonb_build_array(jsonb_build_object('name', 'عيش', 'to', 'pantry'))));
  assert r ->> 'reason' = 'invalid_input', r::text;

  -- With an amount it is still a whole purchase.
  r := public.zad_record_purchase_service('00000000-0000-0000-0000-00000000000a', jsonb_build_object(
    'id', '31111111-1111-1111-1111-111111111112', 'title', 'كارفور', 'amount', 50,
    'lines', jsonb_build_array(jsonb_build_object('name', 'عيش', 'to', 'pantry'))));
  assert r ->> 'status' = 'recorded', r::text;
end $$;
reset role;

do $$ begin
  assert (select count(*) from public.zad_transactions) = 1, 'only the purchase with an amount has an expense';
  assert (select transaction_id from public.zad_purchases where id = '31111111-1111-1111-1111-111111111111') is null;
end $$;

-- The bot's pending row: lines without a read amount, but never neither.
insert into public.telegram_pending_writes (user_id, chat_id, txn_kind, amount, title, purchase_lines)
values ('00000000-0000-0000-0000-00000000000a', 1, 'expense', null, 'كارفور', '[{"name":"لبن","to":"pantry"}]');
do $$ begin
  begin
    insert into public.telegram_pending_writes (user_id, chat_id, txn_kind, amount, title)
    values ('00000000-0000-0000-0000-00000000000a', 1, 'expense', null, 'x');
    assert false, 'a pending row with neither amount nor lines';
  exception when check_violation then null;
  end;
end $$;

select 'purchase_lines_only_test: ok' as result;
