-- On top of the pet-call chain (scratch_scaffold, companion_care, pet_call_scaffold, 20261020100000,
-- 20261108150000) and guardian_outcomes_scaffold + 20261011230000: what 20261011240000 and
-- 20261113090000 need besides that.

\set ON_ERROR_STOP on

alter table public.zad_users add column if not exists pet_calls_enabled boolean not null default true;
alter table public.agent_tasks add column if not exists updated_at timestamptz;
alter table public.agent_tasks add column if not exists result text;
create table if not exists public.dashboard_admins (user_id uuid primary key);
create or replace function public.is_dashboard_admin() returns boolean language sql stable security definer
  set search_path = public as $$ select exists (select 1 from public.dashboard_admins where user_id = auth.uid()) $$;
create table if not exists public.zad_brain_health_alerts (
  alert_date date, kind text, total_runs int, bad_runs int, bad_pct int, top_error text,
  created_at timestamptz default now(), primary key (alert_date, kind));
