-- Scratch shape for commit_intent_test.sql (after events_ledger_scaffold.sql + the M2.1 migration):
-- family_members and zad_inventory trimmed to the columns the door reads and writes. Never against live.
\set ON_ERROR_STOP on
create table public.family_members (family_id uuid, user_id uuid);
create table public.zad_inventory (
  id uuid primary key default gen_random_uuid(), user_id uuid not null, item_name text not null, category text,
  quantity numeric(12,3), expiry_date text, created_at timestamptz default now(), unit text, family_id uuid, opened_at timestamptz,
  restock_mode text);
insert into auth.users values ('33333333-3333-3333-3333-333333333333');
insert into public.zad_users values ('33333333-3333-3333-3333-333333333333', 'جار');
