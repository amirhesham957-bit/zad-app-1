-- zad_memory as far as 20261113060000 touches it (no pgvector needed, so it runs in CI), plus a stale
-- shared note from a writer who already left — the migration's backfill has to clear it.
-- Loads after scratch_scaffold.sql (roles, auth, family_groups, family_members, get_my_family_ids).

\set ON_ERROR_STOP on

create table public.zad_memory (
  id uuid primary key default gen_random_uuid(), user_id uuid not null, scope text not null, note text not null,
  family_id uuid references public.family_groups(id) on delete set null, superseded_by uuid, valid_until timestamptz
);
alter table public.zad_memory enable row level security;
create policy "user_own_memory" on public.zad_memory for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
-- The policy as 20260901170000 left it: the family id alone.
create policy "family_shared_memory_select" on public.zad_memory for select using (family_id in (select get_my_family_ids()));

insert into public.family_groups (id) values
  ('f0000000-0000-0000-0000-00000000000f'), ('f0000000-0000-0000-0000-0000000000a0');
-- F: a1 admin, b1 member, c1 child. G: d1 alone. e1 left F before this migration.
insert into public.family_members (family_id, user_id, role) values
  ('f0000000-0000-0000-0000-00000000000f', '00000000-0000-0000-0000-0000000000a1', 'admin'),
  ('f0000000-0000-0000-0000-00000000000f', '00000000-0000-0000-0000-0000000000b1', 'member'),
  ('f0000000-0000-0000-0000-00000000000f', '00000000-0000-0000-0000-0000000000c1', 'child'),
  ('f0000000-0000-0000-0000-0000000000a0', '00000000-0000-0000-0000-0000000000d1', 'admin');
insert into public.zad_memory (id, user_id, scope, note, family_id) values
  ('e0000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000e1', 'general', 'stale shared note',
   'f0000000-0000-0000-0000-00000000000f');
