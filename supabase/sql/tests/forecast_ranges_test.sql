-- P3.5 (migration 20261128220000): نطاق كل توقع + قفل تلقائي بالفعلي + تغطية النطاق، على scratch database:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/forecasts_scaffold.sql
--   psql < supabase/sql/tests/forecast_runs_out_scaffold.sql
--   psql < supabase/migrations/20261026214500_forecast_ledger.sql
--   psql < supabase/migrations/20261026233000_forecast_runs_out.sql
--   psql < supabase/migrations/20261128240000_forecast_ranges.sql
--   psql < supabase/sql/tests/forecast_ranges_test.sql

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

\set QUIET 1
create or replace function pg_temp.check(cond boolean, label text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAIL: %', label; end if; raise notice 'ok: %', label; end $$;
\set a1 '''00000000-0000-0000-0000-0000000000a1'''
\set a2 '''00000000-0000-0000-0000-0000000000a2'''
\set a3 '''00000000-0000-0000-0000-0000000000a3'''
insert into auth.users values (:a1), (:a2), (:a3);
insert into public.user_behavior_profile values (:a1, 1000, '2026-10-01 23:00Z'), (:a2, 500, '2026-10-01 23:00Z');
-- a1: 5 evidence weeks (800..1200); a2: only 2 weeks, so no range.
insert into public.zad_forecasts (user_id, kind, made_at, due_at, predicted, actual, recorded, settled_at) values
  (:a1, 'weekly_spend', '2026-08-01', '2026-08-08', 1000, 800, 5, '2026-08-08'),
  (:a1, 'weekly_spend', '2026-08-08', '2026-08-15', 1000, 900, 5, '2026-08-15'),
  (:a1, 'weekly_spend', '2026-08-15', '2026-08-22', 1000, 1000, 5, '2026-08-22'),
  (:a1, 'weekly_spend', '2026-08-22', '2026-08-29', 1000, 1100, 5, '2026-08-29'),
  (:a1, 'weekly_spend', '2026-08-29', '2026-09-05', 1000, 1200, 5, '2026-09-05'),
  (:a2, 'weekly_spend', '2026-08-01', '2026-08-08', 500, 400, 5, '2026-08-08'),
  (:a2, 'weekly_spend', '2026-08-08', '2026-08-15', 500, 600, 5, '2026-08-15');
-- a3: 5 judged run-outs, each 1 day late, plus a pantry that now says rice runs out in 2 days; a2 has the same pantry but no history.
insert into public.zad_forecasts (user_id, kind, subject, made_at, due_at, predicted, actual, recorded, outcome, settled_at)
select :a3, 'runs_out', 'صنف' || i, '2026-08-01'::timestamptz + (i || ' days')::interval, '2026-08-10'::timestamptz + (i || ' days')::interval, 2, 3, 1, 'out', '2026-08-10'::timestamptz + (i || ' days')::interval
  from generate_series(1, 5) i;
insert into public.zad_home_state values
  (:a3, '{"pantry": {"running_out": [{"name": "الرز", "days": 2, "approx": false}]}}', '2026-10-01 06:00Z'),
  (:a2, '{"pantry": {"running_out": [{"name": "زيت", "days": 2, "approx": false}]}}', '2026-10-01 06:00Z');
\set QUIET 0

select public.zad_forecasts_tick('2026-10-02 00:00Z');

-- ── النطاق عند الفتح ──
select pg_temp.check((select (low, high) = (880::numeric, 1120::numeric) from public.zad_forecasts where user_id = :a1 and kind = 'weekly_spend' and settled_at is null),
  'weekly range = p20..p80 of the last 5 evidence weeks (880..1120), predicted 1000 inside');
select pg_temp.check((select range_basis like 'p20-p80 of 5%' from public.zad_forecasts where user_id = :a1 and kind = 'weekly_spend' and settled_at is null), 'range has its basis');
select pg_temp.check((select low is null and high is null and range_basis is null from public.zad_forecasts where user_id = :a2 and kind = 'weekly_spend' and settled_at is null),
  'fewer than 4 evidence weeks = no invented range');
select pg_temp.check((select (low, high) = (1::numeric, 3::numeric) from public.zad_forecasts where user_id = :a3 and kind = 'runs_out' and settled_at is null),
  'run-out range = predicted 2 +/- median miss 1 day (from 5 judged)');
select pg_temp.check((select low is null from public.zad_forecasts where user_id = :a2 and kind = 'runs_out' and settled_at is null), 'run-out with < 5 judged = no range');
select pg_temp.check((select count(*) = 0 from public.zad_forecasts where low is not null and in_range is not null and settled_at is null), 'open forecasts have no in_range yet');

-- ── القفل التلقائي بالفعلي ──
-- أسبوع a1: ٣ مصاريف ٩٥٠ (جوه النطاق).
insert into public.zad_transactions (user_id, amount, is_expense, created_at) values
  (:a1, 300, true, '2026-10-03 10:00Z'), (:a1, 350, true, '2026-10-05 10:00Z'), (:a1, 300, true, '2026-10-07 10:00Z');
-- رز a3 خلص بعد ٢٫٣ يوم (جوه ١..٣)
insert into public.zad_inventory_observations (user_id, item_name, qty, observed_at, source) values (:a3, 'رز', 0, '2026-10-04 06:00Z', 'question_answer');
select pg_temp.check(public.zad_forecasts_tick('2026-10-10 00:00Z') ->> 'settled' = '2', 'both weekly forecasts settle on their own (a1 with data, a2 silent)');
select pg_temp.check((select in_range from public.zad_forecasts where user_id = :a1 and kind = 'weekly_spend' and actual = 950), 'actual 950 inside 880..1120 = in_range true');
select pg_temp.check((select in_range is null from public.zad_forecasts where user_id = :a2 and kind = 'weekly_spend' and recorded = 0), 'a silent week (recorded 0) is not judged');
select pg_temp.check((select in_range from public.zad_forecasts where user_id = :a3 and subject = 'الرز'), 'rice ran out after 2.3 days (predicted 2, range 1..3) = in_range true');

-- أسبوع a1 التاني: ٤ مصاريف ٢٠٠٠ (برا النطاق)
insert into public.zad_transactions (user_id, amount, is_expense, created_at) values
  (:a1, 500, true, '2026-10-11 10:00Z'), (:a1, 500, true, '2026-10-12 10:00Z'), (:a1, 500, true, '2026-10-13 10:00Z'), (:a1, 500, true, '2026-10-14 10:00Z');
update public.user_behavior_profile set last_updated_at = '2026-10-16 23:00Z' where user_id = :a1;
select public.zad_forecasts_tick('2026-10-18 00:00Z');
select pg_temp.check((select in_range = false from public.zad_forecasts where user_id = :a1 and kind = 'weekly_spend' and actual = 2000), 'actual 2000 outside the range = in_range false');

-- ── التغطية ──
select pg_temp.check(public.zad_forecast_range_coverage('2026-10-18 00:00Z', 90) -> 'weekly_spend' @> '{"judged": 2, "covered": 1, "coverage_pct": 50, "nominal_pct": 60, "enough": false}',
  'coverage: 1 of 2 judged weeks inside, nominal 60, not enough (< 5)');
select pg_temp.check(public.zad_forecast_range_coverage('2026-10-18 00:00Z', 90) -> 'runs_out' ->> 'nominal_pct' = '50', 'run-out nominal is 50');

-- ── قيود ──
do $$ begin
  insert into public.zad_forecasts (user_id, kind, made_at, due_at, predicted, low, high, range_basis)
  values ('00000000-0000-0000-0000-0000000000a3', 'weekly_spend', now(), now() + interval '1 day', 5, 9, 3, 'x');
  raise exception 'FAIL: low > high accepted';
exception when check_violation then raise notice 'ok: low > high refused'; end $$;
do $$ begin
  insert into public.zad_forecasts (user_id, kind, made_at, due_at, predicted, low, high)
  values ('00000000-0000-0000-0000-0000000000a3', 'weekly_spend', now(), now() + interval '1 day', 5, 1, 9);
  raise exception 'FAIL: a range without its basis accepted';
exception when check_violation then raise notice 'ok: a range needs its basis'; end $$;
