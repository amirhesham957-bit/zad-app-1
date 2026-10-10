-- telegram_pending_writes.wallet (migration 20261010200000). Scratch database only:
--
--   docker run -d --name zadpg -e POSTGRES_PASSWORD=pg postgres:17-alpine
--   psql() { docker exec -i zadpg psql -U postgres -v ON_ERROR_STOP=1 -q; }
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/telegram_pending_wallet_test.sql
--
-- The table is created in its live shape (read 2026-10-10) when the scaffold lacks it. Rolls back.

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
  created_at timestamptz default now(), expires_at timestamptz);
-- A pending write from before the migration.
insert into public.telegram_pending_writes (user_id, chat_id, amount, title) values (gen_random_uuid(), 1, 50, 'قديم');

\i supabase/migrations/20261010200000_telegram_receipt_keeps_how_it_was_paid.sql
\i supabase/migrations/20261010200000_telegram_receipt_keeps_how_it_was_paid.sql

do $$
declare w text;
begin
  if (select wallet from public.telegram_pending_writes where title = 'قديم') is not null then
    raise exception 'an old row got a wallet';
  end if;
  foreach w in array array['cash', 'card', 'bank'] loop
    insert into public.telegram_pending_writes (user_id, chat_id, amount, title, wallet) values (gen_random_uuid(), 1, 50, w, w);
  end loop;
  -- The receipt's own word «wallet» is mapped to bank before the write; the table refuses it.
  foreach w in array array['wallet', 'visa', ''] loop
    begin
      insert into public.telegram_pending_writes (user_id, chat_id, amount, title, wallet) values (gen_random_uuid(), 1, 50, 'x', w);
      raise exception 'accepted wallet %', w;
    exception when check_violation then null;
    end;
  end loop;
  raise notice 'telegram_pending_wallet_test: all passed';
end $$;

rollback;
