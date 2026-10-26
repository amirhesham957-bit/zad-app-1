-- What 20261027001500_house_learnings.sql reads beyond scratch_scaffold.sql, as live 2026-10-26.
alter table public.zad_users add column if not exists country text;
create table public.zad_transactions (
  id uuid primary key default gen_random_uuid(), user_id uuid, amount double precision, category text,
  is_expense boolean, created_at timestamptz default now()
);
create table public.agent_tasks (
  id uuid primary key default gen_random_uuid(), user_id uuid, kind text, task_description text,
  scheduled_for timestamptz, created_at timestamptz not null default now()
);
create unique index idx_agent_tasks_proactive_dedup
  on public.agent_tasks (user_id, kind, ((created_at at time zone 'UTC')::date))
  where kind in ('spending_ahead', 'med_followup', 'bill_reminder', 'warranty_reminder',
                 'home_weekly_digest', 'listener_gap_alert', 'spend_forecast');
create table public.zad_inventory (user_id uuid, quantity numeric, low_stock_threshold numeric);
create table public.zad_subscriptions (user_id uuid, is_active boolean, renewal_date date, due_day int, billing_cycle text);
create function public.zad_subscription_next_renewal(date, int, text, date) returns date language sql as 'select $1';
create table public.zad_obligations (user_id uuid, active boolean, due_day int);
alter table public.zad_pharmacy_items add column if not exists daily_dose_count int;
create or replace function public.zad_market_timezone(p_country text) returns text language sql immutable as $$
  select case upper(coalesce(p_country, '')) when 'SA' then 'Asia/Riyadh' else 'Africa/Cairo' end $$;
