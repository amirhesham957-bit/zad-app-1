-- Scratch shape for 20261113140000_silent_accounts_quiet.sql: just the columns it reads.
\set ON_ERROR_STOP on
do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;
do $$ begin
  create role anon nologin; create role authenticated nologin; create role service_role nologin bypassrls;
exception when duplicate_object then null; end $$;
create table zad_users (id uuid primary key, created_at timestamptz not null default now());
create table zad_brain_runs (user_id uuid, trigger text);
create table zad_chat_turns (user_id uuid, role text, created_at timestamptz default now());
create table telegram_checkin_prompts (user_id uuid, answered_at timestamptz);
create table zad_transactions (user_id uuid, created_at timestamptz default now());
create table zad_inventory (user_id uuid, created_at timestamptz default now());
create table zad_pharmacy_items (user_id uuid, created_at timestamptz default now());
create table zad_appointments (user_id uuid);
create table zad_shopping_list (user_id uuid);
create table zad_obligations (user_id uuid);
create table zad_subscriptions (user_id uuid);
create table family_members (family_id uuid, user_id uuid);
create table zad_notification_ingest_events (user_id uuid, created_at timestamptz default now());
create table agent_actions (user_id uuid, created_at timestamptz default now());
create table zad_fcm_tokens (user_id uuid, updated_at timestamptz default now());
