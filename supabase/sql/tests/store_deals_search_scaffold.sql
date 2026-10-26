-- What 20261026013500_store_deals_search.sql reads beyond deals_scaffold.sql, as live 2026-10-26:
-- zad_transactions with the columns zad_deal_search_targets filters on.
create table if not exists public.zad_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid,
  amount numeric,
  currency text,
  merchant_name text,
  is_expense boolean,
  txn_kind text,
  transfer_to text,
  created_at timestamptz not null default now()
);
