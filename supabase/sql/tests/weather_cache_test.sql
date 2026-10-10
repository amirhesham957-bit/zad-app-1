-- zad_weather_cache (migration 20261011100000): the server's only, no customer data. Scratch database only:
--
--   docker run -d --name zadpg -e POSTGRES_PASSWORD=pg postgres:17-alpine
--   psql() { docker exec -i zadpg psql -U postgres -v ON_ERROR_STOP=1 -q; }
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/weather_cache_test.sql
--
-- Rolls back.

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

begin;
\i supabase/migrations/20261011100000_weather_cache.sql
\i supabase/migrations/20261011100000_weather_cache.sql

insert into public.zad_weather_cache (place_key, label, lat, lon, days)
values ('30.06,31.25', 'القاهرة', 30.0626, 31.2497, '[{"date":"2026-10-11","max":30}]');
-- The same place again replaces the row (the function's upsert).
insert into public.zad_weather_cache (place_key, label, lat, lon, days)
values ('30.06,31.25', 'القاهرة', 30.0626, 31.2497, '[]')
on conflict (place_key) do update set days = excluded.days, fetched_at = now();

do $$
declare v_bad text;
begin
  if (select count(*) from public.zad_weather_cache) <> 1 then raise exception 'upsert made two rows'; end if;
  if not (select relrowsecurity from pg_class where oid = 'public.zad_weather_cache'::regclass) then raise exception 'RLS off'; end if;
  if has_table_privilege('authenticated', 'public.zad_weather_cache', 'select')
     or has_table_privilege('anon', 'public.zad_weather_cache', 'select') then
    raise exception 'clients can read the cache';
  end if;
  begin
    insert into public.zad_weather_cache (place_key, label, lat, lon) values ('x', 'y', 91, 0);
    raise exception 'a latitude of 91 was accepted';
  exception when check_violation then null;
  end;
  begin
    insert into public.zad_weather_cache (place_key, label, lat, lon, days) values ('1,1', 'y', 1, 1, '{}');
    raise exception 'days as an object was accepted';
  exception when check_violation then null;
  end;
  raise notice 'weather_cache_test: all passed';
end $$;

rollback;
