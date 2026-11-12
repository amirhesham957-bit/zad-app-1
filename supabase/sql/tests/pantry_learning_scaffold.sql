-- What 20261112230000_pantry_learning_on_server.sql reads beyond scratch_scaffold.sql, as live 2026-11-12.
alter table public.zad_users add column country text;
create or replace function public.zad_market_timezone(p_country text) returns text language sql immutable as $$
  select case upper(coalesce(p_country, '')) when 'SA' then 'Asia/Riyadh' else 'Africa/Cairo' end $$;
create table public.zad_inventory (
  id uuid primary key default gen_random_uuid(), user_id uuid, item_name text not null, category text,
  quantity numeric default 0, expiry_date text, created_at timestamptz default now(), unit text,
  low_stock_threshold numeric, family_id uuid, restock_mode text, restock_cycle_days integer);
create table public.zad_consumption (
  user_id uuid not null, item_name text not null, avg_daily_qty double precision, sample_count integer,
  rate_known boolean, last_computed_at timestamptz, primary key (user_id, item_name));
create table public.zad_inventory_observations (
  id uuid primary key default gen_random_uuid(), user_id uuid not null, item_name text not null,
  qty numeric not null, observed_at timestamptz not null default now(), source text, created_at timestamptz default now());
create schema if not exists private;
-- No product pairs in these tests: the name is its own canonical.
create function private.zad_product_canonical_for(p_user uuid, p_name text) returns text language sql stable as $$ select p_name $$;
create function public.zad_record_observation(p_user uuid, p_item text, p_qty numeric, p_source text) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  insert into public.zad_inventory_observations (user_id, item_name, qty, source) values (p_user, p_item, p_qty, p_source);
  return '{}'::jsonb;
end $$;
