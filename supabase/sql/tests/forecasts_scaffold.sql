-- What 20261026214500_forecast_ledger.sql reads that scratch_scaffold.sql lacks, as live 2026-10-26.
create table public.user_behavior_profile (
  user_id uuid primary key, avg_weekly_spending numeric, last_updated_at timestamptz
);
create table public.zad_transactions (
  id uuid primary key default gen_random_uuid(), user_id uuid, amount double precision,
  is_expense boolean, created_at timestamptz default now()
);
