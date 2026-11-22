-- Scratch shape for undo_every_table_test.sql: roles, auth.uid(), agent_actions, zad_trash and the
-- tables the test undoes (live column shapes trimmed to what the undo reads). Never against live.
\set ON_ERROR_STOP on
do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;
do $$ begin
  create role anon nologin; create role authenticated nologin; create role service_role nologin bypassrls;
exception when duplicate_object then null; end $$;
create schema if not exists auth;
create or replace function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claims', true)::jsonb ->> 'sub', '')::uuid $$;

create table public.family_members (family_id uuid, user_id uuid);
create table public.agent_actions (
  id uuid primary key default gen_random_uuid(), user_id uuid not null, tool_name text, target_table text,
  target_id uuid, previous_state jsonb, new_state jsonb, status text not null default 'applied',
  created_at timestamptz default now(), undone_at timestamptz, seq bigserial);
create table public.zad_trash (
  id bigserial primary key, table_name text, row_id uuid, user_id uuid, row_data jsonb,
  deleted_at timestamptz default now(), restored_at timestamptz);
create table public.zad_users (id uuid primary key, name text);
create table public.zad_subscriptions (id uuid primary key, user_id uuid not null, name text, amount numeric);
create table public.zad_obligations (id uuid primary key, user_id uuid not null, title text, active boolean default true);
create table public.zad_memory (id uuid primary key, user_id uuid not null, family_id uuid, content text);
create table public.zad_transactions (id uuid primary key, user_id uuid not null, amount numeric);
create table public.zad_inventory (id uuid primary key, user_id uuid not null, family_id uuid, name text);
create table public.zad_shopping_list (id uuid primary key, user_id uuid not null, family_id uuid, name text);
create table public.zad_pharmacy_items (id uuid primary key, user_id uuid not null);
create table public.zad_pharmacy_doses (id uuid primary key, user_id uuid not null);
create table public.zad_debts (id uuid primary key, user_id uuid not null);
create table public.zad_maintenance_items (id uuid primary key, user_id uuid not null);
create table public.zad_documents (id uuid primary key, user_id uuid not null);
create table public.zad_appointments (id uuid primary key, user_id uuid not null);
create table public.zad_category_budgets (id uuid primary key, user_id uuid not null);
