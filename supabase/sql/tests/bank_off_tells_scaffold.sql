-- Tables bank_off_tells_test.sql needs, in their live shape (7/11).
create table if not exists public.zad_product_events (id bigserial primary key, user_id uuid, name text not null, at timestamptz not null default now());
create table if not exists public.agent_tasks (
  id uuid primary key default gen_random_uuid(), user_id uuid, kind text, task_description text,
  scheduled_for timestamptz, status text default 'pending', created_at timestamptz not null default now()
);
create unique index if not exists idx_agent_tasks_proactive_dedup on public.agent_tasks
  (user_id, kind, ((created_at at time zone 'UTC')::date))
  where kind in ('spending_ahead','med_followup','bill_reminder','warranty_reminder','home_weekly_digest','listener_gap_alert','spend_forecast','habit_budget','predicted_shortage');
