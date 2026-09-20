/// The budget period: the half-open range every screen, query and total in the
/// app agrees on.
///
/// Mirror of `public.zad_period_bounds` and `public.zad_budget_period`, added
/// by the shared project's migration
/// `20260919180000_budget_period_salary_cycle.sql`. The golden cases in
/// `test/core/period/budget_period_test.dart` are the same ones as
/// `supabase/sql/tests/budget_period_test.sql`, and both were taken from the
/// deployed functions rather than written by hand.
///
/// One Flutter import, for `@immutable` alone. The rest of this file is plain
/// Dart on purpose — the period's arithmetic is tested without a widget
/// binding, and nothing here touches a widget.
///
/// Two rules this module exists to enforce:
///
/// * The month is **not** the calendar month. It is the salary cycle. The
///   calendar month is only the fallback when the account has no known payday.
/// * "Today" is taken on the account's market calendar, never in UTC and never
///   on the device's clock. 01:30 on the 1st in Cairo is still the previous
///   month in UTC, which is exactly what `date_trunc('month', CURRENT_DATE)`
///   would get wrong.
library;

import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/core/period/market_calendar.dart';
import 'package:zad/core/period/payday.dart';

/// One account's current budget period.
///
/// Immutable, and it has to be: it carries value equality so that watching it
/// can dedupe, and equality on something that can change underneath its own
/// hash is a bug waiting for a map to be involved.
@immutable
class BudgetPeriod {
  /// Creates a period. Prefer [BudgetPeriod.at], which derives every field.
  const new({
    required this.periodStart,
    required this.periodEnd,
    required this.startsAt,
    required this.endsAt,
    required this.timeZone,
    required this.cycleStartDay,
    required this.anchor,
    required this.isCalendarMonth,
  });

  /// The period containing [at] for an account in [country] paid on
  /// [cycleStartDay].
  ///
  /// [cycleStartDay] is null when no payday is known; the period is then the
  /// calendar month. It is never defaulted to the 1st, which would assert a
  /// payday nobody confirmed.
  ///
  /// Requires the timezone database to be loaded — see `bootstrap()`. Throws if
  /// it is not, which is deliberate: a silently wrong period is worse than a
  /// crash on the first frame.
  factory at({
    required DateTime at,
    required String? country,
    required int? cycleStartDay,
    required CycleAnchor anchor,
  }) {
    final zoneName = marketTimeZone(country);
    final location = tz.getLocation(zoneName);

    final local = tz.TZDateTime.from(at.toUtc(), location);
    final today = DateTime.utc(local.year, local.month, local.day);

    final bounds = periodBounds(
      on: today,
      cycleStartDay: cycleStartDay,
      anchor: anchor,
      country: country,
    );

    return BudgetPeriod(
      periodStart: bounds.start,
      periodEnd: bounds.end,
      startsAt: _midnightInstant(bounds.start, location),
      endsAt: _midnightInstant(bounds.end, location),
      timeZone: zoneName,
      cycleStartDay: cycleStartDay,
      anchor: anchor,
      isCalendarMonth: cycleStartDay == null,
    );
  }

  /// Wraps the civil range the **server** already decided on.
  ///
  /// `zad_budget_state()` reports its own `cycle_start` and `cycle_end`, and
  /// the money it reports is computed against those. Recomputing the range here
  /// and showing the result next to those figures would put two answers to
  /// "how many days left" on one card. So when a snapshot exists its range
  /// wins, and [BudgetPeriod.at] is for the case where there is no snapshot to
  /// defer to.
  ///
  /// `zad_cycle_bounds()`, which the server's budget state calls, is a thin
  /// alias over `zad_period_bounds()` as of migration `20260919232941` — the
  /// same definition this file mirrors. Before that it had its own arithmetic
  /// and collapsed under the `last_working_day` anchor, returning an empty
  /// range for a whole month.
  factory fromServer({
    required DateTime cycleStart,
    required DateTime cycleEnd,
    required String timeZone,
    int? cycleStartDay,
    CycleAnchor anchor = CycleAnchor.dayOfMonth,
  }) {
    final location = tz.getLocation(timeZone);
    final start = DateTime.utc(
      cycleStart.year,
      cycleStart.month,
      cycleStart.day,
    );
    final end = DateTime.utc(cycleEnd.year, cycleEnd.month, cycleEnd.day);

    return BudgetPeriod(
      periodStart: start,
      periodEnd: end,
      startsAt: _midnightInstant(start, location),
      endsAt: _midnightInstant(end, location),
      timeZone: timeZone,
      cycleStartDay: cycleStartDay,
      anchor: anchor,
      // Read off the dates, because `zad_budget_state()` does not report a
      // payday. A range that runs from the 1st to the 1st is a calendar month;
      // anything else is a salary cycle. Inferring this from a null
      // `cycleStartDay` instead — the caller rarely has one to pass — told
      // every user with a payday that they were looking at "this month".
      isCalendarMonth: start.day == 1 && end.day == 1,
    );
  }

