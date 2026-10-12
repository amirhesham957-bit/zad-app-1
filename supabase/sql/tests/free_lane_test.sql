-- حارة المجاني وحارس العميل (20261012040000) on a scratch database:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/migrations/20261012040000_free_lane.sql
--   psql < supabase/sql/tests/free_lane_test.sql

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

\set QUIET 1
insert into auth.users (id) values ('00000000-0000-0000-0000-0000000000a1'), ('00000000-0000-0000-0000-0000000000b1') on conflict do nothing;
create table if not exists results (n int, ok boolean, note text);
create or replace function pg_temp.check(n int, ok boolean, note text default '') returns void language sql as $$
  insert into results values (n, coalesce(ok, false), note) $$;
create or replace function pg_temp.a() returns uuid language sql as $$ select '00000000-0000-0000-0000-0000000000a1'::uuid $$;
create or replace function pg_temp.b() returns uuid language sql as $$ select '00000000-0000-0000-0000-0000000000b1'::uuid $$;

-- 1–2. The day's free count goes up by one per call.
select pg_temp.check(1, zad_free_load_take() = 1 and zad_free_load_take() = 2 and zad_free_load_take() = 3);
select pg_temp.check(2, (select turns from zad_free_load where day = (now() at time zone 'utc')::date) = 3);

-- 3–5. One turn at a time per customer; another customer is not blocked.
select pg_temp.check(3, zad_turn_begin(pg_temp.a(), 8)->>'ok' = 'true');
select pg_temp.check(4, zad_turn_begin(pg_temp.a(), 8)->>'reason' = 'busy');
select pg_temp.check(5, zad_turn_begin(pg_temp.b(), 8)->>'ok' = 'true');

-- 6. Ended, the next one starts.
select zad_turn_end(pg_temp.a());
select pg_temp.check(6, zad_turn_begin(pg_temp.a(), 8)->>'ok' = 'true');

-- 7. A crashed turn's lock lets go by itself.
update zad_turn_gate set busy_until = now() - interval '1 second' where user_id = pg_temp.a();
select pg_temp.check(7, zad_turn_begin(pg_temp.a(), 8)->>'ok' = 'true');

-- 8–9. The per-minute cap: three allowed, the fourth refused, and a refusal takes nothing.
update zad_turn_gate set busy_until = null, window_start = now(), window_count = 0 where user_id = pg_temp.b();
do $$ begin
  for i in 1..3 loop
    if zad_turn_begin(pg_temp.b(), 3)->>'ok' <> 'true' then raise exception 'turn % refused', i; end if;
    perform zad_turn_end(pg_temp.b());
  end loop;
end $$;
select pg_temp.check(8, zad_turn_begin(pg_temp.b(), 3)->>'reason' = 'too_fast');
select pg_temp.check(9, (select window_count from zad_turn_gate where user_id = pg_temp.b()) = 3);

-- 10. A new minute opens a new window.
update zad_turn_gate set window_start = now() - interval '61 seconds' where user_id = pg_temp.b();
select pg_temp.check(10, zad_turn_begin(pg_temp.b(), 3)->>'ok' = 'true');
select pg_temp.check(12, (select window_count from zad_turn_gate where user_id = pg_temp.b()) = 1);

-- 11. Nothing here is callable from the app.
select pg_temp.check(11, not has_function_privilege('authenticated', 'public.zad_turn_begin(uuid, int)', 'execute')
  and not has_function_privilege('anon', 'public.zad_free_load_take()', 'execute')
  and not has_table_privilege('authenticated', 'public.zad_turn_gate', 'select'));

\set QUIET 0
select n, ok, note from results order by n;
do $$ declare bad int; total int; begin
  select count(*) filter (where not ok), count(*) into bad, total from results;
  if bad > 0 then raise exception '% of % free lane checks failed', bad, total; end if;
  raise notice 'all % free lane checks passed', total;
end $$;
