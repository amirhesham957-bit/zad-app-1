-- «هيخلص» in zad_forecasts (migration 20261026233000, ZAD_PLAN 5.5), on a scratch database:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/forecasts_scaffold.sql
--   psql < supabase/sql/tests/forecast_runs_out_scaffold.sql
--   psql < supabase/migrations/20261026214500_forecast_ledger.sql
--   psql < supabase/migrations/20261026233000_forecast_runs_out.sql
--   psql < supabase/sql/tests/forecast_runs_out_test.sql
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
create or replace function pg_temp.outcome(p text) returns text language sql as $$
  select outcome from public.zad_forecasts where kind = 'runs_out' and subject = p order by made_at desc limit 1 $$;
insert into auth.users values ('00000000-0000-0000-0000-0000000000a1'), ('00000000-0000-0000-0000-0000000000a2');
-- a1's pantry on 1/10: five items running out; a2's state is two days old.
insert into public.zad_home_state values
  ('00000000-0000-0000-0000-0000000000a1', '{"pantry": {"running_out": [
     {"name": "الرز", "days": 2, "approx": false}, {"name": "زيت", "days": 1, "approx": true},
     {"name": "سكر", "days": 0, "approx": true}, {"name": "شاي", "days": 3, "approx": true},
     {"name": "ملح", "days": 2, "approx": true}, {"name": "ملح", "days": 4, "approx": true}]}}', '2026-10-01 06:00Z'),
  ('00000000-0000-0000-0000-0000000000a2', '{"pantry": {"running_out": [{"name": "لبن", "days": 1}]}}', '2026-09-29 06:00Z');
\set QUIET 0

select pg_temp.check(public.zad_forecasts_tick('2026-10-01 07:00Z') ->> 'made_runs_out' = '5',
  'a fresh home state opens one forecast per item (the duplicate at its sooner day), a stale one opens none');
select pg_temp.check((select (predicted, due_at) = (2::numeric, '2026-10-06 07:00Z'::timestamptz) from public.zad_forecasts where subject = 'الرز'),
  'due three days after the predicted day');
select pg_temp.check((select predicted = 2 from public.zad_forecasts where subject = 'ملح'), 'a duplicate item keeps its sooner day');
select pg_temp.check(public.zad_forecasts_tick('2026-10-02 07:00Z') ->> 'made_runs_out' = '0', 'an open item is not opened again');

-- What the house said: rice ran out on day 3 («رز» matches «الرز»), oil was still there after its day,
-- sugar was bought, tea had no answer at all, salt ran out (after a purchase line).
insert into public.zad_inventory_observations (user_id, item_name, qty, observed_at, source) values
  ('00000000-0000-0000-0000-0000000000a1', 'رز', 1, '2026-10-02 20:00Z', 'question_answer'),
  ('00000000-0000-0000-0000-0000000000a1', 'رز', 0, '2026-10-04 07:00Z', 'question_answer'),
  ('00000000-0000-0000-0000-0000000000a1', 'زيت', 1, '2026-10-03 20:00Z', 'question_answer'),
  ('00000000-0000-0000-0000-0000000000a1', 'سكر', 2, '2026-10-02 12:00Z', 'purchase'),
  ('00000000-0000-0000-0000-0000000000a1', 'ملح', 1, '2026-10-02 12:00Z', 'purchase'),
  ('00000000-0000-0000-0000-0000000000a1', 'ملح', 0, '2026-10-03 22:00Z', 'question_answer');

select pg_temp.check(public.zad_forecasts_tick('2026-10-07 07:00Z') ->> 'settled_runs_out' = '5', 'every due item settles');
select pg_temp.check(pg_temp.outcome('الرز') = 'out', 'a zero answer = out');
select pg_temp.check((select actual = 3.0 from public.zad_forecasts where subject = 'الرز'), 'actual = days until it ran out');
select pg_temp.check(pg_temp.outcome('زيت') = 'still_had', 'a quantity after the predicted day = still had it');
select pg_temp.check(pg_temp.outcome('سكر') = 'restocked', 'bought with no answer = restocked');
select pg_temp.check(pg_temp.outcome('شاي') = 'unknown', 'no answer = unknown');
select pg_temp.check(pg_temp.outcome('ملح') = 'out', 'a zero after a purchase line is still out');
select pg_temp.check(public.zad_forecasts_tick('2026-10-07 08:00Z') ->> 'made_runs_out' = '0',
  'the same item is not opened again within 7 days of the last forecast (and the state is now stale)');

select pg_temp.check(public.zad_forecast_accuracy('00000000-0000-0000-0000-0000000000a1', 'runs_out')
  = '{"kind": "runs_out", "out": 2, "judged": 3, "enough": false, "hit_pct": 67, "unknown": 1, "restocked": 1, "still_had": 1, "median_days_off": 0.8}',
  'accuracy: 2 of 3 judged ran out (rice 1 day late, salt 0.6 → median 0.8), restocked and unknown counted apart, 3 < 5 not enough');
select pg_temp.check(public.zad_forecast_accuracy('00000000-0000-0000-0000-0000000000a1') ->> 'weeks' = '0', 'weekly_spend accuracy still reads its own kind');
do $$ begin
  insert into public.zad_forecasts (user_id, kind, made_at, due_at, predicted)
  values ('00000000-0000-0000-0000-0000000000a1', 'runs_out', now(), now() + interval '1 day', 1);
  raise exception 'FAIL: a run-out forecast without an item';
exception when check_violation then raise notice 'ok: a run-out forecast needs an item';
end $$;
