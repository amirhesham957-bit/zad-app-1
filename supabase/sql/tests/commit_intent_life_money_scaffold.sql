-- Scratch shape for commit_intent_life_money_test.sql (after commit_intent_scaffold.sql): zad_subscriptions, zad_debts and
-- zad_obligations with live's columns and CHECKs (read from information_schema/pg_constraint 2026-11-21; live's
-- subscriptions table has no CHECKs, and the bills-to-obligations/trash/home-state triggers are left out). Never against live.
\set ON_ERROR_STOP on
create table public.zad_subscriptions (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
  title text not null, amount double precision not null, renewal_date text, category text, created_at timestamptz default now(),
  is_active boolean not null default true, billing_cycle text default 'MONTHLY', due_day integer,
  auto_deduct boolean not null default false, type text not null default 'subscription', provider text,
  source text not null default 'user');
create table public.zad_debts (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
  family_id uuid, name text not null, principal_amount numeric not null default 0, remaining_balance numeric not null default 0,
  interest_rate numeric not null default 0, minimum_payment numeric not null default 0, due_day integer,
  is_active boolean not null default true, created_at timestamptz default now());
create table public.zad_obligations (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
  title text not null, amount numeric not null check (amount > 0),
  kind text not null check (kind in ('rent', 'installment', 'debt', 'tuition', 'utility', 'other')),
  due_day integer check (due_day >= 1 and due_day <= 31), due_date date,
  recurrence text not null default 'monthly' check (recurrence in ('monthly', 'quarterly', 'yearly', 'once')),
  auto_detected boolean not null default false, confirmed boolean not null default false, active boolean not null default true,
  created_at timestamptz not null default now(), provider text, total_installments integer, remaining_installments integer);
