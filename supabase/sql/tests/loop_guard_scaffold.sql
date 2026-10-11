-- On top of household_shopping_scaffold.sql + 20261011140000 + product_identity_scaffold.sql
-- + 20261011200000: the other tables zad_loop_guard reads, in their live columns.
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/household_shopping_scaffold.sql
--   psql < supabase/migrations/20261011140000_one_household_shopping_list.sql
--   psql < supabase/sql/tests/product_identity_scaffold.sql
--   psql < supabase/migrations/20261011200000_product_identity.sql
--   psql < supabase/sql/tests/loop_guard_scaffold.sql
--   psql < supabase/migrations/20261011220000_loop_guard.sql
--   psql < supabase/sql/tests/loop_guard_test.sql

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

create table if not exists public.zad_transactions (id uuid primary key default gen_random_uuid(), user_id uuid);
alter table public.zad_transactions add column if not exists source_type text;
alter table public.zad_transactions add column if not exists merchant_name text;
alter table public.zad_transactions add column if not exists created_at timestamptz default now();
create table if not exists public.zad_voice_moments (
  id uuid primary key default gen_random_uuid(), user_id uuid, moment text, status text, error text,
  created_at timestamptz default now());
create table if not exists public.agent_tasks (
  id uuid primary key default gen_random_uuid(), user_id uuid, kind text, task_description text,
  scheduled_for timestamptz, status text default 'pending', created_at timestamptz default now());
create table if not exists public.zad_fcm_tokens (id uuid primary key default gen_random_uuid(), user_id uuid, token text);
create table if not exists public.telegram_bindings (id uuid primary key default gen_random_uuid(), user_id uuid, chat_id bigint, bound_at timestamptz);
create table if not exists public.app_notifications (
  id uuid primary key default gen_random_uuid(), user_id uuid, title text, message text,
  is_read boolean default false, created_at timestamptz default now());
create table if not exists public.zad_brain_health_alerts (
  alert_date date, kind text, total_runs int, bad_runs int, bad_pct int, top_error text,
  created_at timestamptz default now(), primary key (alert_date, kind));
insert into public.zad_users (id, currency) values
  ('00000000-0000-0000-0000-00000000f001', 'EGP'), ('00000000-0000-0000-0000-00000000f002', 'EGP')
  on conflict (id) do update set currency = excluded.currency;
