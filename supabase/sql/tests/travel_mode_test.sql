-- Travel mode (migration 20261003140000, docs/agent/ZAD_LIVING_BRAIN.md slice 6),
-- on a scratch database. The file adds the live shapes the migration builds on,
-- then the migration is spliced in at the «@migration» line:
--
--   docker run -d --name zadpg -e POSTGRES_PASSWORD=pg postgres:17-alpine
--   psql() { docker exec -i zadpg psql -U postgres -v ON_ERROR_STOP=1 -q; }
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   sed '/^-- @migration/r supabase/migrations/20261003140000_travel_mode.sql' \
--     supabase/sql/tests/travel_mode_test.sql | psql
--
-- U travels, H has no market chosen. Raises on the first failed check.

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

-- Live shapes (2026-10-03) the migration builds on.
alter table public.zad_users add column if not exists country text;
create table if not exists public.zad_voice_moments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  moment text not null,
  facts jsonb not null default '{}'::jsonb,
  dedupe_key text not null,
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  unique (user_id, dedupe_key)
);

-- @migration

\set QUIET 1
insert into auth.users values ('00000000-0000-0000-0000-0000000000a1'), ('00000000-0000-0000-0000-0000000000b1') on conflict do nothing;
insert into public.zad_users (id, currency, country) values
  ('00000000-0000-0000-0000-0000000000a1', 'EGP', 'EG'),
  ('00000000-0000-0000-0000-0000000000b1', 'EGP', null)
  on conflict (id) do update set country = excluded.country;
create or replace function pg_temp.who(p text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', case p
    when 'U' then '00000000-0000-0000-0000-0000000000a1' when 'H' then '00000000-0000-0000-0000-0000000000b1' end,
    'role', 'authenticated')::text, false);
end $$;
create or replace function pg_temp.check(cond boolean, label text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAIL: %', label; end if; raise notice 'ok: %', label; end $$;
grant execute on function pg_temp.who(text) to authenticated;
grant execute on function pg_temp.check(boolean, text) to authenticated;
\set QUIET 0

set role authenticated;
select pg_temp.who('U');
select pg_temp.check(zad_travel_report('EG') ->> 'status' = 'home', 'home country is home');
select pg_temp.check(zad_travel_report('ae') ->> 'status' = 'arrived', 'a new country is an arrival (any case)');
select pg_temp.check(zad_travel_report('AE') ->> 'status' = 'away', 'the same country again is not a second arrival');
select pg_temp.check(zad_travel_report('Dubai') ->> 'status' = 'home', 'not a country code: treated as unknown, trip cleared');
select pg_temp.check(zad_travel_report('AE') ->> 'status' = 'arrived', 'back to AE after that');
reset role;
select pg_temp.check((select count(*) from zad_voice_moments where moment = 'travel_arrived') = 1, 'one welcome per country per day');
select pg_temp.check((select facts ->> 'home_country' from zad_voice_moments where moment = 'travel_arrived') = 'EG', 'the moment knows home');
select pg_temp.check((select country = 'EG' and travel_country = 'AE' from zad_users where id = '00000000-0000-0000-0000-0000000000a1'), 'the market is untouched; the trip is beside it');
set role authenticated;
select pg_temp.who('U');
select pg_temp.check(zad_travel_report('TR') ->> 'status' = 'arrived', 'a third country is a new arrival');
select pg_temp.check(zad_travel_report('EG') ->> 'status' = 'home', 'coming home clears the trip');
reset role;
select pg_temp.check((select travel_country is null and travel_since is null from zad_users where id = '00000000-0000-0000-0000-0000000000a1'), 'nothing left of the trip');
set role authenticated;
select pg_temp.who('H');
select pg_temp.check(zad_travel_report('AE') ->> 'reason' = 'no_home_market', 'no market chosen: no idea what abroad means');
reset role;
select pg_temp.check(not has_function_privilege('anon', 'public.zad_travel_report(text)', 'EXECUTE'), 'anon cannot report a trip');
