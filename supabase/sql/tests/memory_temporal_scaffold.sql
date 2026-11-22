-- zad_memory وجيرانها زي الحي (اتقروا من information_schema وpg_constraint ٢٢/١١)، من غير pgvector وembedding.
-- بعد scratch_scaffold.sql. للتست memory_temporal_test.sql (م٩.١ وم٩.٢).

\set ON_ERROR_STOP on

insert into auth.users (id) values
  ('00000000-0000-0000-0000-0000000000a1'), ('00000000-0000-0000-0000-0000000000b1');

create table public.zad_household_members (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  display_name text not null check (length(btrim(display_name)) between 1 and 60),
  kind text not null check (kind in ('self', 'adult', 'child', 'elder')),
  birth_year int, linked_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(), archived_at timestamptz,
  unique (id, user_id)
);

create table public.zad_memory (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  scope text not null default 'general', note text not null,
  confidence real not null default 0.5, evidence_count integer not null default 1,
  last_seen timestamptz not null default now(), created_at timestamptz not null default now(),
  family_id uuid, subject_kind text, suppress_until timestamptz,
  valid_from timestamptz not null default now(), valid_until timestamptz,
  superseded_by uuid references public.zad_memory(id) on delete set null,
  occasion text, occasion_md text, occasion_for text,
  constraint zad_memory_not_superseded_by_self check (superseded_by is null or superseded_by <> id),
  constraint zad_memory_valid_range check (valid_until is null or valid_until >= valid_from)
);

create table public.zad_memory_entities (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  kind text not null, name text not null, name_key text not null,
  created_at timestamptz not null default now(), last_seen timestamptz not null default now(),
  unique (user_id, kind, name_key)
);

create table public.zad_memory_mentions (
  memory_id uuid not null references public.zad_memory(id) on delete cascade,
  entity_id uuid not null references public.zad_memory_entities(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (memory_id, entity_id)
);

create table public.zad_memory_links (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  from_id uuid not null references public.zad_memory(id) on delete cascade,
  to_id uuid not null references public.zad_memory(id) on delete cascade,
  relation text not null check (relation in ('leads_to', 'co_occurs', 'explains', 'contradicts')),
  strength real not null default 0.5 check (strength >= 0 and strength <= 1),
  evidence_count integer not null default 1,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  constraint zad_memory_links_no_self check (from_id <> to_id),
  constraint zad_memory_links_unique unique (user_id, from_id, to_id, relation)
);

-- النسخ اللي المايجريشن بتعمل لها drop وcreate، بالتوقيع القديم.
create function public.zad_memory_live_notes(p_user uuid, p_limit integer default 20)
returns table (id uuid, scope text, note text, confidence real, evidence_count integer,
  last_seen timestamptz, valid_until timestamptz, about text[])
language sql stable as $$ select null::uuid, null, null, null::real, null::int, null::timestamptz, null::timestamptz, null::text[] where false $$;
create function public.zad_memory_recall_entities(p_user uuid, p_text text, p_limit integer default 8)
returns table (id uuid, scope text, note text, confidence real, evidence_count integer,
  last_seen timestamptz, valid_until timestamptz, about text[])
language sql stable as $$ select null::uuid, null, null, null::real, null::int, null::timestamptz, null::timestamptz, null::text[] where false $$;

-- بيت a1: «أنا» و«أحمد» (أخ). بيت b1: «أنا» بس.
insert into public.zad_household_members (id, user_id, display_name, kind) values
  ('11111111-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000a1', 'أنا', 'self'),
  ('22222222-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000a1', 'أحمد', 'adult'),
  ('11111111-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000b1', 'أنا', 'self');

insert into public.zad_memory (id, user_id, scope, note, confidence) values
  ('aaaaaaaa-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000a1', 'general', 'أحمد بيروح الجيم كل يوم الصبح', 0.8),
  ('aaaaaaaa-0000-0000-0000-000000000002', '00000000-0000-0000-0000-0000000000a1', 'general', 'بيشرب قهوة كل صبح', 0.7),
  ('bbbbbbbb-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000b1', 'general', 'ملاحظة بيت تاني', 0.7);

insert into public.zad_memory_entities (id, user_id, kind, name, name_key) values
  ('eeeeeeee-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000a1', 'person', 'أحمد', 'احمد');
insert into public.zad_memory_mentions (memory_id, entity_id, user_id) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'eeeeeeee-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000a1');
