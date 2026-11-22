-- Scratch shape for member_id_required_test.sql (after the goal-domain chain): zad_item_preferences as live (20261113010000),
-- plus rows that exist BEFORE the migration so the backfill is exercised. Never against live.
\set ON_ERROR_STOP on
create table public.zad_item_preferences (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  family_id uuid,
  item_name text not null, item_key text not null,
  kind text not null check (kind in ('preferred_brand', 'rejected_brand', 'accidental')),
  brand text, created_at timestamptz not null default now());
insert into public.zad_inventory (id, user_id, item_name, quantity) values
  ('e0000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'قديم', 1);
insert into public.agent_goals (user_id, title) values ('11111111-1111-1111-1111-111111111111', 'هدف قديم');
insert into public.zad_item_preferences (user_id, item_name, item_key, kind) values
  ('11111111-1111-1111-1111-111111111111', 'عيش', 'عيش', 'accidental');
