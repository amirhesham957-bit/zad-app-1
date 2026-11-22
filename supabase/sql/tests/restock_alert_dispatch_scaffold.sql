-- Scaffold for restock_alert_dispatch_test.sql, on top of scratch_scaffold.sql. Trimmed to the columns the function reads. Scratch only.
\set ON_ERROR_STOP on
alter table public.zad_users add column country text, add column last_lat double precision, add column last_lon double precision,
  add column last_location_at timestamptz, add column sleep_bed time, add column sleep_wake time;
create function public.zad_market_timezone(p_country text) returns text language sql immutable as $$ select 'Africa/Cairo' $$;
create table public.zad_inventory (id uuid primary key default gen_random_uuid(), user_id uuid, item_name text, quantity numeric, low_stock_threshold integer);
create table public.zad_shopping_list (id uuid primary key default gen_random_uuid(), user_id uuid, item_name text, is_purchased boolean default false);
create table public.zad_memory (id uuid primary key default gen_random_uuid(), user_id uuid, subject_kind text, suppress_until timestamptz);
create table public.zad_broke_mode (user_id uuid primary key, ends_at timestamptz, ended_at timestamptz);
