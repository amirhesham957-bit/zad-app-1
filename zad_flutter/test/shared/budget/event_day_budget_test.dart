// ميزانية المواعيد — نفس حالات `zad-brain/eventDayBudget_test.ts`.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/features/home/presentation/metrics_duo.dart';
import 'package:zad/shared/budget/domain/event_day_budget.dart';

// +03:00 all year, as the server test's Asia/Riyadh.
DateTime _riyadh(DateTime utc) => utc.toUtc().add(const Duration(hours: 3));

// A Tuesday morning.
final DateTime _now = DateTime.parse('2026-10-06T09:00:00+03:00');

OutingAppointment _o(
  String title,
  String at, {
  String kind = 'personal',
  String recurrence = 'once',
  String status = 'upcoming',
}) => (
  title: title,
  kind: kind,
  startsAt: DateTime.parse(at),
  recurrence: recurrence,
  status: status,
);

EventDayBudget? _budget(
  double spendable,
  int daysLeft,
  List<OutingAppointment> a,
) => eventDayBudget(
  spendable: spendable,
  daysLeft: daysLeft,
  appointments: a,
  now: _now,
  toLocal: _riyadh,
);

void main() {
  test('weights: travel 2, a doctor or an outing 1.5, the rest 1', () {
    expect(eventWeight(_o('سفر إسكندرية', '2026-10-06T10:00:00Z')), 2);
    expect(eventWeight(_o('دكتور الأسنان', '2026-10-06T10:00:00Z')), 1.5);
    expect(
      eventWeight(_o('متابعة', '2026-10-06T10:00:00Z', kind: 'medical')),
      1.5,
    );
    expect(eventWeight(_o('البنك', '2026-10-06T10:00:00Z')), 1);
    expect(
      eventWeight(_o('النادي', '2026-10-06T10:00:00Z', recurrence: 'weekly')),
      1,
    );
    expect(
      eventWeight(_o('دكتور', '2026-10-06T10:00:00Z', status: 'cancelled')),
      1,
    );
  });

  test('a doctor today raises today; the total is unchanged', () {
    final r = _budget(1000, 10, <OutingAppointment>[
      _o('دكتور الأسنان', '2026-10-06T17:00:00+03:00'),
    ])!;
    expect(r.base, 100);
    expect(r.today, 140);
    expect(r.eventTitle, 'دكتور الأسنان');
    expect(r.eventInDays, 0);
    expect(r.today + 6 * (700 / 7.5) + 3 * 100, closeTo(1000, 0.01));
  });

  test('a trip later this week lowers today and names it', () {
    final r = _budget(700, 7, <OutingAppointment>[
      _o('سفر', '2026-10-09T08:00:00+03:00'),
    ])!;
    expect(r.today, 87.5);
    expect(r.eventInDays, 3);
    expect(
      eventDayCaption(r, weekday: DateTime.friday),
      'شايلين حاجة لـ«سفر» يوم الجمعة',
    );
  });

  test('nothing to rebalance', () {
    expect(
      _budget(1000, 10, <OutingAppointment>[
        _o('البنك', '2026-10-06T12:00:00+03:00'),
      ]),
      isNull,
    );
    expect(
      _budget(1000, 10, <OutingAppointment>[
        _o('سفر', '2026-10-14T12:00:00+03:00'),
      ]),
      isNull,
      reason: 'beyond the week',
    );
    expect(
      _budget(0, 10, <OutingAppointment>[
        _o('سفر', '2026-10-06T12:00:00+03:00'),
      ]),
      isNull,
    );
  });

  test('the last two days: the horizon is the cycle', () {
    expect(
      _budget(200, 2, <OutingAppointment>[
        _o('خروجة', '2026-10-06T20:00:00+03:00'),
      ])!.today,
      120,
    );
  });

  testWidgets('the home pair shows the reweighed figure and says why', (
    tester,
  ) async {
    final e = _budget(1000, 10, <OutingAppointment>[
      _o('دكتور الأسنان', '2026-10-06T17:00:00+03:00'),
    ])!;
    await tester.pumpWidget(
      MaterialApp(
        theme: ZadTheme.light(),
        home: Scaffold(
          body: HomeMetricsDuo(
            spendable: 1000,
            daysLeft: 10,
            currency: 'EGP',
            event: (budget: e, caption: eventDayCaption(e, weekday: 2)),
          ),
        ),
      ),
    );
    expect(find.text('140 EGP'), findsOneWidget);
    expect(find.text('زوّدناه عشان «دكتور الأسنان» النهارده'), findsOneWidget);
  });
}
