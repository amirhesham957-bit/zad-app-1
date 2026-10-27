-- What 20261027070000_habit_trials.sql reads beyond scratch_scaffold.sql, as live 2026-10-27.
alter table public.zad_users add column if not exists country text;
create table public.zad_transactions (
  id uuid primary key default gen_random_uuid(), user_id uuid, amount double precision, category text,
  is_expense boolean, created_at timestamptz default now()
);
create table public.agent_tasks (
  id uuid primary key default gen_random_uuid(), user_id uuid, kind text, task_description text,
  scheduled_for timestamptz, created_at timestamptz not null default now()
);
create table if not exists public.telegram_bindings (
  id uuid primary key default gen_random_uuid(), user_id uuid, chat_id bigint, bound_at timestamptz
);
create table public.zad_memory (
  id uuid primary key default gen_random_uuid(), user_id uuid not null, scope text not null default 'general',
  note text not null, confidence real not null default 0.5, evidence_count int not null default 1,
  superseded_by uuid, created_at timestamptz not null default now()
);
create or replace function public.zad_market_timezone(p_country text) returns text language sql immutable as $$
  select case upper(coalesce(p_country, '')) when 'SA' then 'Asia/Riyadh' else 'Africa/Cairo' end $$;
