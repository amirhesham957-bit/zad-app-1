-- On top of scratch_scaffold.sql: the tables zad_view_* read (only the columns they use), plus a stand-in zad_budget_state.
-- The real zad_budget_state is a long chain (single_budget_authority .. early_cycle_threat) that the scratch DB does not carry:
-- the stand-in reads the same tables with the same keys, and the test checks the view passes ITS numbers through unchanged.
-- Scratch only.
\set ON_ERROR_STOP on
do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

alter table public.zad_users add column if not exists country text;
alter table public.zad_users add column if not exists monthly_limit numeric;
alter table public.zad_pharmacy_items add column if not exists for_person text;
create function public.zad_market_timezone(p text) returns text language sql immutable as $$ select 'UTC' $$;
create table public.zad_pharmacy_doses (id uuid primary key default gen_random_uuid(), user_id uuid, item_id uuid, status text, scheduled_at timestamptz);
create table public.zad_household_members (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
  display_name text not null, kind text not null check (kind in ('self', 'adult', 'child', 'elder')), birth_year int,
  linked_user_id uuid references auth.users(id) on delete set null, created_at timestamptz not null default now(),
  archived_at timestamptz, unique (id, user_id));
alter table public.zad_household_members enable row level security;
create policy household_members_read_own on public.zad_household_members for select to authenticated using (user_id = (select auth.uid()));

create table public.zad_transactions (id uuid primary key default gen_random_uuid(), user_id uuid not null, amount double precision not null,
  txn_kind text not null default 'expense', category text, is_expense boolean default true, created_at timestamptz default now());
create table public.zad_inventory (id uuid primary key default gen_random_uuid(), user_id uuid not null, item_name text, quantity numeric,
  low_stock_threshold numeric, expiry_date text, member_id uuid);
create table public.zad_appointments (id uuid primary key default gen_random_uuid(), user_id uuid not null, title text, starts_at timestamptz,
  status text not null default 'upcoming');
create table public.agent_goals (id uuid primary key default gen_random_uuid(), user_id uuid not null, title text, status text not null default 'active', member_id uuid);
create table public.zad_debts (id uuid primary key default gen_random_uuid(), user_id uuid not null, remaining_balance numeric, is_active boolean default true);
create table public.zad_subscriptions (id uuid primary key default gen_random_uuid(), user_id uuid not null, amount double precision, is_active boolean default true);
do $$ declare t text; begin
  foreach t in array array['zad_transactions', 'zad_inventory', 'zad_appointments', 'agent_goals', 'zad_debts', 'zad_subscriptions'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('create policy own_rows on public.%I for select to authenticated using (user_id = (select auth.uid()))', t);
  end loop;
end $$;
alter table public.zad_pharmacy_items drop constraint if exists zad_pharmacy_items_family_member_id_fkey;

create function public.zad_budget_state(p_user uuid, p_tz text default null) returns jsonb language sql stable as $$
  select jsonb_build_object(
    'income', coalesce(sum(amount) filter (where txn_kind = 'income'), 0),
    'spent', coalesce(sum(amount) filter (where txn_kind = 'expense'), 0),
    'balance', coalesce(sum(amount) filter (where txn_kind = 'income'), 0) - coalesce(sum(amount) filter (where txn_kind = 'expense'), 0),
    'available', coalesce(sum(amount) filter (where txn_kind = 'income'), 0) - coalesce(sum(amount) filter (where txn_kind = 'expense'), 0),
    'committed', 0, 'daily_allowance_left', 10, 'threat', 'SAFE')
  from public.zad_transactions where user_id = p_user $$;
