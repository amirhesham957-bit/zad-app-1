-- The family layer of the memory (migration 20261113060000, ZAD_PLAN 10.2c), on a scratch database. Runs in CI:
--   docker run -d --name zadpg -e POSTGRES_PASSWORD=pg postgres:17-alpine
--   psql() { docker exec -i zadpg psql -U postgres -v ON_ERROR_STOP=1 -q; }
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/memory_family_share_scaffold.sql
--   psql < supabase/migrations/20261113060000_memory_family_share.sql
--   psql < supabase/sql/tests/memory_family_share_test.sql
--
-- F = a1 (admin), b1 (member), c1 (child). G = d1 alone. f1 has no family. e1 left F before the migration.
-- Raises on the first failed check.

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

create or replace function pg_temp.check(cond boolean, label text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAIL: %', label; end if; raise notice 'ok: %', label; end $$;

-- What a given account can read through RLS.
create or replace function pg_temp.sees(viewer uuid, p_note uuid) returns boolean language plpgsql as $$
declare v boolean;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', viewer, 'role', 'authenticated')::text, true);
  set local role authenticated;
  select exists (select 1 from public.zad_memory where id = p_note) into v;
  reset role;
  return v;
end $$;
grant select on public.zad_memory, public.family_members to authenticated;

insert into public.zad_memory (id, user_id, scope, note) values
  ('a0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000a1', 'general', 'قسط العربية ٣٠٠٠'),
  ('c0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000c1', 'general', 'عندي امتحان'),
  ('d0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000d1', 'general', 'الإيجار يوم ٥'),
  ('f1000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000f1', 'general', 'النت ٤٥٠');

select pg_temp.check((select family_id from public.zad_memory where id = 'e0000000-0000-0000-0000-0000000000e1') is null,
  'backfill: a note shared by someone who already left goes private');

-- The client can neither share nor see the function.
select pg_temp.check(not has_function_privilege('authenticated', 'public.zad_memory_share_with_family(uuid, uuid, boolean)', 'execute'),
  'authenticated cannot call the share function');
select pg_temp.check(not has_function_privilege('anon', 'public.zad_memory_share_with_family(uuid, uuid, boolean)', 'execute'),
  'anon cannot call the share function');
select pg_temp.check(has_function_privilege('service_role', 'public.zad_memory_share_with_family(uuid, uuid, boolean)', 'execute'),
  'service_role can call the share function');

-- Private by default.
select pg_temp.check(not pg_temp.sees('00000000-0000-0000-0000-0000000000b1', 'a0000000-0000-0000-0000-000000000001'),
  'a private note is not visible to the family');

-- Only the writer shares their own note.
select pg_temp.check(public.zad_memory_share_with_family('00000000-0000-0000-0000-0000000000b1', 'a0000000-0000-0000-0000-000000000001', true) ->> 'reason' = 'unknown_note',
  'another member cannot share my note');
select pg_temp.check((select family_id from public.zad_memory where id = 'a0000000-0000-0000-0000-000000000001') is null,
  'the refused share changed nothing');

select pg_temp.check((public.zad_memory_share_with_family('00000000-0000-0000-0000-0000000000a1', 'a0000000-0000-0000-0000-000000000001', true) ->> 'shared')::boolean,
  'the writer shares their note');
select pg_temp.check(pg_temp.sees('00000000-0000-0000-0000-0000000000b1', 'a0000000-0000-0000-0000-000000000001'),
  'a family member now sees it');
select pg_temp.check(not pg_temp.sees('00000000-0000-0000-0000-0000000000f1', 'a0000000-0000-0000-0000-000000000001'),
  'an outsider still does not');

select pg_temp.check(public.zad_memory_share_with_family('00000000-0000-0000-0000-0000000000c1', 'c0000000-0000-0000-0000-000000000001', true) ->> 'reason' = 'child',
  'a child account does not share');
select pg_temp.check(public.zad_memory_share_with_family('00000000-0000-0000-0000-0000000000d1', 'd0000000-0000-0000-0000-000000000001', true) ->> 'reason' = 'alone',
  'a family of one has nobody to share with');
select pg_temp.check(public.zad_memory_share_with_family('00000000-0000-0000-0000-0000000000f1', 'f1000000-0000-0000-0000-000000000001', true) ->> 'reason' = 'no_family',
  'no family, no sharing');

-- «خليها ليا»: always allowed.
select pg_temp.check(not (public.zad_memory_share_with_family('00000000-0000-0000-0000-0000000000a1', 'a0000000-0000-0000-0000-000000000001', false) ->> 'shared')::boolean,
  'the writer takes it back');
select pg_temp.check(not pg_temp.sees('00000000-0000-0000-0000-0000000000b1', 'a0000000-0000-0000-0000-000000000001'),
  'and the family no longer sees it');

-- Leaving the family ends the consent.
select public.zad_memory_share_with_family('00000000-0000-0000-0000-0000000000a1', 'a0000000-0000-0000-0000-000000000001', true);
delete from public.family_members where user_id = '00000000-0000-0000-0000-0000000000a1';
select pg_temp.check((select family_id from public.zad_memory where id = 'a0000000-0000-0000-0000-000000000001') is null,
  'leaving the family makes the writer''s shared notes private');

-- Even if a family id is left behind some other way, the policy wants the writer still in the family.
update public.zad_memory set family_id = 'f0000000-0000-0000-0000-00000000000f' where id = 'a0000000-0000-0000-0000-000000000001';
select pg_temp.check(not pg_temp.sees('00000000-0000-0000-0000-0000000000b1', 'a0000000-0000-0000-0000-000000000001'),
  'a note whose writer left is not readable by the old family');

select 'memory_family_share_test: all checks passed' as result;
