-- telegram_pending_writes.merchant_name / source_type (migration 20261011170000). Scratch only:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/telegram_pending_shop_test.sql
--
-- The table is created in its live shape (2026-10-11, with wallet) when the scaffold lacks it.

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

begin;

create table if not exists public.telegram_pending_writes (
  id uuid primary key default gen_random_uuid(), user_id uuid not null, chat_id bigint not null,
  txn_kind text not null default 'expense', amount double precision not null default 1, title text,
  category text, confidence double precision, status text not null default 'pending'
    check (status in ('pending', 'confirmed', 'cancelled')),
  created_at timestamptz default now(), expires_at timestamptz,
  wallet text check (wallet is null or wallet in ('cash', 'card', 'bank')));
insert into public.telegram_pending_writes (user_id, chat_id, amount, title) values (gen_random_uuid(), 1, 50, 'قديم');

\i supabase/migrations/20261011170000_telegram_receipt_keeps_the_shop.sql
-- Runs twice cleanly.
\i supabase/migrations/20261011170000_telegram_receipt_keeps_the_shop.sql

do $$ begin
  -- the old row is untouched: a text or voice request has neither
  assert (select merchant_name is null and source_type is null from telegram_pending_writes where title = 'قديم');
  -- a receipt request carries both
  insert into telegram_pending_writes (user_id, chat_id, amount, title, merchant_name, source_type)
    values (gen_random_uuid(), 1, 480, 'كارفور', 'كارفور المعادي', 'receipt');
  -- nothing else is a source here, and a name is bounded
  begin
    insert into telegram_pending_writes (user_id, chat_id, amount, source_type) values (gen_random_uuid(), 1, 1, 'bank');
    raise exception 'a source other than receipt was taken';
  exception when check_violation then null; end;
  begin
    insert into telegram_pending_writes (user_id, chat_id, amount, merchant_name) values (gen_random_uuid(), 1, 1, repeat('م', 81));
    raise exception 'an 81-letter shop name was taken';
  exception when check_violation then null; end;
end $$;

rollback;

\echo telegram_pending_shop_test: all checks passed
