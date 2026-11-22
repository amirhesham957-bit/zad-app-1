-- Scratch shape for trend_signals_test.sql: the live columns it reads (zad_users.country, family_members). Never against live.
\set ON_ERROR_STOP on
do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;
alter table public.zad_users add column if not exists country text;
create table if not exists public.family_members (id uuid primary key default gen_random_uuid(), family_id uuid, user_id uuid);
