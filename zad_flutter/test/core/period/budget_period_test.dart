// Golden cases for the budget period.
//
// Every expected value here was read out of the deployed SQL functions
// (`zad_period_bounds`, `zad_market_timezone`, `zad_period_payday`) rather than
// worked out by hand, so this file is a parity check against the server and not
// a restatement of the same assumptions. The identical cases live in
// `supabase/sql/tests/budget_period_test.sql`; change one and you must change
// the other.

import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/core/period/budget_period.dart';
import 'package:zad/core/period/market_calendar.dart';
import 'package:zad/core/period/payday.dart';

typedef _BoundsCase = ({
  String id,
  String on,
  int? day,
  String? anchor,
  String country,
  String start,
  String end,
});

const _boundsCases = <_BoundsCase>[
  // No payday known: the calendar month, and nothing else.
  (
    id: 'calendar_month_when_no_payday',
    on: '2026-09-19',
    day: null,
    anchor: null,
    country: 'EG',
    start: '2026-09-01',
    end: '2026-10-01',
  ),
  (
    id: 'calendar_month_first_day',
    on: '2026-09-01',
    day: null,
    anchor: null,
    country: 'EG',
    start: '2026-09-01',
    end: '2026-10-01',
  ),

  // A plain day-of-month cycle. The period is 31 days here, not a month.
  (
    id: 'day25_before_payday',
    on: '2026-09-19',
    day: 25,
    anchor: 'day_of_month',
    country: 'EG',
    start: '2026-08-25',
    end: '2026-09-25',
  ),
  // Payday itself opens the new period; it never closes the old one.
  (
    id: 'day25_on_payday',
    on: '2026-09-25',
    day: 25,
    anchor: 'day_of_month',
    country: 'EG',
    start: '2026-09-25',
    end: '2026-10-25',
  ),

  // The 31st clamps to the month's real length.
  (
    id: 'day31_clamped_to_feb28',
    on: '2026-02-15',
    day: 31,
    anchor: 'day_of_month',
    country: 'EG',
    start: '2026-01-31',
    end: '2026-02-28',
  ),
  (
    id: 'day31_on_clamped_payday',
    on: '2026-02-28',
    day: 31,
    anchor: 'day_of_month',
    country: 'EG',
    start: '2026-02-28',
    end: '2026-03-31',
  ),

  // 2026-08-01 is a Saturday. In Saudi Arabia (weekend Fri+Sat) the payday
  // walks back to Thursday the 30th of July, so August's period opens in July
  // and runs 33 days, to the 1st of September.
  (
    id: 'day1_saturday_walks_back_sa',
    on: '2026-08-05',
    day: 1,
    anchor: 'last_working_day',
    country: 'SA',
    start: '2026-07-30',
    end: '2026-09-01',
  ),
  // The case `zad_cycle_bounds()` got wrong: asked on the walked-back payday
  // itself, the new period must already have started.
  (
    id: 'day1_on_walked_back_payday_sa',
    on: '2026-07-30',
    day: 1,
    anchor: 'last_working_day',
    country: 'SA',
    start: '2026-07-30',
    end: '2026-09-01',
  ),
  // And the day before it still belongs to July's period.
  (
    id: 'day1_day_before_walked_back_sa',
    on: '2026-07-29',
    day: 1,
    anchor: 'last_working_day',
    country: 'SA',
    start: '2026-07-01',
    end: '2026-07-30',
  ),

  // Same date, same anchor, different weekend. 2026-02-01 is a Sunday: a
  // working day in Riyadh, the weekend in Istanbul.
  (
    id: 'day1_sunday_no_walk_sa',
    on: '2026-02-10',
    day: 1,
    anchor: 'last_working_day',
    country: 'SA',
    start: '2026-02-01',
    end: '2026-03-01',
  ),
  (
    id: 'day1_sunday_walks_back_tr',
    on: '2026-02-10',
    day: 1,
    anchor: 'last_working_day',
    country: 'TR',
    start: '2026-01-30',
    end: '2026-02-27',
  ),
  (
    id: 'day1_saturday_walks_back_tr',
    on: '2026-08-05',
    day: 1,
    anchor: 'last_working_day',
    country: 'TR',
    start: '2026-07-31',
    end: '2026-09-01',
  ),

  // Year rollover in both directions.
  (
    id: 'dec_to_jan_year_rollover',
    on: '2026-12-28',
    day: 25,
    anchor: 'day_of_month',
    country: 'EG',
    start: '2026-12-25',
    end: '2027-01-25',
  ),
  (
    id: 'jan_to_dec_year_rollover',
    on: '2026-01-03',
    day: 25,
    anchor: 'day_of_month',
    country: 'EG',
    start: '2025-12-25',
    end: '2026-01-25',
  ),
];

