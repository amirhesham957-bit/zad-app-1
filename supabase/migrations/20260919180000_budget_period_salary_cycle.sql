-- Budget period for the Flutter app (seam1010x-lab/zad-flutter). Source of truth:
-- zad-flutter supabase/sql/budget_period.sql @ fdbedb49, with its golden tests and a
-- Dart↔SQL parity check (140,288 period bounds for 2026-2028, identical). Adds three
-- functions; changes no table, policy, or existing function — zad_cycle_bounds() and
-- zad_budget_state() are untouched, and the Kotlin app keeps using them.
--
-- Budget period: the half-open range [period_start, period_end) of civil dates on
-- the account's market calendar, and the same range as instants [starts_at, ends_at).
--
-- period_end is the next payday — the first day of the *next* period — so a
-- transaction belongs to the period exactly when
--     created_at >= starts_at and created_at < ends_at
-- a plain range on the raw timestamptz column: index-friendly, DST-correct, and
-- with no "23:59:59" edge. Never compare `(created_at at time zone tz)::date`;
-- that computes per row and cannot use an index.
--
-- "Today" is taken in the account's market timezone (zad_market_timezone), never
-- the database's: this project runs in UTC, and 01:30 on the 1st in Cairo is
-- still the previous month in UTC.
--
-- Mirror: lib/core/period/budget_period.dart. Golden cases in
-- tests/budget_period_test.sql are the same as the Dart ones.
--
-- Depends on zad_market_timezone(text) and zad_weekend_dows(text), which already
-- exist in the shared project (zad-app migration 20260809120000).
--

-- The payday that belongs to (p_year, p_month). p_month may run past 1..12 and
-- rolls over. Clamped to the month's real length, then walked back off the
-- market's weekend when the anchor is last_working_day.
create or replace function public.zad_period_payday(
  p_year int, p_month int, p_day int, p_anchor text, p_country text
) returns date
language plpgsql immutable set search_path = public as $$
declare
  v_first date := (make_date(p_year, 1, 1) + make_interval(months => p_month - 1))::date;
  v_last  int  := extract(day from v_first + interval '1 month - 1 day')::int;
  v_date  date := v_first + (least(p_day, v_last) - 1);
begin
  if p_anchor = 'last_working_day' then
    while extract(dow from v_date)::int = any (public.zad_weekend_dows(p_country)) loop
      v_date := v_date - 1;
    end loop;
  end if;
  return v_date;
end;
$$;

-- The period containing p_on. No payday known (null) = the calendar month; it is
-- never defaulted to the 1st, which would assert a payday nobody confirmed.
--
-- Paydays of the previous month through two months ahead are considered: with
-- last_working_day, next month's payday can walk back into this month (the 1st
-- on a Saturday is paid on Thursday the 30th), and from that day on the period
-- runs to the payday after it. zad_cycle_bounds() does not handle that case.
create or replace function public.zad_period_bounds(
  p_on date, p_cycle_start_day int, p_cycle_anchor text, p_country text
) returns table (period_start date, period_end date)
language sql immutable set search_path = public as $$
  with paydays as (
    select public.zad_period_payday(
             extract(year from p_on)::int, extract(month from p_on)::int + k,
             p_cycle_start_day, p_cycle_anchor, p_country) as day
      from generate_series(-1, 2) as k
     where p_cycle_start_day is not null
  )
  select date_trunc('month', p_on)::date,
         (date_trunc('month', p_on) + interval '1 month')::date
   where p_cycle_start_day is null
  union all
  select (select max(day) from paydays where day <= p_on),
         (select min(day) from paydays where day >  p_on)
   where p_cycle_start_day is not null;
$$;

-- The caller's current budget period (or p_user's, for the service role).
--
-- Not security definer: zad_users is read through the caller's own RLS, so this
-- answers only for the caller themself or a child in a family they administer.
-- An account the caller cannot see returns no row — never a guessed period.
create or replace function public.zad_budget_period(
  p_at timestamptz default now(),
  p_user uuid default auth.uid()
) returns table (
  period_start      date,
  period_end        date,
  starts_at         timestamptz,
  ends_at           timestamptz,
  time_zone         text,
  cycle_start_day   int,
  cycle_anchor      text,
  is_calendar_month boolean
)
language sql stable set search_path = public as $$
  select b.period_start,
         b.period_end,
         b.period_start::timestamp at time zone tz.name,
         b.period_end::timestamp   at time zone tz.name,
         tz.name,
         u.cycle_start_day,
         u.cycle_anchor,
         u.cycle_start_day is null
    from public.zad_users u
   cross join lateral (select public.zad_market_timezone(u.country) as name) tz
   cross join lateral public.zad_period_bounds(
           (p_at at time zone tz.name)::date,
           u.cycle_start_day, u.cycle_anchor, u.country) b
   where u.id = p_user;
$$;

grant execute on function public.zad_period_payday(int, int, int, text, text) to authenticated, service_role;
grant execute on function public.zad_period_bounds(date, int, text, text)     to authenticated, service_role;
grant execute on function public.zad_budget_period(timestamptz, uuid)          to authenticated, service_role;
