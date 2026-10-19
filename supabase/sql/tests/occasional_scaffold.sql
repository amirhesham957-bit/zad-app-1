-- The tables zad_item_is_occasional and _agent_predicted_shortage_for_user read, in their live shapes
-- (after scratch_scaffold.sql; zad_inventory as purchase_door_scaffold.sql read it off the project).

\set ON_ERROR_STOP on

create table public.zad_inventory (
  id uuid primary key default gen_random_uuid(), user_id uuid, item_name text, category text,
  quantity integer default 1, expiry_date text, created_at timestamptz default now(),
  unit text default 'pcs', low_stock_threshold integer default 2,
  family_id uuid references public.family_groups(id) on delete set null);
create table public.zad_inventory_observations (
  id uuid primary key default gen_random_uuid(), user_id uuid not null, item_name text not null,
  qty numeric not null, observed_at timestamptz not null default now(), source text not null,
  created_at timestamptz not null default now());
create table public.zad_consumption (
  user_id uuid, item_name text, avg_daily_qty double precision, rate_known boolean);
create table public.zad_shopping_list (
  id uuid primary key default gen_random_uuid(), user_id uuid, item_name text, is_purchased boolean default false);
create table public.agent_tasks (
  id uuid primary key default gen_random_uuid(), user_id uuid, kind text, task_description text,
  scheduled_for timestamptz, status text default 'pending', created_at timestamptz default now());
create unique index idx_agent_tasks_proactive_dedup
  on public.agent_tasks (user_id, kind, ((created_at at time zone 'UTC')::date))
  where kind in (
    'spending_ahead', 'med_followup', 'bill_reminder',
    'warranty_reminder', 'home_weekly_digest', 'listener_gap_alert',
    'spend_forecast', 'habit_budget', 'predicted_shortage'
  );
