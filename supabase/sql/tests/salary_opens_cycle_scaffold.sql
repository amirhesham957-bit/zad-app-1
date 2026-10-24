-- Tables the salary migration (20261025001500) reads, in the shape the live schema has them, on top of
-- scratch_scaffold.sql. Only the columns it touches.
alter table public.zad_users add column if not exists country text,
  add column if not exists cycle_start_day int, add column if not exists cycle_anchor text default 'day_of_month';
create or replace function public.zad_market_timezone(p_country text) returns text language sql as $$
  select case p_country when 'SA' then 'Asia/Riyadh' else 'Africa/Cairo' end $$;
create table public.zad_transactions (id uuid primary key default gen_random_uuid(), user_id uuid, amount numeric,
  txn_kind text, source_type text, currency text, created_at timestamptz default now());
create table public.zad_inventory (id uuid primary key default gen_random_uuid(), user_id uuid, item_name text, quantity numeric);
create table public.zad_consumption (user_id uuid, item_name text, avg_daily_qty numeric, rate_known boolean);
create table public.zad_voice_moments (id uuid primary key default gen_random_uuid(), user_id uuid, moment text, facts jsonb,
  dedupe_key text, status text default 'pending', created_at timestamptz default now(), unique (user_id, dedupe_key));
