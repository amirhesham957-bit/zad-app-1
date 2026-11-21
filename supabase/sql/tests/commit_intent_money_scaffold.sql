-- Scratch shape for commit_intent_money_test.sql (after the pharmacy scaffold): zad_transactions with live's CHECKs, and a
-- stand-in zad_record_purchase_service with its live reply shape (ok + transaction_id, or status duplicate_suspected + twin,
-- or ok false + reason). Never against live.
\set ON_ERROR_STOP on
create table public.zad_transactions (
  id uuid primary key default gen_random_uuid(), user_id uuid not null, amount double precision not null, title text not null,
  category text, is_expense boolean default true, created_at timestamptz default now(), wallet text not null default 'card',
  txn_kind text not null default 'expense', transfer_to text, merchant_name text, source_type text,
  counts_toward_budget boolean default true, for_person text,
  check ((txn_kind = 'transfer' and transfer_to is not null) or (txn_kind <> 'transfer' and transfer_to is null)),
  check (for_person is null or char_length(btrim(for_person)) between 1 and 40),
  check (transfer_to is null or transfer_to in ('cash', 'card', 'bank')),
  check (txn_kind in ('expense', 'income', 'transfer')),
  check (wallet in ('cash', 'card', 'bank')));
create or replace function public.zad_record_purchase_service(p_user uuid, p_purchase jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_twin public.zad_transactions%rowtype;
begin
  if jsonb_array_length(coalesce(p_purchase -> 'lines', '[]'::jsonb)) = 0 then
    return jsonb_build_object('ok', false, 'reason', 'no_lines');
  end if;
  select * into v_twin from public.zad_transactions where user_id = p_user and amount = (p_purchase ->> 'amount')::numeric
    and created_at > now() - interval '10 minutes' limit 1;
  if found and coalesce((p_purchase ->> 'allow_duplicate')::boolean, false) is not true then
    return jsonb_build_object('ok', false, 'status', 'duplicate_suspected', 'twin', jsonb_build_object('title', v_twin.title, 'created_at', v_twin.created_at));
  end if;
  insert into public.zad_transactions (user_id, amount, title, txn_kind, is_expense)
  values (p_user, (p_purchase ->> 'amount')::numeric, p_purchase ->> 'title', 'expense', true) returning id into v_id;
  return jsonb_build_object('ok', true, 'transaction_id', v_id, 'pantry', jsonb_build_object('added', jsonb_array_length(p_purchase -> 'lines')));
end $$;
