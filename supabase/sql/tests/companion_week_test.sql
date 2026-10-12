-- تحدي الأسبوع (20261012070000) on a scratch database, on top of the companion:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/companion_scaffold.sql
--   psql < supabase/migrations/20261012030000_companion.sql
--   psql < supabase/migrations/20261012070000_companion_week_challenge.sql
--   psql < supabase/sql/tests/companion_week_test.sql
--
-- «Today» is pinned to Friday 2026-10-16, so its week (Saturday 2026-10-10 on) is fixed.

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

\set QUIET 1
create or replace function public.zad_companion_today(p_user uuid) returns date
language sql stable as $$ select date '2026-10-16' $$;
insert into auth.users (id) values ('00000000-0000-0000-0000-0000000000d1') on conflict do nothing;
insert into public.zad_users (id, country) values ('00000000-0000-0000-0000-0000000000d1', 'EG') on conflict do nothing;
create table if not exists results (n int, ok boolean, note text);
grant all on results to authenticated;
create or replace function pg_temp.check(n int, ok boolean, note text default '') returns void language sql as $$
  insert into results values (n, coalesce(ok, false), note) $$;
create or replace function pg_temp.d() returns uuid language sql as $$ select '00000000-0000-0000-0000-0000000000d1'::uuid $$;
create table if not exists s (k text primary key, v jsonb);
grant all on s to authenticated;

-- 1. The week starts on Saturday.
select pg_temp.check(1, zad_companion_week_start(date '2026-10-16') = date '2026-10-10'
  and zad_companion_week_start(date '2026-10-10') = date '2026-10-10'
  and zad_companion_week_start(date '2026-10-09') = date '2026-10-03');

-- Logged on Saturday, Sunday and Tuesday of this week, and on last Thursday (another week).
select zad_companion_ensure(pg_temp.d());
insert into zad_companion_ledger (user_id, source, ref, day, xp) values
  (pg_temp.d(), 'log', 'a', date '2026-10-10', 10), (pg_temp.d(), 'scan', 'b', date '2026-10-11', 20),
  (pg_temp.d(), 'log', 'c', date '2026-10-13', 10), (pg_temp.d(), 'log', 'z', date '2026-10-08', 10);

-- 2. Wednesday makes four: no challenge yet.
insert into zad_companion_ledger (user_id, source, ref, day, xp) values (pg_temp.d(), 'log', 'wed', date '2026-10-14', 10);
select pg_temp.check(2, not exists (select 1 from zad_companion_ledger where user_id = pg_temp.d() and source = 'challenge'));

-- 3–4. Friday's expense is the fifth day: +100 XP once, keyed on the week.
select set_config('request.jwt.claims', json_build_object('sub', pg_temp.d(), 'role', 'authenticated')::text, false);
set role authenticated;
insert into zad_transactions (user_id, amount) values (pg_temp.d(), 40);
insert into zad_transactions (user_id, amount) values (pg_temp.d(), 15);
insert into s select 'st', zad_companion_status();
reset role;
select pg_temp.check(3, (select xp from zad_companion_ledger where user_id = pg_temp.d() and source = 'challenge' and ref = '2026-10-10') = 100);
select pg_temp.check(4, (select count(*) from zad_companion_ledger where user_id = pg_temp.d() and source = 'challenge') = 1);

-- 5. The studio reads the week.
select pg_temp.check(5, v->'week' = '{"days": 5, "goal": 5, "done": true}'::jsonb, v->>'week') from s where k = 'st';

-- 6. The celebration's seeds still add up with non-numeric refs in the ledger (uuids, dates).
select pg_temp.check(6, (v->>'level')::int >= 1 and v ? 'celebrate', v::text) from s where k = 'st';

\set QUIET 0
select n, ok, note from results order by n;
do $$ declare bad int; total int; begin
  select count(*) filter (where not ok), count(*) into bad, total from results;
  if bad > 0 then raise exception '% of % week checks failed', bad, total; end if;
  raise notice 'all % week checks passed', total;
end $$;
