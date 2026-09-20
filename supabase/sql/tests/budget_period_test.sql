-- Golden cases for zad_period_payday / zad_period_bounds / zad_budget_period
-- (migration 20260919180000_budget_period_salary_cycle.sql).
--
-- The same cases, with the same expected values, are asserted on the client in
-- zad_flutter/test/core/period/budget_period_test.dart. That pairing is the
-- point of this file: the period is computed twice, once in SQL for queries and
-- once in Dart for offline reads, and the two must not drift. Change a case
-- here and you must change it there.
--
-- Read-only. Raises on the first mismatch, prints a count on success:
--   psql "$DATABASE_URL" -f supabase/sql/tests/budget_period_test.sql

\set ON_ERROR_STOP on

do $$
declare
  c        record;
  got      record;
  failures int := 0;
  checked  int := 0;
begin
  ------------------------------------------------------------------ bounds --
  for c in
    select * from (values
      -- No payday known: the calendar month, and never a guessed 1st.
      ('calendar_month_when_no_payday',  date '2026-09-19', null::int, null::text,        'EG', date '2026-09-01', date '2026-10-01'),
      ('calendar_month_first_day',       date '2026-09-01', null,      null,              'EG', date '2026-09-01', date '2026-10-01'),

      -- A plain day-of-month cycle: 31 days here, not "a month".
      ('day25_before_payday',            date '2026-09-19', 25,        'day_of_month',    'EG', date '2026-08-25', date '2026-09-25'),
      -- Payday opens the new period; it never closes the old one.
      ('day25_on_payday',                date '2026-09-25', 25,        'day_of_month',    'EG', date '2026-09-25', date '2026-10-25'),

      -- The 31st clamps to the month's real length.
      ('day31_clamped_to_feb28',         date '2026-02-15', 31,        'day_of_month',    'EG', date '2026-01-31', date '2026-02-28'),
      ('day31_on_clamped_payday',        date '2026-02-28', 31,        'day_of_month',    'EG', date '2026-02-28', date '2026-03-31'),

      -- 2026-08-01 is a Saturday. In Saudi Arabia the payday walks back to
      -- Thursday the 30th of July, so the period opens in July and runs 33 days.
      ('day1_saturday_walks_back_sa',    date '2026-08-05', 1,         'last_working_day','SA', date '2026-07-30', date '2026-09-01'),
      -- The case zad_cycle_bounds() gets wrong: asked on the walked-back payday
      -- itself, the new period must already have started (daysLeft was -1).
      ('day1_on_walked_back_payday_sa',  date '2026-07-30', 1,         'last_working_day','SA', date '2026-07-30', date '2026-09-01'),
      -- The day before it still belongs to July.
      ('day1_day_before_walked_back_sa', date '2026-07-29', 1,         'last_working_day','SA', date '2026-07-01', date '2026-07-30'),

      -- Same date, same anchor, different weekend: 2026-02-01 is a Sunday, a
      -- working day in Riyadh and the weekend in Istanbul.
      ('day1_sunday_no_walk_sa',         date '2026-02-10', 1,         'last_working_day','SA', date '2026-02-01', date '2026-03-01'),
      ('day1_sunday_walks_back_tr',      date '2026-02-10', 1,         'last_working_day','TR', date '2026-01-30', date '2026-02-27'),
      ('day1_saturday_walks_back_tr',    date '2026-08-05', 1,         'last_working_day','TR', date '2026-07-31', date '2026-09-01'),

      -- Year rollover, both directions.
      ('dec_to_jan_year_rollover',       date '2026-12-28', 25,        'day_of_month',    'EG', date '2026-12-25', date '2027-01-25'),
      ('jan_to_dec_year_rollover',       date '2026-01-03', 25,        'day_of_month',    'EG', date '2025-12-25', date '2026-01-25'),

      -- The collapse migration 20260919232941 closed. Asked anywhere in August
      -- with a payday on the 1st in Saudi Arabia, the old zad_cycle_bounds()
      -- returned start = end = 2026-07-30: an empty range that summed no
      -- spending and reported days_left down to -32.
      ('collapse_day_before',            date '2026-07-29', 1,         'last_working_day','SA', date '2026-07-01', date '2026-07-30'),
      ('collapse_on_payday',             date '2026-07-30', 1,         'last_working_day','SA', date '2026-07-30', date '2026-09-01'),
      ('collapse_mid_month',             date '2026-08-10', 1,         'last_working_day','SA', date '2026-07-30', date '2026-09-01'),
      ('collapse_last_day',              date '2026-08-31', 1,         'last_working_day','SA', date '2026-07-30', date '2026-09-01')
    ) as t(id, on_date, day, anchor, country, want_start, want_end)
  loop
    select * into got
      from public.zad_period_bounds(c.on_date, c.day, c.anchor, c.country);

    checked := checked + 1;

    if got.period_start is distinct from c.want_start
       or got.period_end is distinct from c.want_end then
      failures := failures + 1;
      raise warning '% : want [%, %)  got [%, %)',
        c.id, c.want_start, c.want_end, got.period_start, got.period_end;
    end if;
  end loop;

  ------------------------------------------------- "today" on the market ----
  -- Each instant is on the previous day in UTC and on the 1st of September
  -- locally. date_trunc('month', CURRENT_DATE) would put all four in August.
  for c in
    select * from (values
      ('cairo_90_minutes_past_midnight',      timestamptz '2026-08-31 22:30:00+00', 'EG'),
      ('cairo_exactly_midnight',              timestamptz '2026-08-31 21:00:00+00', 'EG'),
      ('riyadh_30_minutes_past_midnight',     timestamptz '2026-08-31 21:30:00+00', 'SA'),
      ('casablanca_30_minutes_past_midnight', timestamptz '2026-08-31 23:30:00+00', 'MA')
    ) as t(id, at_utc, country)
  loop
    checked := checked + 1;

    if (c.at_utc at time zone public.zad_market_timezone(c.country))::date
       <> date '2026-09-01' then
      failures := failures + 1;
      raise warning '% : market date should be 2026-09-01, got %',
        c.id, (c.at_utc at time zone public.zad_market_timezone(c.country))::date;
    end if;

    -- The premise of the case: in UTC it is still August.
    if c.at_utc::date <> date '2026-08-31' then
      failures := failures + 1;
      raise warning '% : case is stale, UTC date is % not 2026-08-31',
        c.id, c.at_utc::date;
    end if;
  end loop;

  ------------------------------------------ civil dates become instants -----
  -- 31 civil days in Cairo is 745 hours when summer time ends inside them, and
  -- 744 in Riyadh, which never shifts. A period stored as a civil range and
  -- compared as one would lose that hour.
  for c in
    select * from (values
      ('eg_october_spans_dst_end', date '2026-10-01', date '2026-11-01', 'Africa/Cairo', 745),
      ('eg_september_flat',        date '2026-09-01', date '2026-10-01', 'Africa/Cairo', 720),
      ('sa_august_no_dst',         date '2026-08-01', date '2026-09-01', 'Asia/Riyadh',  744)
    ) as t(id, ps, pe, tz, want_hours)
  loop
    checked := checked + 1;

    if extract(epoch from (c.pe::timestamp at time zone c.tz)
                        - (c.ps::timestamp at time zone c.tz)) / 3600
       <> c.want_hours then
      failures := failures + 1;
      raise warning '% : want % hours, got %', c.id, c.want_hours,
        extract(epoch from (c.pe::timestamp at time zone c.tz)
                         - (c.ps::timestamp at time zone c.tz)) / 3600;
    end if;
  end loop;

  ------------------------------------------- one definition, two names ------
  -- zad_cycle_bounds() is a thin alias over zad_period_bounds() as of
  -- migration 20260919232941. It is what zad_budget_state_legacy() calls, so a
  -- drift between the two names would be a drift in every money figure.
  for c in
    select * from (values
      (date '2026-08-10', 1,         'last_working_day', 'SA'),
      (date '2026-07-30', 1,         'last_working_day', 'SA'),
      (date '2026-02-10', 1,         'last_working_day', 'TR'),
      (date '2026-09-19', 25,        'day_of_month',     'EG'),
      (date '2026-09-19', null::int, null::text,         'EG')
    ) as t(on_date, day, anchor, country)
  loop
    checked := checked + 1;

    select * into got
      from public.zad_period_bounds(c.on_date, c.day, c.anchor, c.country);

    if not exists (
      select 1 from public.zad_cycle_bounds(c.on_date, c.day, c.anchor, c.country) b
       where b.cycle_start is not distinct from got.period_start
         and b.cycle_end   is not distinct from got.period_end
    ) then
      failures := failures + 1;
      raise warning 'zad_cycle_bounds drifted from zad_period_bounds at % (day %, %, %)',
        c.on_date, c.day, c.anchor, c.country;
    end if;
  end loop;

  if failures > 0 then
    raise exception 'budget_period: % of % checks failed', failures, checked;
  end if;

  raise notice 'budget_period: % checks passed', checked;
end $$;
