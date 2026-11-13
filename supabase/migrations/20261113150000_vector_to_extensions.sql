-- ٨.٥ step 1 (owner 13/11; plan in docs/agent/PLAN_8_5_EXTENSIONS.md): move pgvector out of
-- public. The advisor flags extension_in_public; Supabase's own target is schema extensions.
--
-- Measured 13/11 on live: vector 0.8.2 is relocatable. It backs zad_memory.embedding and
-- idx_zad_memory_embedding (ivfflat) — both bound by OID, so they follow the type with no
-- rebuild — and three functions. zad_memory_review_candidates already has extensions on its
-- path; the other two are pinned to public and would lose the <=> operator. Their paths are
-- set first, while vector still resolves in public.
--
-- Rollback: alter extension vector set schema public;

create schema if not exists extensions;

alter function public.zad_memory_semantic_search(uuid, vector, integer)
  set search_path = public, extensions, pg_temp;
alter function public.zad_memory_set_embedding(uuid, text, vector)
  set search_path = public, extensions, pg_temp;

alter extension vector set schema extensions;
