-- One definition of the salary cycle.
--
-- zad_cycle_bounds() now answers by calling zad_period_bounds(), the function
-- migration 20260919180000 added. Its own arithmetic is gone. The name stays,
-- with the same signature and the same column names, because
-- zad_budget_state_legacy() calls it and so may a client: this is a change of
-- answer, not of interface.
--
-- WHY. The old body picked the cycle as "this month's anchor, or last month's
-- if we have not reached it yet", then took the end as one month past the
-- start, re-anchored. With `last_working_day` that collapses. Measured on this
-- project before the change, for a payday on the 1st in Saudi Arabia, where
-- 2026-08-01 is a Saturday and the payday walks back to Thursday 2026-07-30:
--
--   asked on    old cycle                 days_left   new period                days_left
--   2026-07-30  [2026-07-01, 2026-07-30)         -1   [2026-07-30, 2026-09-01)         32
--   2026-08-01  [2026-07-30, 2026-07-30)         -3   [2026-07-30, 2026-09-01)         30
--   2026-08-10  [2026-07-30, 2026-07-30)        -12   [2026-07-30, 2026-09-01)         21
--
-- The old range is not merely off by a day. It is **empty** — start equals end
-- — and it stays empty for the rest of the month while days_left falls further
-- every day. Everything downstream inherits that:
--
--   * `spent` and `income` are summed over `created_at >= cycle_start and
--     < cycle_end`, which over an empty range is zero. The customer's spending
--     disappears.
--   * `daily_allowance_left` is `available / days_left`, so a negative
--     days_left returns a negative daily allowance.
--   * `velocity`, and therefore `threat`, are divided by cycle_length_days.
--
-- BLAST RADIUS, measured rather than assumed. Comparing both functions over
-- every day of 2026-2028 × every cycle day 1-31 × EG/SA/TR — 203,856 cases:
--
--   day_of_month       101,928 cases,     0 differ
--   last_working_day   101,928 cases, 1,454 differ  (1.4%)
--
-- Every account on this project today has cycle_anchor = 'day_of_month', and
-- none has a cycle_start_day at all, so all four are on the calendar-month
-- fallback where the two functions have always agreed. **No existing customer's
-- figures move.** This closes a trap before anyone falls into it rather than
-- correcting numbers already shown.
--
-- The ten golden vectors in the Kotlin app's BudgetAuthorityParityTest were
-- re-run against both functions first: all ten pass under either, so that test
-- stays green. The same collapse existed in the Kotlin mirror (CycleMath.kt)
-- and is fixed in the same commit — two implementations of one definition is
-- only safe while a test fails the moment they part company.

create or replace function public.zad_cycle_bounds(
  p_asof date,
  p_cycle_start_day int,
  p_cycle_anchor text,
  p_country text
) returns table (cycle_start date, cycle_end date)
language sql
immutable
set search_path = public
as $$
  select period_start, period_end
    from public.zad_period_bounds(
           p_asof, p_cycle_start_day, p_cycle_anchor, p_country);
$$;

comment on function public.zad_cycle_bounds(date, int, text, text) is
  'The salary cycle containing p_asof. Kept as a thin alias over '
  'zad_period_bounds() so there is one definition; see migration '
  '20260919232941 for the collapse its own arithmetic produced under the '
  'last_working_day anchor.';
