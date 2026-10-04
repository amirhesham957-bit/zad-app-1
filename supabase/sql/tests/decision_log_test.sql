-- The decision log (migration 20261004140000, docs/agent/ZAD_LIVING_BRAIN.md
-- slice 26), on a scratch database:
--
--   docker run -d --name zadpg -e POSTGRES_PASSWORD=pg postgres:17-alpine
--   psql() { docker exec -i zadpg psql -U postgres -v ON_ERROR_STOP=1 -q; }
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/migrations/20261004140000_decision_log.sql
--   psql < supabase/sql/tests/decision_log_test.sql
--
-- A logged a decision (the server writes it), B is another account. Raises on
-- the first failed check; each passing one prints "ok:".

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
    else '{}' end, false);
end $$;
create or replace function pg_temp.check(cond boolean, label text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAIL: %', label; end if; raise notice 'ok: %', label; end $$;
grant execute on function pg_temp.who(text) to authenticated, anon;
grant execute on function pg_temp.check(boolean, text) to authenticated, anon;
\set QUIET 0

-- The server (zad-brain, service role) writes.
insert into zad_decision_log (user_id, label, one_time_cost, monthly_cost, baseline_income, baseline_spend, baseline_days)
values ('00000000-0000-0000-0000-0000000000a1', 'العربية', 50000, 1000, 10000, 7000, 90);

-- 1. Bad rows are refused by the table itself.
do $$ begin
  begin
    insert into zad_decision_log (user_id, label) values ('00000000-0000-0000-0000-0000000000a1', '  ');
    raise exception 'FAIL: an empty label went in';
  exception when check_violation then raise notice 'ok: a label is needed';
  end;
  begin
    insert into zad_decision_log (user_id, label, monthly_cost) values ('00000000-0000-0000-0000-0000000000a1', 'x', -5);
    raise exception 'FAIL: a negative cost went in';
  exception when check_violation then raise notice 'ok: costs are not negative';
  end;
  begin
    insert into zad_decision_log (user_id, label, reviews) values ('00000000-0000-0000-0000-0000000000a1', 'x', 3);
    raise exception 'FAIL: a third review went in';
  exception when check_violation then raise notice 'ok: two reviews at most';
  end;
end $$;

set role authenticated;

-- 2. The owner reads it; another account does not.
select pg_temp.who('A');
select pg_temp.check((select count(*) from zad_decision_log) = 1, 'the owner reads their decision');
select pg_temp.who('B');
select pg_temp.check((select count(*) from zad_decision_log) = 0, 'another account reads nothing');

-- 3. Nobody writes from the app: not a new decision, not a review.
select pg_temp.who('A');
do $$ begin
  begin
    insert into zad_decision_log (user_id, label) values ('00000000-0000-0000-0000-0000000000a1', 'مدرسة');
    raise exception 'FAIL: the app inserted a decision';
  exception when insufficient_privilege then raise notice 'ok: the app does not insert';
  end;
  begin
    update zad_decision_log set reviews = 2;
    raise exception 'FAIL: the app marked a review';
  exception when insufficient_privilege then raise notice 'ok: the app does not mark reviews';
  end;
end $$;

-- 4. Another account cannot delete it; the owner can.
select pg_temp.who('B');
delete from zad_decision_log;
select pg_temp.who('A');
select pg_temp.check((select count(*) from zad_decision_log) = 1, 'another account deleted nothing');
delete from zad_decision_log;
select pg_temp.check((select count(*) from zad_decision_log) = 0, 'the owner deletes their decision');

-- 5. anon has nothing.
reset role;
set role anon;
do $$ begin
  perform 1 from zad_decision_log;
  raise exception 'FAIL: anon read the log';
exception when insufficient_privilege then raise notice 'ok: anon reads nothing';
end $$;
reset role;
