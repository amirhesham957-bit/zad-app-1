-- zad_forecasts (migration 20261026214500, ZAD_PLAN 5.5), on a scratch database:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/forecasts_scaffold.sql
--   psql < supabase/migrations/20261026214500_forecast_ledger.sql
--   psql < supabase/sql/tests/forecasts_test.sql
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
-- a1: fresh profile; a2: stale profile (20 days); a3: fresh profile, records nothing.
insert into auth.users values
  ('00000000-0000-0000-0000-0000000000a1'), ('00000000-0000-0000-0000-0000000000a2'), ('00000000-0000-0000-0000-0000000000a3');
insert into public.user_behavior_profile values
  ('00000000-0000-0000-0000-0000000000a1', 1000, '2026-10-01 23:00Z'),
  ('00000000-0000-0000-0000-0000000000a2', 500, '2026-09-12 23:00Z'),
  ('00000000-0000-0000-0000-0000000000a3', 300, '2026-10-01 23:00Z');
\set QUIET 0

select pg_temp.check(public.zad_forecasts_tick('2026-10-02 00:00Z') @> '{"made": 2, "settled": 0}', 'fresh profiles open a forecast, the stale one does not');
select pg_temp.check(public.zad_forecasts_tick('2026-10-03 00:00Z') @> '{"made": 0, "settled": 0}', 'one open forecast per home: the next day opens nothing');

-- a1's week: 700 spent, an income and a purchase after the week do not count.
insert into public.zad_transactions (user_id, amount, is_expense, created_at) values
  ('00000000-0000-0000-0000-0000000000a1', 400, true, '2026-10-03 10:00Z'),
  ('00000000-0000-0000-0000-0000000000a1', 300, true, '2026-10-08 10:00Z'),
  ('00000000-0000-0000-0000-0000000000a1', 9000, false, '2026-10-05 10:00Z'),
  ('00000000-0000-0000-0000-0000000000a1', 50, true, '2026-10-09 01:00Z');

select pg_temp.check(public.zad_forecasts_tick('2026-10-09 00:00Z') @> '{"made": 2, "settled": 2}', 'due forecasts settle, then the next week opens');
select pg_temp.check((select (actual, recorded) = (700::numeric, 2) from public.zad_forecasts
  where user_id = '00000000-0000-0000-0000-0000000000a1' and settled_at is not null), 'actual = expenses inside the week only');
select pg_temp.check((select (actual, recorded) = (0::numeric, 0) from public.zad_forecasts
  where user_id = '00000000-0000-0000-0000-0000000000a3' and settled_at is not null), 'a silent week settles at recorded 0');

-- Two more weeks for a1: 1100 (10% off) and 2000 (50% off).
insert into public.zad_transactions (user_id, amount, is_expense, created_at) values
  ('00000000-0000-0000-0000-0000000000a1', 1050, true, '2026-10-12 10:00Z'),
  ('00000000-0000-0000-0000-0000000000a1', 2000, true, '2026-10-20 10:00Z');
-- update-behavior-profile refreshes a1 every night; a3's profile goes stale and stops forecasting.
update public.user_behavior_profile set last_updated_at = '2026-10-15 23:00Z' where user_id = '00000000-0000-0000-0000-0000000000a1';
select pg_temp.check(public.zad_forecasts_tick('2026-10-16 00:00Z') @> '{"made": 1, "settled": 2}', 'a stale profile stops opening forecasts');
select pg_temp.check(public.zad_forecast_accuracy('00000000-0000-0000-0000-0000000000a1') is not null, 'server-side SQL (cron, no JWT) reads accuracy');
select set_config('request.jwt.claims', '{"role": "anon"}', false);
select pg_temp.check(public.zad_forecast_accuracy('00000000-0000-0000-0000-0000000000a1') is null, 'an anonymous request reads nothing');
select pg_temp.who('00000000-0000-0000-0000-0000000000a1');
select pg_temp.check(not (public.zad_forecast_accuracy('00000000-0000-0000-0000-0000000000a1') ->> 'enough')::boolean, 'two weeks are not enough to state accuracy');
reset role;
select set_config('request.jwt.claims', '{}', false);
select public.zad_forecasts_tick('2026-10-23 00:00Z');

select pg_temp.who('00000000-0000-0000-0000-0000000000a1');
set role authenticated;
select pg_temp.check(public.zad_forecast_accuracy('00000000-0000-0000-0000-0000000000a1')
  = '{"kind": "weekly_spend", "weeks": 3, "enough": true, "median_error_pct": 43, "within_25pct": 1, "skipped_unrecorded": 0}',
  'accuracy: 3 weeks, median error 43% of what was spent (700→43%, 1100→9%, 2000→50%), 1 within 25%');
select pg_temp.check(public.zad_forecast_accuracy('00000000-0000-0000-0000-0000000000a3') is null, 'a customer cannot read another home''s accuracy');
select pg_temp.check((select count(*) from public.zad_forecasts) = 4, 'a customer sees only their own forecasts');
do $$ begin
  insert into public.zad_forecasts (user_id, kind, made_at, due_at, predicted)
  values ('00000000-0000-0000-0000-0000000000a1', 'weekly_spend', now(), now() + interval '7 days', 1);
  raise exception 'FAIL: a customer wrote a forecast';
exception when insufficient_privilege then raise notice 'ok: customers cannot write forecasts';
end $$;
do $$ begin
  perform public.zad_forecasts_tick();
  raise exception 'FAIL: a customer ran the tick';
exception when insufficient_privilege then raise notice 'ok: customers cannot run the tick';
end $$;
reset role;
