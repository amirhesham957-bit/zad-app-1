-- Scratch shape for net_calls_never_block_writes_test.sql: just enough of the live
-- tables (2026-11-13) for the two triggers to fire, and a net.http_post that always
-- throws — what a write sees while pg_net is down or being moved to `extensions`.
\set ON_ERROR_STOP on
do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

create schema net;
create table net.calls (url text);
-- Records the attempt, then fails. The record rolls back with the failure, so the
-- test counts attempts through a sequence (sequences don't roll back).
create sequence net.attempts;
create function net.http_post(url text, headers jsonb, body jsonb, timeout_milliseconds int)
returns bigint language plpgsql as $$
begin
  perform nextval('net.attempts');
  raise exception 'pg_net is down';
end $$;

create function public.zad_cron_secret(p_name text) returns text language sql as $$ select 's' $$;

create table public.telegram_bindings (user_id uuid, bound_at timestamptz);
create table public.zad_consumption (user_id uuid, item_name text, avg_daily_qty numeric, rate_known boolean);
create function public._inventory_needs_checkin(q numeric, t numeric, a numeric, k boolean)
returns boolean language sql as $$ select q <= coalesce(t, 1) $$;

create table public.zad_inventory (
  user_id uuid, item_name text, quantity numeric, low_stock_threshold numeric
);
create table public.zad_insights (
  user_id uuid, kind text, priority text, status text, title text, body text
);

-- Bodies are replaced by the migration; the triggers are what the live tables carry.
create function public.notify_telegram_on_low_stock() returns trigger language plpgsql as $$ begin return NEW; end $$;
create function public.notify_telegram_on_insight() returns trigger language plpgsql as $$ begin return NEW; end $$;
create trigger trigger_notify_telegram_on_low_stock after update on public.zad_inventory
  for each row execute function public.notify_telegram_on_low_stock();
create trigger trigger_notify_telegram_on_insight after insert on public.zad_insights
  for each row execute function public.notify_telegram_on_insight();
