-- Trusted technicians (migration 20261006014219, docs/agent/ZAD_LIVING_BRAIN.md slice 43), on a scratch database:
--
--   docker run -d --name zadpg -e POSTGRES_PASSWORD=pg postgres:17-alpine
--   psql() { docker exec -i zadpg psql -U postgres -v ON_ERROR_STOP=1 -q; }
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/migrations/20261006014219_trusted_technicians.sql
--   psql < supabase/sql/tests/trusted_technicians_test.sql
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

-- 1. The customer's own technicians go in.
insert into zad_trusted_technicians (user_id, name, trade, phone) values
  ('00000000-0000-0000-0000-0000000000a1', 'عم سيد', 'plumber', '01001234567'),
  ('00000000-0000-0000-0000-0000000000a1', 'أبو محمد', 'electrician', '+20 100 765 4321');
select pg_temp.check((select count(*) from zad_trusted_technicians) = 2, 'two technicians stored');

-- 2. Nonsense is refused by the table itself.
do $$ begin
  insert into zad_trusted_technicians (user_id, name, trade, phone) values ('00000000-0000-0000-0000-0000000000a1', 'حد', 'doctor', '01001234568');
  raise exception 'FAIL: unknown trade accepted';
exception when check_violation then raise notice 'ok: only the known trades'; end $$;
do $$ begin
  insert into zad_trusted_technicians (user_id, name, trade, phone) values ('00000000-0000-0000-0000-0000000000a1', 'حد', 'gas', 'اتصل بيا');
  raise exception 'FAIL: a phone that is not a number accepted';
exception when check_violation then raise notice 'ok: the phone is digits'; end $$;
do $$ begin
  insert into zad_trusted_technicians (user_id, name, trade, phone) values ('00000000-0000-0000-0000-0000000000a1', ' عم سيد ', 'gas', '01001234569');
  raise exception 'FAIL: an untrimmed name accepted';
exception when check_violation then raise notice 'ok: the name is trimmed'; end $$;
do $$ begin
  insert into zad_trusted_technicians (user_id, name, trade, phone) values ('00000000-0000-0000-0000-0000000000a1', 'تاني', 'ac', '01001234567');
  raise exception 'FAIL: the same number twice';
exception when unique_violation then raise notice 'ok: one row per number'; end $$;

-- 3. Nobody else reads, edits, deletes or adds for A.
select pg_temp.who('B');
select pg_temp.check((select count(*) from zad_trusted_technicians) = 0, 'another account sees nothing');
update zad_trusted_technicians set phone = '01111111111';
delete from zad_trusted_technicians;
do $$ begin
  insert into zad_trusted_technicians (user_id, name, trade, phone) values ('00000000-0000-0000-0000-0000000000a1', 'دخيل', 'gas', '01222222222');
  raise exception 'FAIL: B wrote into A''s list';
exception when insufficient_privilege then raise notice 'ok: no writing into another account'; end $$;
select pg_temp.who('A');
select pg_temp.check((select count(*) from zad_trusted_technicians) = 2
  and (select phone from zad_trusted_technicians where trade = 'plumber') = '01001234567', 'B changed and deleted nothing');

-- 4. A can't hand a row to B either.
do $$ begin
  update zad_trusted_technicians set user_id = '00000000-0000-0000-0000-0000000000b1' where trade = 'plumber';
  raise exception 'FAIL: moved a technician to another account';
exception when insufficient_privilege then raise notice 'ok: a row stays with its owner'; end $$;

-- 5. The owner deletes their own.
delete from zad_trusted_technicians where trade = 'electrician';
select pg_temp.check((select count(*) from zad_trusted_technicians) = 1, 'the owner deletes');
reset role;

-- 6. anon has nothing at all.
set role anon;
do $$ begin
  perform 1 from zad_trusted_technicians;
  raise exception 'FAIL: anon read the list';
exception when insufficient_privilege then raise notice 'ok: anon cannot read'; end $$;
reset role;
