-- 20261113120000_old_grocery_orphans.sql on a scratch database: setup, migration, checks.
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/old_grocery_orphans_scaffold.sql
--   psql < supabase/migrations/20261113120000_old_grocery_orphans.sql
--   psql < supabase/sql/tests/old_grocery_orphans_test.sql
\set ON_ERROR_STOP on
do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;
\set QUIET 1
\o /dev/null
create or replace function pg_temp.check(cond boolean, label text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAIL: %', label; end if; raise notice 'ok: %', label; end $$;

select pg_temp.check(not exists (select 1 from public.shared_grocery_list where item_name = 'يتيم'), 'the orphan row is gone');
select pg_temp.check(exists (select 1 from zad_backup.shared_grocery_list_20261113 where item_name = 'يتيم'), 'and kept in the backup');
select pg_temp.check(exists (select 1 from public.shared_grocery_list where item_name = 'عيلة فيها حد'), 'a family with a member keeps its row');
select pg_temp.check(exists (select 1 from public.shared_grocery_list where item_name = 'صاحبه موجود'), 'a row whose author still exists stays');
select pg_temp.check((select count(*) from zad_backup.shared_grocery_list_20261113) = 1, 'only the orphan is backed up');
select pg_temp.check(not has_schema_privilege('authenticated', 'zad_backup', 'usage'), 'the backup is not readable by customers');
