-- وضع السفر من الموقع (migration 20261103180000), on a scratch database:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/travel_from_location_scaffold.sql
--   psql < supabase/migrations/20261103180000_travel_from_location.sql
--   psql < supabase/sql/tests/travel_from_location_test.sql
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

-- 1. Cities land in their country; the small states are not swallowed by the big boxes round them.
select pg_temp.check(
  (select bool_and(public.zad_country_at(lat, lon) is not distinct from want) from (values
    (29.9, 31.0, 'EG'), (30.04, 31.24, 'EG'), (31.2, 29.9, 'EG'), (27.25, 33.8, 'EG'), (27.9, 34.3, 'EG'), (24.09, 32.9, 'EG'),
    (24.7, 46.7, 'SA'), (21.5, 39.2, 'SA'), (21.4, 39.8, 'SA'), (24.5, 39.6, 'SA'), (26.4, 50.1, 'SA'), (28.38, 36.57, 'SA'), (16.9, 42.55, 'SA'),
    (26.22, 50.58, 'BH'), (25.29, 51.53, 'QA'), (29.37, 47.98, 'KW'), (25.2, 55.27, 'AE'), (24.45, 54.38, 'AE'), (23.59, 58.4, 'OM'),
    (31.95, 35.93, 'JO'), (33.89, 35.5, 'LB'), (33.51, 36.29, 'SY'), (36.2, 37.16, 'SY'), (33.31, 44.36, 'IQ'), (30.5, 47.8, 'IQ'),
    (41.0, 28.98, 'TR'), (39.93, 32.86, 'TR'), (15.37, 44.19, 'YE'), (12.8, 45.03, 'YE'), (32.89, 13.19, 'LY'), (36.8, 10.18, 'TN'),
    (36.75, 3.06, 'DZ'), (33.57, -7.59, 'MA'), (31.63, -8.0, 'MA'), (15.5, 32.56, 'SD'), (31.5, 34.46, 'PS')
  ) as c(lat, lon, want)), 'cities land in their country');

-- 2. Places outside every market, and nulls, are not known — never a wrong country.
select pg_temp.check(public.zad_country_at(51.5, -0.12) is null, 'London is not known');
select pg_temp.check(public.zad_country_at(40.18, 44.5) is null, 'Yerevan is not Turkey');
select pg_temp.check(public.zad_country_at(34.3, 47.1) is null, 'Kermanshah is not Iraq');
select pg_temp.check(public.zad_country_at(29.53, 35.0) is null, 'Aqaba and Eilat are not guessed');
select pg_temp.check(public.zad_country_at(33.85, 35.86) = 'LB', 'Zahle is Lebanon');
select pg_temp.check(public.zad_country_at(null, 31.0) is null, 'no point, no country');

-- 3. A Saudi account whose phone is in Giza starts a trip once, with the moment.
\set u '''00000000-0000-0000-0000-0000000000a1'''
insert into auth.users (id) values (:u) on conflict do nothing;
insert into public.zad_users (id, currency, country) values (:u, 'SAR', 'SA');
update public.zad_users set last_lat = 29.9, last_lon = 31.0, last_location_at = now() where id = :u;
select pg_temp.check((select travel_country = 'EG' and travel_since is not null from public.zad_users where id = :u), 'in Giza = travelling in Egypt');
select pg_temp.check((select count(*) = 1 and bool_and(facts ->> 'from' = 'location') from public.zad_voice_moments where user_id = :u and moment = 'travel_arrived'),
  'one travel_arrived moment');

-- 4. The same point written again changes nothing; a second point in Egypt keeps the trip's start.
update public.zad_users set travel_since = now() - interval '2 days' where id = :u;
update public.zad_users set last_lat = 29.9, last_lon = 31.0 where id = :u;
update public.zad_users set last_lat = 31.2, last_lon = 29.9 where id = :u;
select pg_temp.check((select travel_since < now() - interval '1 day' from public.zad_users where id = :u), 'the trip keeps its start');
select pg_temp.check((select count(*) = 1 from public.zad_voice_moments where user_id = :u), 'no second moment');

-- 5. A point on no map (the sea, a border) leaves the trip alone; home ends it.
update public.zad_users set last_lat = 34.0, last_lon = 33.0 where id = :u;
select pg_temp.check((select travel_country = 'EG' from public.zad_users where id = :u), 'an unknown point changes nothing');
update public.zad_users set last_lat = 24.7, last_lon = 46.7 where id = :u;
select pg_temp.check((select travel_country is null and travel_since is null from public.zad_users where id = :u), 'back in Riyadh ends the trip');

-- 6. No market chosen: nothing happens.
\set v '''00000000-0000-0000-0000-0000000000b1'''
insert into auth.users (id) values (:v) on conflict do nothing;
insert into public.zad_users (id, currency) values (:v, 'EGP');
update public.zad_users set last_lat = 29.9, last_lon = 31.0 where id = :v;
select pg_temp.check((select travel_country is null from public.zad_users where id = :v), 'no market, no trip');

-- 7. Customers cannot call the trigger function.
select pg_temp.check(not has_function_privilege('authenticated', 'public.zad_users_travel_from_location()', 'execute'),
  'the trigger function is not a customer door');
