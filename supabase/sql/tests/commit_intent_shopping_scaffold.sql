-- Scratch shape for commit_intent_shopping_test.sql (after commit_intent_scaffold.sql): zad_shopping_list trimmed to the
-- columns the door reads and writes, as on live (quantity integer). Never against live.
\set ON_ERROR_STOP on
create table public.zad_shopping_list (
  id uuid primary key default gen_random_uuid(), user_id uuid not null, item_name text not null, quantity integer default 1,
  is_purchased boolean default false, created_at timestamptz default now(), family_id uuid);
