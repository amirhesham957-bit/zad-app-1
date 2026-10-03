-- The live shapes (read off the project 2026-10-03) of the memory tables that
-- migration 20261003100000_memory_entities_and_time.sql changes, for a scratch
-- database already set up by scratch_scaffold.sql. The memory functions are
-- their live bodies of that day in short form: the migration replaces each of
-- them, so only their signatures and grants matter here.
--
-- Needs pgvector — use the pgvector image instead of plain postgres:
--   docker run -d --name zadpg -e POSTGRES_PASSWORD=pg pgvector/pgvector:pg17
--   psql() { docker exec -i zadpg psql -U postgres -v ON_ERROR_STOP=1 -q; }
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/memory_scaffold.sql
--   psql < supabase/migrations/20261003100000_memory_entities_and_time.sql
--   psql < supabase/sql/tests/memory_time_entities_test.sql

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

create extension if not exists pg_trgm;
create extension if not exists vector;
create table if not exists public.family_groups (id uuid primary key default gen_random_uuid());

create table public.zad_memory (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  scope text not null default 'general',
  note text not null,
  confidence real not null default 0.5,
  evidence_count int not null default 1,
  last_seen timestamptz not null default now(),
  created_at timestamptz not null default now(),
  embedding vector(768),
  family_id uuid references public.family_groups(id) on delete set null,
  subject_kind text,
  suppress_until timestamptz
);
create index idx_zad_memory_note_trgm on public.zad_memory using gin (note gin_trgm_ops);
create index idx_zad_memory_user_scope on public.zad_memory (user_id, scope);
alter table public.zad_memory enable row level security;
create policy user_own_memory on public.zad_memory for all
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
grant select, insert, update, delete on public.zad_memory to authenticated;

create table public.zad_memory_links (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  from_id uuid not null references public.zad_memory(id) on delete cascade,
  to_id uuid not null references public.zad_memory(id) on delete cascade,
  relation text not null check (relation in ('leads_to', 'co_occurs', 'explains', 'contradicts')),
  strength real not null default 0.5,
  evidence_count integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint zad_memory_links_no_self check (from_id <> to_id),
  constraint zad_memory_links_unique unique (user_id, from_id, to_id, relation)
);
alter table public.zad_memory_links enable row level security;

create function public.zad_text_has_negation(t text) returns boolean
language sql immutable parallel safe set search_path to 'public', 'pg_temp' as $$
  select coalesce(t, '') ~ (
    '(^|\s)(مش|مِش|مو|مب|ليس|لا|أبدا|أبداً|ابدا|بطل|بطّل|وقف|وقّف|خلاص)($|\s)'
    || '|(^|\s)ما\S*ش($|\s)'
    || '|(^|\s)(not|no|never|stopped|doesn''t|don''t|isn''t|won''t)($|\s)');
$$;

-- Live signatures and grants the migration replaces.
create function public.zad_memory_upsert(p_user uuid, p_scope text, p_note text, p_conf real default 0.5, p_family_id uuid default null)
returns text language plpgsql security definer as $$ begin return 'live-before-20261003100000'; end $$;
revoke execute on function public.zad_memory_upsert(uuid, text, text, real, uuid) from public;
grant execute on function public.zad_memory_upsert(uuid, text, text, real, uuid) to authenticated, service_role;
create function public.zad_memory_conflict(p_user uuid, p_scope text, p_note text)
returns jsonb language sql stable security definer as $$ select null::jsonb $$;
create function public.zad_memory_resolve_conflict(p_user uuid, p_old_id uuid, p_scope text, p_note text, p_conf real default 0.6)
returns jsonb language plpgsql security definer as $$ begin return null; end $$;
revoke execute on function public.zad_memory_conflict(uuid, text, text) from public, anon, authenticated;
revoke execute on function public.zad_memory_resolve_conflict(uuid, uuid, text, text, real) from public, anon, authenticated;
grant execute on function public.zad_memory_conflict(uuid, text, text) to service_role;
grant execute on function public.zad_memory_resolve_conflict(uuid, uuid, text, text, real) to service_role;

-- A note written before the migration: valid_from must come back as its created_at.
insert into auth.users values ('00000000-0000-0000-0000-0000000000a1') on conflict do nothing;
insert into public.zad_memory (user_id, note, created_at)
values ('00000000-0000-0000-0000-0000000000a1', 'ملاحظة قديمة من الشهر اللي فات', now() - interval '30 days');
