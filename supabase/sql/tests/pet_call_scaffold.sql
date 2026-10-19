-- The tables zad_enqueue_pet_calls reads, in the shapes it needs (after scratch_scaffold.sql and
-- 20261020090000_companion_care.sql). zad_fcm_tokens comes from scratch_scaffold.sql.

\set ON_ERROR_STOP on

create table if not exists public.agent_tasks (
  id uuid primary key default gen_random_uuid(), user_id uuid, kind text, task_description text,
  scheduled_for timestamptz, status text default 'pending', created_at timestamptz default now());
create table if not exists public.telegram_bindings (
  id uuid primary key default gen_random_uuid(), user_id uuid, chat_id bigint, bound_at timestamptz);
create table if not exists public.zad_product_events (
  id bigint generated always as identity primary key, user_id uuid not null, name text not null,
  at timestamptz not null default now());
