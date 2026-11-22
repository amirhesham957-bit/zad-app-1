-- ميزانية الرحلة (migration 20261123010000), on a scratch database:
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/travel_from_location_scaffold.sql
--   psql < supabase/migrations/20261123010000_trip_budget.sql
--   psql < supabase/sql/tests/trip_budget_test.sql
\set ON_ERROR_STOP on
do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;
\set QUIET 1
insert into auth.users values ('00000000-0000-0000-0000-0000000000c1');
insert into public.zad_users (id, currency, country) values ('00000000-0000-0000-0000-0000000000c1', 'EGP', 'EG');
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000c1","role":"authenticated"}', false);
create or replace function pg_temp.check(cond boolean, label text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAIL: %', label; end if; raise notice 'ok: %', label; end $$;
grant execute on function pg_temp.check(boolean, text) to authenticated;
\set QUIET 0

set role authenticated;
select pg_temp.check(zad_trip_budget_set(500) ->> 'reason' = 'not_traveling', 'no budget while at home');
reset role;
update public.zad_users set travel_country = 'AE', travel_since = now() where id = '00000000-0000-0000-0000-0000000000c1';
set role authenticated;
select pg_temp.check((zad_trip_budget_set(500) ->> 'ok')::boolean, 'budget set on a trip');
select pg_temp.check(zad_trip_budget_set(-5) ->> 'reason' = 'bad_amount', 'negative refused');
select pg_temp.check(zad_trip_budget_set(0) ->> 'reason' = 'bad_amount', 'zero refused');
reset role;
select pg_temp.check((select travel_budget = 500 from zad_users where id = '00000000-0000-0000-0000-0000000000c1'), 'stored as sent');
update public.zad_users set travel_country = 'TR' where id = '00000000-0000-0000-0000-0000000000c1';
select pg_temp.check((select travel_budget is null from zad_users where id = '00000000-0000-0000-0000-0000000000c1'), 'a new country clears the budget');
update public.zad_users set travel_budget = 300 where id = '00000000-0000-0000-0000-0000000000c1';
update public.zad_users set travel_country = null, travel_since = null where id = '00000000-0000-0000-0000-0000000000c1';
select pg_temp.check((select travel_budget is null from zad_users where id = '00000000-0000-0000-0000-0000000000c1'), 'coming home clears the budget');
select pg_temp.check(not has_function_privilege('anon', 'public.zad_trip_budget_set(numeric)', 'EXECUTE'), 'anon cannot set it');
