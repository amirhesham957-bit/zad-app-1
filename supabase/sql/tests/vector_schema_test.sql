-- ٨.٥ step 1: after the move, vector lives in extensions and memory search still works.
-- Runs after scratch_scaffold, memory_scaffold, the memory migrations and 20261113150000
-- on pgvector/pgvector:pg17 (CI's postgres has no pgvector, like memory_heals_test).
\set ON_ERROR_STOP on
do $$
declare
  u uuid := '00000000-0000-0000-0000-0000000000a1';
  v extensions.vector := array_fill(0.1::real, array[768])::extensions.vector;
  hits int;
begin
  if (select extnamespace::regnamespace::text from pg_extension where extname = 'vector') <> 'extensions' then
    raise exception 'vector is not in schema extensions';
  end if;
  if exists (select 1 from pg_type t join pg_namespace n on n.oid = t.typnamespace where t.typname = 'vector' and n.nspname = 'public') then
    raise exception 'a vector type is still in public';
  end if;
  insert into auth.users (id) values (u) on conflict do nothing;
  insert into public.zad_memory (user_id, scope, note) values (u, 'household_profile', 'عنده عيلين');
  perform public.zad_memory_set_embedding(u, 'عنده عيلين', v);
  select count(*) into hits from public.zad_memory_semantic_search(u, v, 5);
  if hits <> 1 then raise exception 'semantic search returned % rows after the move, expected 1', hits; end if;
  raise notice 'vector_schema_test: 4 checks passed';
end $$;
