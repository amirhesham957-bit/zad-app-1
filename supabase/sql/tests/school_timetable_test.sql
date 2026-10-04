-- The school timetable from the camera (migration 20261004110000,
-- docs/agent/ZAD_LIVING_BRAIN.md slice 21), on a scratch database:
--
--   docker run -d --name zadpg -e POSTGRES_PASSWORD=pg postgres:17-alpine
--   psql() { docker exec -i zadpg psql -U postgres -v ON_ERROR_STOP=1 -q; }
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/migrations/20261004110000_school_timetable.sql
--   psql < supabase/sql/tests/school_timetable_test.sql
--
-- A is a parent, B another account. Raises on the first failed check; each
-- passing one prints "ok:".

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

\set QUIET 1
insert into auth.users values ('00000000-0000-0000-0000-0000000000a1'), ('00000000-0000-0000-0000-0000000000b1') on conflict do nothing;
create or replace function pg_temp.who(p text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', case p
    when 'A' then json_build_object('sub', '00000000-0000-0000-0000-0000000000a1', 'role', 'authenticated')::text
    when 'B' then json_build_object('sub', '00000000-0000-0000-0000-0000000000b1', 'role', 'authenticated')::text
    else '' end, false);
end $$;
create or replace function pg_temp.check(cond boolean, label text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAIL: %', label; end if; raise notice 'ok: %', label; end $$;
grant execute on function pg_temp.who(text) to authenticated, anon;
grant execute on function pg_temp.check(boolean, text) to authenticated, anon;
\set QUIET 0

set role authenticated;
select pg_temp.who('A');

-- 1. A timetable goes in whole, periods renumbered, bad rows skipped.
select pg_temp.check((select (zad_timetable_replace('عمر', '[
  {"weekday":0,"periods":[{"order":1,"start":"07:45","end":"08:30","subject":"رياضيات"},{"subject":""},{"subject":"علوم","start":"25:00"}]},
  {"weekday":9,"periods":[{"subject":"يوم مش موجود"}]},
  {"weekday":1,"periods":[{"subject":"لغة عربية"}]}
]'::jsonb)->>'periods')::int) = 3, 'three real periods stored');
select pg_temp.check((select array_agg(subject order by weekday, period) from zad_school_timetable) = array['رياضيات','علوم','لغة عربية'],
  'subjects in order');
select pg_temp.check((select ends from zad_school_timetable where subject = 'رياضيات') = '08:30'::time
  and (select starts from zad_school_timetable where subject = 'علوم') is null, 'times kept when valid, dropped when not');

-- 2. A new photo replaces that child's timetable, not another child's.
select zad_timetable_replace('سلمى', '[{"weekday":2,"periods":[{"subject":"رسم"}]}]'::jsonb);
select zad_timetable_replace('عمر', '[{"weekday":3,"periods":[{"subject":"إنجليزي"}]}]'::jsonb);
select pg_temp.check((select array_agg(person || ':' || subject order by person) from zad_school_timetable)
  = array['سلمى:رسم','عمر:إنجليزي'], 'replaced per child');

-- 3. Nonsense is refused without touching anything.
select pg_temp.check((select zad_timetable_replace('', '[]'::jsonb)->>'reason') = 'bad_person', 'a name is needed');
select pg_temp.check((select zad_timetable_replace('عمر', '{}'::jsonb)->>'reason') = 'bad_days', 'days must be a list');
select pg_temp.check((select count(*) from zad_school_timetable) = 2, 'nothing changed');

-- 4. Nobody else reads, writes or deletes it; the table takes no direct insert.
select pg_temp.who('B');
select pg_temp.check((select count(*) from zad_school_timetable) = 0, 'another account sees nothing');
delete from zad_school_timetable;
select pg_temp.who('A');
select pg_temp.check((select count(*) from zad_school_timetable) = 2, 'and deletes nothing');
do $$ begin
  insert into zad_school_timetable (user_id, person, weekday, period, subject)
    values ('00000000-0000-0000-0000-0000000000a1', 'عمر', 4, 1, 'مباشر');
  raise exception 'FAIL: inserted around the function';
exception when insufficient_privilege then raise notice 'ok: writes go through the function only'; end $$;
reset role;
set role anon;
do $$ begin
  perform zad_timetable_replace('عمر', '[]'::jsonb);
  raise exception 'FAIL: anon called it';
exception when insufficient_privilege then raise notice 'ok: anon cannot write a timetable'; end $$;
reset role;
