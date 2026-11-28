-- Scratch shape for telegram_notifications_test.sql, after the settings_buttons chain: the two tables the new kinds write
-- (real ones: 20260730150000_telegram_bindings, 20261123060000_notification_events). Never against live.
\set ON_ERROR_STOP on
do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;
create table if not exists public.telegram_bindings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  chat_id bigint,
  binding_code text not null,
  code_expires_at timestamptz not null,
  bound_at timestamptz,
  created_at timestamptz not null default now()
);
create table if not exists public.zad_notification_switches (
  user_id uuid not null references auth.users (id) on delete cascade,
  kind text not null check (kind in ('appointment', 'trip', 'document_due')),
  enabled boolean not null default false,
  enabled_at timestamptz,
  primary key (user_id, kind)
);
