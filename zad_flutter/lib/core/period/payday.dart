/// Mirror of `public.zad_period_payday`, added by the shared project's
/// migration `20260919180000_budget_period_salary_cycle.sql`.
library;

import 'dart:math' as math;

import 'package:zad/core/period/market_calendar.dart';

/// How `zad_users.cycle_anchor` places the payday inside its month.
enum CycleAnchor {
  /// The same numbered day every month, clamped to the month's real length.
  dayOfMonth('day_of_month'),

  /// As [dayOfMonth], then walked backwards off the market's weekend.
  lastWorkingDay('last_working_day');

  new(this.wireName);

  /// The value stored in `zad_users.cycle_anchor`.
  final String wireName;

  /// Reads the column's value.
  ///
  /// Anything other than the exact string `last_working_day` becomes
  /// [dayOfMonth], because that is the only value the SQL branches on. An
  /// anchor this client has not been taught must not silently start walking
  /// paydays backwards.
  static CycleAnchor fromWire(String? value) =>
      value == lastWorkingDay.wireName ? lastWorkingDay : dayOfMonth;
}

/// The payday belonging to ([year], [month]).
///
/// [month] may fall outside 1..12 and rolls over into the neighbouring year,
/// which is how `periodBounds` asks for an adjacent month's payday. Dart's
/// `DateTime` normalises it the same way Postgres's
/// `make_interval(months => …)` does.
///
/// [day] is clamped to the month's real length first, so a cycle anchored on
/// the 31st pays on the 28th in February.
///
/// The result is a **civil date**, carried as a UTC-midnight `DateTime`. It is
/// not an instant and means nothing until `BudgetPeriod` anchors it to a
/// market timezone. UTC is used only because arithmetic on it has no DST to
/// trip over.
DateTime periodPayday({
  required int year,
  required int month,
  required int day,
  required CycleAnchor anchor,
  required String? country,
}) {
  final firstOfMonth = DateTime.utc(year, month);
  // Day zero of the following month is the last day of this one.
  final lastDayOfMonth = DateTime.utc(
    firstOfMonth.year,
    firstOfMonth.month + 1,
    0,
  ).day;

  var payday = DateTime.utc(
    firstOfMonth.year,
    firstOfMonth.month,
    math.min(day, lastDayOfMonth),
  );

  if (anchor == CycleAnchor.lastWorkingDay) {
    final weekend = weekendDows(country);
    // Walks into the previous month when it has to: the 1st on a Saturday is
    // paid on Thursday the 30th.
    while (weekend.contains(pgDayOfWeek(payday))) {
      payday = payday.subtract(const Duration(days: 1));
    }
  }

  return payday;
}
