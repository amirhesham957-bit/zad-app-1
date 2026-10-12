-- رسالة التحويل الأسبوعية (20261012060000) on a scratch database:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/ad_reward_scaffold.sql
--   psql < supabase/migrations/20261012060000_ad_week_nudge.sql
--   psql < supabase/sql/tests/ad_week_nudge_test.sql

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

\set QUIET 1
alter table public.zad_entitlements add column if not exists tier_expires_at timestamptz;
insert into auth.users (id) values ('00000000-0000-0000-0000-0000000000a1'), ('00000000-0000-0000-0000-0000000000b1') on conflict do nothing;
create table if not exists results (n int, ok boolean, note text);
grant all on results to authenticated;
create or replace function pg_temp.check(n int, ok boolean, note text default '') returns void language sql as $$
  insert into results values (n, coalesce(ok, false), note) $$;
create table if not exists s (k text primary key, v jsonb);
grant all on s to authenticated;
create or replace function pg_temp.as_user(id text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', id, 'role', 'authenticated')::text, false) $$;

-- A: four ads this week, two last month.
insert into zad_ad_grants (user_id, granted_at)
select '00000000-0000-0000-0000-0000000000a1', now() - (g || ' hours')::interval from generate_series(1, 4) g;
insert into zad_ad_grants (user_id, granted_at)
select '00000000-0000-0000-0000-0000000000a1', now() - interval '30 days' from generate_series(1, 2);

select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1'); set role authenticated;
insert into s select 'a1', zad_ad_week_status();
reset role;
select pg_temp.check(1, v = '{"show": false, "ads": 4, "minutes": 2}'::jsonb, v::text) from s where k = 'a1';

-- Fifteen this week: shown, ~8 minutes.
insert into zad_ad_grants (user_id, granted_at)
select '00000000-0000-0000-0000-0000000000a1', now() - (g || ' minutes')::interval from generate_series(1, 11) g;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1'); set role authenticated;
insert into s select 'a2', zad_ad_week_status();
select zad_ad_week_seen();
insert into s select 'a3', zad_ad_week_status();
reset role;
select pg_temp.check(2, v = '{"show": true, "ads": 15, "minutes": 8}'::jsonb, v::text) from s where k = 'a2';
select pg_temp.check(3, (v->>'show')::boolean = false, 'once a week') from s where k = 'a3';

-- A week later it may show again.
update zad_ad_week_nudge set shown_at = now() - interval '8 days';
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1'); set role authenticated;
insert into s select 'a4', zad_ad_week_status();
reset role;
select pg_temp.check(4, (v->>'show')::boolean, v::text) from s where k = 'a4';

-- A subscriber never sees it.
insert into zad_entitlements (user_id, tier, tier_expires_at) values ('00000000-0000-0000-0000-0000000000a1', 'plus', now() + interval '10 days')
on conflict (user_id) do update set tier = 'plus', tier_expires_at = now() + interval '10 days';
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1'); set role authenticated;
insert into s select 'a5', zad_ad_week_status();
reset role;
select pg_temp.check(5, (v->>'show')::boolean = false, v::text) from s where k = 'a5';

-- B sees only its own ads; signed out is refused; the table is not readable.
select pg_temp.as_user('00000000-0000-0000-0000-0000000000b1'); set role authenticated;
insert into s select 'b1', zad_ad_week_status();
do $$ begin perform count(*) from zad_ad_week_nudge; perform pg_temp.check(7, false, 'table readable');
exception when insufficient_privilege then perform pg_temp.check(7, true); end $$;
reset role;
select pg_temp.check(6, (v->>'ads')::int = 0, v::text) from s where k = 'b1';
select set_config('request.jwt.claims', '{}', false);
do $$ begin perform zad_ad_week_status(); perform pg_temp.check(8, false, 'signed out');
exception when insufficient_privilege then perform pg_temp.check(8, true); end $$;

\set QUIET 0
select n, ok, note from results order by n;
do $$ declare bad int; total int; begin
  select count(*) filter (where not ok), count(*) into bad, total from results;
  if bad > 0 then raise exception '% of % ad week checks failed', bad, total; end if;
  raise notice 'all % ad week checks passed', total;
end $$;
