-- The sleep window (migration 20261005231523, docs/agent/ZAD_LIVING_BRAIN.md slice 37), on a scratch database:
--
--   docker run -d --name zadpg -e POSTGRES_PASSWORD=pg postgres:17-alpine
--   psql() { docker exec -i zadpg psql -U postgres -v ON_ERROR_STOP=1 -q; }
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/migrations/20261005231523_sleep_window.sql
--   psql < supabase/sql/tests/sleep_window_test.sql
--
-- A and B are two accounts. Raises on the first failed check; each passing one prints "ok:".

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

\set QUIET 1
insert into auth.users values ('00000000-0000-0000-0000-0000000000a1'), ('00000000-0000-0000-0000-0000000000b1') on conflict do nothing;
insert into public.zad_users (id, currency) values ('00000000-0000-0000-0000-0000000000a1', 'EGP'), ('00000000-0000-0000-0000-0000000000b1', 'SAR');
create or replace function pg_temp.who(p text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', case p
    when 'A' then '00000000-0000-0000-0000-0000000000a1' when 'B' then '00000000-0000-0000-0000-0000000000b1' end,
    'role', 'authenticated')::text, false);
end $$;
create or replace function pg_temp.check(cond boolean, label text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAIL: %', label; end if; raise notice 'ok: %', label; end $$;
grant execute on function pg_temp.who(text) to authenticated;
grant execute on function pg_temp.check(boolean, text) to authenticated;
\set QUIET 0

set role authenticated;
select pg_temp.who('A');

-- 1. The phone's learned window goes in, for the caller only.
select pg_temp.check((select zad_set_sleep_window('23:40', '07:10', 5, 'learned') ->> 'source') = 'learned', 'a learned window is stored');
reset role;
select pg_temp.check((select sleep_bed = '23:40' and sleep_wake = '07:10' and sleep_nights = 5 and sleep_source = 'learned'
  from zad_users where id = '00000000-0000-0000-0000-0000000000a1'), 'bed, wake and nights');
select pg_temp.check((select sleep_bed is null from zad_users where id = '00000000-0000-0000-0000-0000000000b1'), 'nobody else touched');

-- 2. The customer's own wins: a later learned window does not overwrite it.
set role authenticated; select pg_temp.who('A');
select zad_set_sleep_window('01:00', '09:00', null, 'manual');
select pg_temp.check((select zad_set_sleep_window('23:00', '06:30', 7, 'learned') ->> 'kept') = 'manual', 'learned does not overwrite manual');
reset role;
select pg_temp.check((select sleep_bed = '01:00' and sleep_source = 'manual' and sleep_nights is null
  from zad_users where id = '00000000-0000-0000-0000-0000000000a1'), 'the manual window stays');

-- 2b. Turning learning off clears a learned window only — the manual one stays.
set role authenticated; select pg_temp.who('A');
select pg_temp.check(not (select (zad_set_sleep_window(null, null, null, 'clear_learned') ->> 'cleared')::boolean), 'manual survives clear_learned');
select pg_temp.who('B');
select zad_set_sleep_window('22:30', '06:00', 4, 'learned');
select pg_temp.check((select (zad_set_sleep_window(null, null, null, 'clear_learned') ->> 'cleared')::boolean), 'a learned window is cleared');
reset role;
select pg_temp.check((select sleep_bed is null from zad_users where id = '00000000-0000-0000-0000-0000000000b1')
  and (select sleep_bed = '01:00' from zad_users where id = '00000000-0000-0000-0000-0000000000a1'), 'each as it should be');

-- 3. Out of range (a night shift, a phone left on) is refused; clear goes back to the default.
set role authenticated; select pg_temp.who('A');
select pg_temp.check((select zad_set_sleep_window('09:00', '17:00', 4, 'learned') ->> 'reason') = 'out_of_range', 'a day sleeper is not a night window');
select pg_temp.check((select zad_set_sleep_window('23:00', null, 4, 'learned') ->> 'reason') = 'invalid_input', 'both times needed');
select pg_temp.check((select zad_set_sleep_window(null, null, null, 'clear') ->> 'cleared')::boolean, 'clear');
reset role;
select pg_temp.check((select sleep_bed is null and sleep_source is null from zad_users where id = '00000000-0000-0000-0000-0000000000a1'), 'cleared to nothing');
do $$ begin
  update zad_users set sleep_source = 'guessed' where id = '00000000-0000-0000-0000-0000000000a1';
  raise exception 'FAIL: unknown source accepted';
exception when check_violation then raise notice 'ok: only learned or manual'; end $$;

-- 4. anon cannot call it.
set role anon;
do $$ begin
  perform zad_set_sleep_window('23:00', '07:00', 3, 'learned');
  raise exception 'FAIL: anon set a window';
exception when insufficient_privilege then raise notice 'ok: anon cannot set a window'; end $$;
reset role;
