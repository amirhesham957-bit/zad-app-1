-- P2.1 (migration 20261128100000), on a scratch database:
--
--   psql < supabase/sql/tests/events_ledger_scaffold.sql
--   psql < supabase/migrations/20261121160000_events_ledger.sql
--   psql < supabase/migrations/20261128100000_one_person_member.sql
--   psql < supabase/sql/tests/one_person_member_test.sql
--
-- Raises on the first failed check; each passing one prints "ok:".

\set ON_ERROR_STOP on
do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

\set QUIET 1
-- Supabase's default select grant is not in the scratch DB (live has it; the ledger migration only revokes writes). Table-level insert/update/delete stay closed, as live.
grant select on public.zad_household_members to authenticated;
create or replace function pg_temp.check(cond boolean, label text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAIL: %', label; end if; raise notice 'ok: %', label; end $$;
create or replace function pg_temp.who(p uuid) returns void language plpgsql as $$
begin reset role; perform set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, false); set role authenticated; end $$;
-- runs a statement as the current role; true if it raised
create or replace function pg_temp.fails(q text) returns boolean language plpgsql as $$
begin execute q; return false; exception when others then return true; end $$;
grant execute on function pg_temp.who(uuid) to authenticated;
grant execute on function pg_temp.check(boolean, text) to authenticated;
grant execute on function pg_temp.fails(text) to authenticated;
\set a '''00000000-0000-0000-0000-0000000000a1'''
\set b '''00000000-0000-0000-0000-0000000000b1'''
\set ma '''00000000-0000-0000-0000-00000000aa01'''
\set mkid '''00000000-0000-0000-0000-00000000aa02'''
\set mb '''00000000-0000-0000-0000-00000000bb01'''

insert into auth.users values (:a), (:b);
insert into public.zad_household_members (id, user_id, display_name, kind) values
  (:ma, :a, 'أنا', 'self'), (:mkid, :a, 'سلمى', 'child'), (:mb, :b, 'بابا', 'self');
\set QUIET 0

-- ── الصاحب يعدّل الأعمدة الجديدة ──
select pg_temp.who(:a);
update public.zad_household_members set country = 'EG', currency = 'EGP', dialect = 'masri', guardian_member_id = :ma where id = :mkid;
select pg_temp.check((select country || currency || dialect from public.zad_household_members where id = :mkid) = 'EGEGPmasri', 'owner sets country/currency/dialect');
select pg_temp.check((select guardian_member_id from public.zad_household_members where id = :mkid) = :ma, 'owner sets guardian');

-- ── RLS: غير الصاحب مايعدّلش ──
select pg_temp.who(:b);
with u as (update public.zad_household_members set country = 'SA' where id = :mkid returning 1)
select pg_temp.check((select count(*) from u) = 0, 'non-owner update affects 0 rows');
with u as (update public.zad_household_members set guardian_member_id = :mb where id = :mkid returning 1)
select pg_temp.check((select count(*) from u) = 0, 'non-owner guardian_member_id update on a foreign row affects 0 rows');
select pg_temp.who(:a);
select pg_temp.check((select country from public.zad_household_members where id = :mkid) = 'EG', 'non-owner update changed nothing');
select pg_temp.check((select guardian_member_id from public.zad_household_members where id = :mkid) = :ma, 'non-owner guardian update changed nothing');
select pg_temp.who(:b);
select pg_temp.check(pg_temp.fails($q$update public.zad_household_members set guardian_member_id = '00000000-0000-0000-0000-00000000aa01' where id = '00000000-0000-0000-0000-00000000bb01'$q$), 'guardian from another household is refused (fk)');

-- ── باقي الأعمدة لسه مقفولة ──
select pg_temp.who(:a);
select pg_temp.check(pg_temp.fails($q$update public.zad_household_members set display_name = 'x' where id = '00000000-0000-0000-0000-00000000aa02'$q$), 'display_name still not writable directly');
select pg_temp.check(pg_temp.fails($q$update public.zad_household_members set user_id = '00000000-0000-0000-0000-0000000000b1' where id = '00000000-0000-0000-0000-00000000aa02'$q$), 'user_id not writable');
select pg_temp.check(pg_temp.fails($q$insert into public.zad_household_members (user_id, display_name, kind) values ('00000000-0000-0000-0000-0000000000a1', 'z', 'adult')$q$), 'insert still closed to authenticated');

-- ── قيود ──
select pg_temp.check(pg_temp.fails($q$update public.zad_household_members set guardian_member_id = id where id = '00000000-0000-0000-0000-00000000aa02'$q$), 'own guardian refused');
select pg_temp.check(pg_temp.fails($q$update public.zad_household_members set currency = '' where id = '00000000-0000-0000-0000-00000000aa02'$q$), 'empty currency refused');

-- ── مسح الوليّ يفضّي العمود بس ──
reset role;
delete from public.zad_household_members where id = :ma;
select pg_temp.check((select guardian_member_id is null and user_id = :a from public.zad_household_members where id = :mkid), 'deleting the guardian nulls guardian_member_id only');
select pg_temp.check((select count(*) from public.zad_household_members where id = :mkid) = 1, 'the child row survives');