  /// First civil date of the period, inclusive. A UTC-midnight `DateTime`
  /// standing for a date, not an instant.
  final DateTime periodStart;

  /// First civil date of the *next* period, exclusive.
  final DateTime periodEnd;

  /// The instant the period opens, inclusive.
  final DateTime startsAt;

  /// The instant the period closes, exclusive — the next payday's local
  /// midnight, not a `23:59:59` fudge.
  final DateTime endsAt;

  /// The IANA zone the civil dates were read on.
  final String timeZone;

  /// The account's payday, or null when none is known.
  final int? cycleStartDay;

  /// How [cycleStartDay] is placed inside its month.
  final CycleAnchor anchor;

  /// Whether this period is a plain calendar month rather than a salary cycle.
  ///
  /// Stored, not derived. [BudgetPeriod.at] knows because it was given the
  /// payday; [BudgetPeriod.fromServer] reads it off the range, because the
  /// server's budget state reports dates and no payday.
  final bool isCalendarMonth;

  /// The period's length in civil days.
  int get totalDays => periodEnd.difference(periodStart).inDays;

  /// Whether [at] falls inside this period.
  ///
  /// This is the comparison every query must use —
  /// `created_at >= starts_at and created_at < ends_at` — a plain range on the
  /// raw instant. Never compare a per-row date cast: it cannot use an index.
  bool contains(DateTime at) {
    final instant = at.toUtc();
    return !instant.isBefore(startsAt) && instant.isBefore(endsAt);
  }

  /// Whole civil days left before the next payday, counted from [at] on the
  /// market calendar. Zero on the last day, never negative inside the period.
  int daysRemainingFrom(DateTime at) {
    final local = tz.TZDateTime.from(at.toUtc(), tz.getLocation(timeZone));
    final today = DateTime.utc(local.year, local.month, local.day);
    return periodEnd.difference(today).inDays - 1;
  }

  /// Value equality.
  ///
  /// A period is a value, not an identity, and without this it behaves like
  /// one: `ref.watch(...select(period))` could never dedupe, so every change to
  /// the budget — including its own background refresh landing — rebuilt
  /// everything keyed on the period and re-read the cache. It also made
  /// `BudgetPeriod` useless as a provider-family key. Both were found by a test
  /// that expected a list to stay confirmed after a successful refresh and
  /// found it marked stale again a moment later.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BudgetPeriod &&
          other.periodStart == periodStart &&
          other.periodEnd == periodEnd &&
          other.timeZone == timeZone &&
          other.cycleStartDay == cycleStartDay &&
          other.anchor == anchor &&
          other.isCalendarMonth == isCalendarMonth;

  @override
  int get hashCode => Object.hash(
    periodStart,
    periodEnd,
    timeZone,
    cycleStartDay,
    anchor,
    isCalendarMonth,
  );

  @override
  String toString() =>
      'BudgetPeriod(${_iso(periodStart)} → ${_iso(periodEnd)} in $timeZone)';
}

/// The civil bounds of the period containing [on]. Mirror of
/// `public.zad_period_bounds`.
///
/// [on] is a civil date; its time part is ignored.
({DateTime start, DateTime end}) periodBounds({
  required DateTime on,
  required int? cycleStartDay,
  required CycleAnchor anchor,
  required String? country,
}) {
  final day = DateTime.utc(on.year, on.month, on.day);

  if (cycleStartDay == null) {
    return (
      start: DateTime.utc(day.year, day.month),
      end: DateTime.utc(day.year, day.month + 1),
    );
  }

  // The previous month through two months ahead. The window has to be this
  // wide because with [CycleAnchor.lastWorkingDay] next month's payday can walk
  // back into this one — the 1st on a Saturday is paid on Thursday the 30th —
  // and from that day the period runs to the payday after it.
  final paydays = <DateTime>[
    for (var k = -1; k <= 2; k++)
      periodPayday(
        year: day.year,
        month: day.month + k,
        day: cycleStartDay,
        anchor: anchor,
        country: country,
      ),
  ];

  // Both sides are always populated: the previous month's payday necessarily
  // precedes any day of this month, and the payday two months out necessarily
  // follows it.
  final start = paydays.where((d) => !d.isAfter(day)).reduce(_later);
  final end = paydays.where((d) => d.isAfter(day)).reduce(_earlier);

  return (start: start, end: end);
}

DateTime _later(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

DateTime _earlier(DateTime a, DateTime b) => a.isBefore(b) ? a : b;

/// Local midnight on [civilDate] in [location], as an instant. Mirror of SQL's
/// `civil_date::timestamp at time zone tz`.
DateTime _midnightInstant(DateTime civilDate, tz.Location location) =>
    tz.TZDateTime(
      location,
      civilDate.year,
      civilDate.month,
      civilDate.day,
    ).toUtc();

String _iso(DateTime d) => d.toIso8601String().split('T').first;
