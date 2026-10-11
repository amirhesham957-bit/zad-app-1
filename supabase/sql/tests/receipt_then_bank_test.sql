-- A receipt first, then the bank for the same payment (migration 20261010160000). Scratch
-- database only:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/receipt_then_bank_test.sql
--
-- The live function is 13 KB and touches a dozen tables; the migration edits one clause of
-- its transaction-twin lookup. The stand-in below carries that lookup word for word as it
-- stood on 2026-10-10 (pg_get_functiondef, read-only), and returns the twin it finds.

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

create schema if not exists private;
drop table if exists public.zad_transaction_proposals cascade;
drop table if exists public.zad_transactions cascade;
create table public.zad_transactions (
  id uuid primary key default gen_random_uuid(), user_id uuid, amount double precision,
  title text, is_expense boolean default true, txn_kind text default 'expense',
  created_at timestamptz default now(), merchant_name text, source_type text,
  wallet text default 'card');
create table public.zad_transaction_proposals (
  id uuid primary key default gen_random_uuid(), user_id uuid, amount double precision,
  created_at timestamptz, transaction_id uuid);

create or replace function private.zad_resolve_transaction_proposal_impl(p_user uuid, p_proposal uuid, p_decision text, p_channel text)
 returns uuid language plpgsql as $function$
declare
  v_proposal record;
  v_kind text := 'expense';
  v_twin_transaction_id uuid;
  v_twin_title text;
  v_twin_at timestamptz;
begin
  select * into v_proposal from public.zad_transaction_proposals where id = p_proposal;
      select t.id, t.title, t.created_at
        into v_twin_transaction_id, v_twin_title, v_twin_at
        from public.zad_transactions t
       where t.user_id = p_user
         and abs(t.amount - v_proposal.amount) < 0.005
         and coalesce(t.txn_kind, case when t.is_expense then 'expense' else 'income' end) = v_kind
         and t.created_at between v_proposal.created_at - interval '15 minutes'
                              and v_proposal.created_at + interval '15 minutes'
         and not exists (
           select 1 from public.zad_transaction_proposals p2 where p2.transaction_id = t.id
         )
       order by abs(extract(epoch from (t.created_at - v_proposal.created_at)))
       limit 1;
  return v_twin_transaction_id;
end;
$function$;

\ir ../../migrations/20261010160000_receipt_then_bank_is_one_payment.sql

do $$
declare
  u uuid := '00000000-0000-0000-0000-0000000000d1';
  bank_at timestamptz := '2026-10-09 10:00+00';
  receipt uuid;
  typed uuid;
  cash uuid;
  p uuid;
  got uuid;
begin
  -- The receipt (a shop, no channel, a card) saved the evening before the bank's message.
  insert into zad_transactions (user_id, amount, title, merchant_name, created_at)
    values (u, 422.22, 'كارفور', 'كارفور', bank_at - interval '14 hours') returning id into receipt;
  insert into zad_transaction_proposals (user_id, amount, created_at) values (u, 422.22, bank_at) returning id into p;
  got := private.zad_resolve_transaction_proposal_impl(u, p, 'confirm', 'app');
  assert got = receipt, 'the receipt was not found as the twin';

  -- A row typed by hand with no shop, hours away: not a receipt, still the 15-minute rule.
  insert into zad_transactions (user_id, amount, title, created_at)
    values (u, 300, 'قهوة', bank_at - interval '3 hours') returning id into typed;
  insert into zad_transaction_proposals (user_id, amount, created_at) values (u, 300, bank_at) returning id into p;
  assert private.zad_resolve_transaction_proposal_impl(u, p, 'confirm', 'app') is null, 'typed row matched';

  -- A cash receipt is never the bank's payment.
  insert into zad_transactions (user_id, amount, title, merchant_name, wallet, created_at)
    values (u, 150, 'بقالة', 'بقالة', 'cash', bank_at - interval '1 hour') returning id into cash;
  insert into zad_transaction_proposals (user_id, amount, created_at) values (u, 150, bank_at) returning id into p;
  assert private.zad_resolve_transaction_proposal_impl(u, p, 'confirm', 'app') is null, 'cash receipt matched';

  -- Three days apart is two payments.
  insert into zad_transactions (user_id, amount, title, merchant_name, created_at)
    values (u, 99, 'صيدلية', 'صيدلية', bank_at - interval '3 days');
  insert into zad_transaction_proposals (user_id, amount, created_at) values (u, 99, bank_at) returning id into p;
  assert private.zad_resolve_transaction_proposal_impl(u, p, 'confirm', 'app') is null, 'three days matched';

  -- The 15-minute rule still holds for any row.
  insert into zad_transactions (user_id, amount, title, created_at)
    values (u, 75, 'تحويل', bank_at + interval '5 minutes') returning id into typed;
  insert into zad_transaction_proposals (user_id, amount, created_at) values (u, 75, bank_at) returning id into p;
  assert private.zad_resolve_transaction_proposal_impl(u, p, 'confirm', 'app') = typed, '15 minutes broke';
end $$;

select 'receipt_then_bank_test: all passed' as result;
