-- On top of scratch_scaffold.sql: the live columns 20261012030000_companion.sql reads.
--
--   psql() { docker exec -i zadpg psql -U postgres -v ON_ERROR_STOP=1 -q; }
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/companion_scaffold.sql
--   psql < supabase/migrations/20261012030000_companion.sql
--   psql < supabase/sql/tests/companion_test.sql

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

alter table auth.users add column if not exists created_at timestamptz default now();
alter table public.zad_users add column if not exists country text;
create table if not exists public.zad_transactions (
  id uuid primary key default gen_random_uuid(), user_id uuid, amount numeric, source_type text,
  created_at timestamptz default now());
create table if not exists public.zad_inventory (
  id uuid primary key default gen_random_uuid(), user_id uuid, item_name text, quantity numeric default 1);
create table if not exists public.zad_shopping_list (
  id uuid primary key default gen_random_uuid(), user_id uuid, item_name text);
create table if not exists public.zad_entitlements (
  user_id uuid primary key, tier text not null default 'free', tier_expires_at timestamptz);
alter table public.zad_transactions enable row level security;
create policy own_txn on public.zad_transactions for all using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
alter table public.zad_inventory enable row level security;
create policy own_inv on public.zad_inventory for all using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
grant select, insert, update, delete on public.zad_transactions, public.zad_inventory, public.zad_shopping_list to authenticated;

create or replace function public.zad_market_timezone(p_country text)
returns text language sql immutable set search_path = public as $$
  select case upper(coalesce(p_country, '')) when 'SA' then 'Asia/Riyadh' when 'EG' then 'Africa/Cairo' else 'UTC' end $$;