DateTime _date(String iso) => DateTime.parse('${iso}T00:00:00Z');

void main() {
  setUpAll(tz_data.initializeTimeZones);

  group('periodBounds matches the deployed SQL', () {
    for (final c in _boundsCases) {
      test(c.id, () {
        final bounds = periodBounds(
          on: _date(c.on),
          cycleStartDay: c.day,
          anchor: CycleAnchor.fromWire(c.anchor),
          country: c.country,
        );

        expect(bounds.start, _date(c.start), reason: '${c.id}: period_start');
        expect(bounds.end, _date(c.end), reason: '${c.id}: period_end');
      });
    }
  });

  group('"today" is read on the market calendar, not in UTC', () {
    // Each of these instants is on the previous day in UTC and on the 1st of
    // September locally. `date_trunc('month', CURRENT_DATE)` would put all four
    // in August — this is the bug the salary-cycle period exists to close.
    const cases = <({String id, String at, String country})>[
      (
        id: 'cairo_90_minutes_past_midnight',
        at: '2026-08-31T22:30:00Z',
        country: 'EG',
      ),
      (id: 'cairo_exactly_midnight', at: '2026-08-31T21:00:00Z', country: 'EG'),
      (
        id: 'riyadh_30_minutes_past_midnight',
        at: '2026-08-31T21:30:00Z',
        country: 'SA',
      ),
      (
        id: 'casablanca_30_minutes_past_midnight',
        at: '2026-08-31T23:30:00Z',
        country: 'MA',
      ),
    ];

    for (final c in cases) {
      test(c.id, () {
        final at = DateTime.parse(c.at);
        final period = BudgetPeriod.at(
          at: at,
          country: c.country,
          cycleStartDay: null,
          anchor: CycleAnchor.dayOfMonth,
        );

        expect(period.periodStart, _date('2026-09-01'));
        expect(
          at.toUtc().day,
          31,
          reason: 'the instant really is the 31st in UTC',
        );
      });
    }
  });

  group('civil dates become instants on the market clock', () {
    test('Egypt: the period spanning the end of summer time is 745 hours', () {
      final october = BudgetPeriod.at(
        at: DateTime.parse('2026-10-15T09:00:00Z'),
        country: 'EG',
        cycleStartDay: null,
        anchor: CycleAnchor.dayOfMonth,
      );

      expect(october.startsAt, DateTime.parse('2026-09-30T21:00:00Z'));
      expect(october.endsAt, DateTime.parse('2026-10-31T22:00:00Z'));
      // 31 civil days, but 745 hours: the clock went back one hour inside it.
      expect(october.totalDays, 31);
      expect(october.endsAt.difference(october.startsAt).inHours, 745);
    });

    test('Egypt: a period with no transition is a flat 720 hours', () {
      final september = BudgetPeriod.at(
        at: DateTime.parse('2026-09-15T09:00:00Z'),
        country: 'EG',
        cycleStartDay: null,
        anchor: CycleAnchor.dayOfMonth,
      );

      expect(september.startsAt, DateTime.parse('2026-08-31T21:00:00Z'));
      expect(september.endsAt, DateTime.parse('2026-09-30T21:00:00Z'));
      expect(september.endsAt.difference(september.startsAt).inHours, 720);
    });

    test('Saudi Arabia never shifts, so 31 days is always 744 hours', () {
      final august = BudgetPeriod.at(
        at: DateTime.parse('2026-08-15T09:00:00Z'),
        country: 'SA',
        cycleStartDay: null,
        anchor: CycleAnchor.dayOfMonth,
      );

      expect(august.startsAt, DateTime.parse('2026-07-31T21:00:00Z'));
      expect(august.endsAt, DateTime.parse('2026-08-31T21:00:00Z'));
      expect(august.endsAt.difference(august.startsAt).inHours, 744);
    });
  });

  group('contains() is half-open', () {
    // Built in setUp, not in the group body: group bodies run while tests are
    // being collected, before setUpAll has loaded the timezone database.
    late BudgetPeriod period;

    setUp(() {
      period = BudgetPeriod.at(
        at: DateTime.parse('2026-09-15T09:00:00Z'),
        country: 'EG',
        cycleStartDay: null,
        anchor: CycleAnchor.dayOfMonth,
      );
    });

    test('the opening instant is inside', () {
      expect(period.contains(DateTime.parse('2026-08-31T21:00:00Z')), isTrue);
    });

    test('one microsecond before it is outside', () {
      expect(
        period.contains(DateTime.parse('2026-08-31T20:59:59.999999Z')),
        isFalse,
      );
    });

    test('the closing instant is outside — there is no 23:59:59 edge', () {
      expect(period.contains(DateTime.parse('2026-09-30T21:00:00Z')), isFalse);
      expect(
        period.contains(DateTime.parse('2026-09-30T20:59:59.999999Z')),
        isTrue,
      );
    });
  });

  group('daysRemainingFrom', () {
    test('is zero on the last civil day, not negative', () {
      final period = BudgetPeriod.at(
        at: DateTime.parse('2026-09-30T12:00:00Z'),
        country: 'EG',
        cycleStartDay: null,
        anchor: CycleAnchor.dayOfMonth,
      );

      expect(
        period.daysRemainingFrom(DateTime.parse('2026-09-30T12:00:00Z')),
        0,
      );
    });

    test('never goes negative on a walked-back payday', () {
      // The shape that produced daysLeft = -1 under zad_cycle_bounds().
      final period = BudgetPeriod.at(
        at: DateTime.parse('2026-07-30T09:00:00Z'),
        country: 'SA',
        cycleStartDay: 1,
        anchor: CycleAnchor.lastWorkingDay,
      );

      expect(period.periodStart, _date('2026-07-30'));
      expect(
        period.daysRemainingFrom(DateTime.parse('2026-07-30T09:00:00Z')),
        32,
      );
    });
  });

  group('market calendar', () {
    test('every market zone resolves in the bundled database', () {
      const countries = <String>[
        'SA',
        'EG',
        'AE',
        'KW',
        'QA',
        'BH',
        'OM',
        'JO',
        'LB',
        'IQ',
        'SY',
        'YE',
        'PS',
        'LY',
        'SD',
        'MA',
        'TN',
        'DZ',
        'TR',
      ];

      for (final country in countries) {
        final name = marketTimeZone(country);
        expect(
          () => tz.getLocation(name),
          returnsNormally,
          reason: '$country → $name is missing from the timezone database',
        );
      }
    });

    test(
      'an unknown or null country falls back to UTC, not the device zone',
      () {
        expect(marketTimeZone(null), 'UTC');
        expect(marketTimeZone(''), 'UTC');
        expect(marketTimeZone('ZZ'), 'UTC');
      },
    );

    test('the weekend splits Gulf markets from Maghreb and Turkey', () {
      expect(weekendDows('SA'), <int>{5, 6});
      expect(weekendDows('EG'), <int>{5, 6});
      expect(weekendDows('TR'), <int>{6, 0});
      expect(weekendDows('MA'), <int>{6, 0});
      expect(weekendDows(null), <int>{5, 6});
    });

    test('Dart weekdays map onto Postgres dow numbering', () {
      expect(pgDayOfWeek(_date('2026-08-02')), 0); // Sunday
      expect(pgDayOfWeek(_date('2026-07-31')), 5); // Friday
      expect(pgDayOfWeek(_date('2026-08-01')), 6); // Saturday
    });
  });

  group('an unknown anchor must not walk paydays backwards', () {
    test('it is read as day_of_month', () {
      expect(CycleAnchor.fromWire(null), CycleAnchor.dayOfMonth);
      expect(
        CycleAnchor.fromWire('whatever_ships_next'),
        CycleAnchor.dayOfMonth,
      );
      expect(
        CycleAnchor.fromWire('last_working_day'),
        CycleAnchor.lastWorkingDay,
      );
    });
  });
}
