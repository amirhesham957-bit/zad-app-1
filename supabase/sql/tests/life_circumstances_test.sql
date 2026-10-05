-- Life circumstances (migration 20261004150000, docs/agent/ZAD_LIVING_BRAIN.md
-- slice 29), on a scratch database. It builds on travel mode, so both are
-- spliced in at the «@migration» line:
--
--   docker run -d --name zadpg -e POSTGRES_PASSWORD=pg postgres:17-alpine
--   psql() { docker exec -i zadpg psql -U postgres -v ON_ERROR_STOP=1 -q; }
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   cat supabase/migrations/20261003140000_travel_mode.sql supabase/migrations/20261004150000_life_circumstances.sql > /tmp/m.sql
--   sed '/^-- @migration/r /tmp/m.sql' supabase/sql/tests/life_circumstances_test.sql | psql
--
-- A declared a circumstance and travels, B is another account. Raises on the
-- first failed check; each passing one prints "ok:".

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

-- Live shapes (2026-10-03) travel mode builds on.
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
  ('00000000-0000-0000-0000-0000000000b1', 'EGP', 'EG')
  on conflict (id) do update set country = excluded.country;
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

-- The server (zad-brain, set_life_circumstance) writes what the customer said.
insert into zad_life_circumstances (id, user_id, kind, source, ends_at) values
  ('00000000-0000-0000-0000-00000000c001', '00000000-0000-0000-0000-0000000000a1', 'exceptional', 'customer', now() + interval '3 days'),
  ('00000000-0000-0000-0000-00000000c002', '00000000-0000-0000-0000-0000000000a1', 'shift_spending', 'detected', now() + interval '30 days');

-- 1. The table refuses nonsense.
do $$ begin
  begin
    insert into zad_life_circumstances (user_id, kind, source, ends_at)
    values ('00000000-0000-0000-0000-0000000000a1', 'mood', 'customer', now() + interval '1 day');
    raise exception 'FAIL: a made-up kind went in';
  exception when check_violation then raise notice 'ok: only the known kinds';
  end;
  begin
    insert into zad_life_circumstances (user_id, kind, source, started_at, ends_at)
    values ('00000000-0000-0000-0000-0000000000a1', 'exams', 'customer', now(), now() + interval '200 days');
    raise exception 'FAIL: a 200-day circumstance went in';
  exception when check_violation then raise notice 'ok: 120 days at most';
  end;
end $$;

set role authenticated;

-- 2. The owner reads; another account does not; nobody writes from the app.
select pg_temp.who('A');
select pg_temp.check((select count(*) from zad_life_circumstances) = 2, 'the owner reads their circumstances');
select pg_temp.who('B');
select pg_temp.check((select count(*) from zad_life_circumstances) = 0, 'another account reads nothing');
do $$ begin
  insert into zad_life_circumstances (user_id, kind, source, ends_at)
  values ('00000000-0000-0000-0000-0000000000b1', 'exceptional', 'customer', now() + interval '1 day');
  raise exception 'FAIL: the app inserted a circumstance';
exception when insufficient_privilege then raise notice 'ok: the app does not insert';
end $$;

-- 3. «رجّع التنبيهات»: only the owner, only a quiet kind, and it is marked as theirs.
select pg_temp.check((select zad_circumstance_end('00000000-0000-0000-0000-00000000c001')->>'reason') = 'not_found',
  'another account cannot end it');
select pg_temp.who('A');
select pg_temp.check((select zad_circumstance_end('00000000-0000-0000-0000-00000000c002')->>'reason') = 'not_found',
  'a detected shift is not ended from the button');
select pg_temp.check((select (zad_circumstance_end('00000000-0000-0000-0000-00000000c001')->>'ok')::boolean), 'the owner ends it');
select pg_temp.check((select ended_at is not null and ends_at <= now() and (detail->>'ended_by_customer')::boolean
  from zad_life_circumstances where id = '00000000-0000-0000-0000-00000000c001'), 'ended now, by the customer');
select pg_temp.check((select (zad_circumstance_end('00000000-0000-0000-0000-00000000c001')->>'already')::boolean), 'ending twice is fine');

-- 4. Coming home after two days or more records the trip; a short hop does not.
select zad_travel_report('SA');
reset role;
update zad_users set travel_since = now() - interval '5 days' where id = '00000000-0000-0000-0000-0000000000a1';
set role authenticated;
select pg_temp.who('A');
select pg_temp.check((select zad_travel_report('EG')->>'status') = 'home', 'home again');
select pg_temp.check((select count(*) from zad_life_circumstances where kind = 'travel' and detail->>'country' = 'SA'
  and ended_at is not null and started_at <= now() - interval '4 days') = 1, 'the trip is recorded as ended');
select zad_travel_report('AE');
select pg_temp.check((select zad_travel_report('EG')->>'status') = 'home', 'home after a short hop');
select pg_temp.check((select count(*) from zad_life_circumstances where kind = 'travel') = 1, 'a short hop is not a trip');

-- 5. anon has nothing.
reset role;
set role anon;
do $$ begin
  perform 1 from zad_life_circumstances;
  raise exception 'FAIL: anon read circumstances';
exception when insufficient_privilege then raise notice 'ok: anon reads nothing';
end $$;
do $$ begin
  perform zad_circumstance_end('00000000-0000-0000-0000-00000000c001');
  raise exception 'FAIL: anon called the end function';
exception when insufficient_privilege then raise notice 'ok: anon cannot end anything';
end $$;
reset role;
