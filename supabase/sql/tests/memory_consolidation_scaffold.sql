-- The live shape (migration 20260907090000_chat_turns.sql) that
-- 20261003130000_memory_nightly_consolidation.sql reads, for a scratch database
-- already set up by scratch_scaffold.sql. Run in this order:
--
--   docker run -d --name zadpg -e POSTGRES_PASSWORD=pg postgres:17-alpine
--   psql() { docker exec -i zadpg psql -U postgres -v ON_ERROR_STOP=1 -q; }
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/memory_consolidation_scaffold.sql
--   psql < supabase/migrations/20261003130000_memory_nightly_consolidation.sql
--   psql < supabase/sql/tests/memory_consolidation_test.sql

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

create table if not exists public.zad_chat_turns (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('user', 'assistant')),
  text text not null check (char_length(text) <= 4000),
  created_at timestamptz not null default now()
);
