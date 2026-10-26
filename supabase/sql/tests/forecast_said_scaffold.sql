-- What 20261026223500_forecast_accuracy_said.sql reads beyond forecasts_scaffold.sql, as live 2026-10-26.
alter table public.zad_users add column if not exists country text;
create table public.agent_tasks (
  id uuid primary key default gen_random_uuid(), user_id uuid, kind text, task_description text,
  scheduled_for timestamptz, created_at timestamptz not null default now()
);
create unique index idx_agent_tasks_proactive_dedup
  on public.agent_tasks (user_id, kind, ((created_at at time zone 'UTC')::date))
  where kind in ('spending_ahead', 'med_followup', 'bill_reminder', 'warranty_reminder',
                 'home_weekly_digest', 'listener_gap_alert', 'spend_forecast');
create table public.zad_obligations (user_id uuid, amount numeric, due_day int, active boolean, confirmed boolean);
-- The card's balance; the test sets it per home.
create table test_balance (user_id uuid primary key, balance numeric);
create function public.zad_cash_balance(p uuid) returns numeric language sql stable as
  $$ select balance from public.test_balance where user_id = p $$;
