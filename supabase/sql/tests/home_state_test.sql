-- حالة البيت (migration 20261025012500, ZAD_PLAN 3.1), on a scratch database:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/home_state_scaffold.sql
--   psql < supabase/migrations/20261025012500_home_state.sql
--   psql < supabase/sql/tests/home_state_test.sql
--
-- Raises on the first failed check; each passing one prints "ok:".

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

\set QUIET 1
create or replace function pg_temp.check(cond boolean, label text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAIL: %', label; end if; raise notice 'ok: %', label; end $$;
create or replace function pg_temp.who(p uuid) returns void language plpgsql as $$
begin perform set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, false); end $$;
grant execute on function pg_temp.who(uuid) to authenticated;
grant execute on function pg_temp.check(boolean, text) to authenticated;
\set a '''00000000-0000-0000-0000-0000000000a1'''
\set b '''00000000-0000-0000-0000-0000000000b1'''
\set c '''00000000-0000-0000-0000-0000000000c1'''
\set fam '''00000000-0000-0000-0000-0000000000f1'''
-- «Computed a minute ago» for everyone, so any touch after it reads as a change.
create or replace function pg_temp.settle() returns void language sql as $$
  update public.zad_home_state set computed_at = now() - interval '1 minute', dirty_at = now() - interval '2 minutes', version = 1, state = '{"ok":1}' $$;
\set QUIET 0

select pg_temp.check((select count(*) from public.zad_home_state) = 3, 'every account gets a row from the migration');
select pg_temp.check((select count(*) from public.zad_home_states_due(1, 50)) = 3, 'and a row never computed is due');

select pg_temp.settle();
select pg_temp.check(not exists (select 1 from public.zad_home_states_due(1, 50)), 'a row computed after its last change is not due');
select pg_temp.check((select count(*) from public.zad_home_states_due(2, 50)) = 3, 'a row of an older version is due');
select pg_temp.check((select count(*) from public.zad_home_states_due(null, 50)) = 0, 'the cron''s check ignores the version');

insert into public.zad_transactions (user_id, amount) values (:a, 50);
select pg_temp.check((select array_agg(user_id) from public.zad_home_states_due(1, 50)) = array[:a::uuid], 'a new transaction makes that home due, and only that one');

select pg_temp.settle();
insert into public.family_groups (id) values (:fam);
insert into public.family_members (family_id, user_id) values (:fam, :b), (:fam, :c);
insert into public.zad_inventory (user_id, family_id, item_name, quantity) values (:b, :fam, 'لبن', 2);
select pg_temp.check((select count(*) from public.zad_home_states_due(1, 50) where user_id in (:b, :c)) = 2, 'a shared pantry item makes every member''s home due');

select pg_temp.settle();
delete from public.zad_inventory;
select pg_temp.check((select count(*) from public.zad_home_states_due(1, 50)) = 2, 'a delete counts as a change');

select pg_temp.settle();
update public.zad_users set last_lat = 30.1 where id = :a;
select pg_temp.check(not exists (select 1 from public.zad_home_states_due(1, 50)), 'a location ping is not a change of the home');
update public.zad_users set currency = 'SAR' where id = :a;
select pg_temp.check(exists (select 1 from public.zad_home_states_due(1, 50) where user_id = :a), 'a currency change is');

select pg_temp.settle();
insert into public.zad_transactions (user_id, amount) values ('00000000-0000-0000-0000-00000000dead', 5);
select pg_temp.check((select count(*) from public.zad_home_state) = 3, 'a row for an unknown account is never made, and the write still lands');
select pg_temp.check((select count(*) from public.zad_transactions) = 2, 'both transactions are there');

update public.zad_home_state set computed_at = now() - interval '7 hours', dirty_at = now() - interval '8 hours' where user_id = :a;
update public.zad_home_state set computed_at = now() - interval '7 hours', dirty_at = now() - interval '40 days' where user_id = :b;
select pg_temp.check((select array_agg(user_id) from public.zad_home_states_due(1, 50)) = array[:a::uuid], 'an old state of a living home is due; a home quiet for a month is not');

-- The customer reads their own row and writes none.
set role authenticated;
select pg_temp.who(:a);
select pg_temp.check((select count(*) from public.zad_home_state) = 1, 'the customer reads only their own row');
do $$ begin
  update public.zad_home_state set state = '{}';
  raise exception 'FAIL: a customer wrote their home state';
exception when insufficient_privilege then raise notice 'ok: a customer cannot write the state';
end $$;
reset role;
select pg_temp.check(not has_function_privilege('authenticated', 'public.zad_home_states_due(int, int)', 'execute'), 'customers cannot list due homes');
