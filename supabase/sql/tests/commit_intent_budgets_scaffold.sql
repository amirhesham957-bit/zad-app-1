-- Scratch shape for commit_intent_budgets_test.sql (after the money scaffold): zad_users' balance columns and
-- zad_category_budgets with live's constraints. Never against live.
\set ON_ERROR_STOP on
alter table public.zad_users add column monthly_limit numeric, add column limit_confirmed_at timestamptz;
create table public.zad_category_budgets (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
  category text not null check (char_length(category) between 1 and 60), amount numeric not null check (amount > 0),
  updated_at timestamptz not null default now(), unique (user_id, category));
