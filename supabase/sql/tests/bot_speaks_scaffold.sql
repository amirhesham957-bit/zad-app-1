-- Scaffold for bot_speaks_with_notifications_test.sql, on top of scratch_scaffold.sql. Scratch only.
-- net.http_post here records the call (url + body) instead of sending it.
\set ON_ERROR_STOP on
do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

create schema net;
create table net.calls (id bigint generated always as identity primary key, url text, body jsonb);
create function net.http_post(url text, headers jsonb, body jsonb, timeout_milliseconds int)
returns bigint language plpgsql as $$
declare r bigint;
begin
  insert into net.calls (url, body) values (url, body) returning id into r;
  return r;
end $$;
create function public.zad_cron_secret(p_name text) returns text language sql as $$ select 's' $$;
create table public.telegram_bindings (user_id uuid, chat_id bigint, bound_at timestamptz);
