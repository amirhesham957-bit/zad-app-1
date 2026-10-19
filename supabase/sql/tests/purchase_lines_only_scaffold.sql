-- Scratch scaffold for purchase_lines_only_test.sql (migration 20261019220000), run after
-- purchase_door_scaffold.sql. telegram_pending_writes as its migrations leave it before
-- 20261019220000 (20260731120000 + wallet, merchant_name, source_type).

\set ON_ERROR_STOP on

create table if not exists public.telegram_pending_writes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  chat_id bigint not null,
  txn_kind text not null check (txn_kind in ('expense', 'income')),
  amount double precision not null check (amount > 0),
  title text not null, category text, confidence real,
  status text not null default 'pending' check (status in ('pending', 'confirmed', 'cancelled')),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '30 minutes',
  wallet text, merchant_name text, source_type text);
