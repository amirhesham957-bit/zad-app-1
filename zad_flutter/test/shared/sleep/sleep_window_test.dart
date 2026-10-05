// إيقاع النوم (الشريحة ٣٧): نافذة النوم من لحظات قفل/فتح الشاشة.

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/shared/sleep/domain/sleep_window.dart';

// The account's wall clock = UTC+3 (Riyadh), whatever the device's zone.
DateTime _local(DateTime u) {
  final t = u.toUtc().add(const Duration(hours: 3));
  return DateTime(t.year, t.month, t.day, t.hour, t.minute);
}

/// A night: screen off at [off] local on [day], on at [on] local next morning.
List<ScreenEvent> _night(int day, (int, int) off, (int, int) on) {
  DateTime utc(int d, (int, int) hm) => DateTime.utc(
    2026,
    10,
    d,
    hm.$1,
    hm.$2,
  ).subtract(const Duration(hours: 3));
  final offDay = off.$1 < 12 ? day + 1 : day;
  return <ScreenEvent>[
    (on: false, at: utc(offDay, off)),
    (on: true, at: utc(day + 1, on)),
  ];
}

void main() {
  final now = DateTime.utc(2026, 10, 9, 9); // 12:00 Riyadh on the 9th

  test('the median bedtime and wake time across nights, midnight included', () {
    final events = <ScreenEvent>[
      ..._night(4, (23, 30), (7, 0)),
      ..._night(5, (0, 30), (7, 30)),
      ..._night(6, (23, 50), (6, 50)),
      ..._night(7, (23, 40), (7, 10)),
    ];
    final w = learnSleepWindow(events, now, _local)!;
    expect(w.nights, 4);
    expect(w.bed, '23:45');
    expect(w.wake, '07:05');
  });

  test('fewer than three nights, or naps too short, learn nothing', () {
    expect(
      learnSleepWindow(
        <ScreenEvent>[
          ..._night(6, (23, 0), (7, 0)),
          ..._night(7, (23, 0), (7, 0)),
        ],
        now,
        _local,
      ),
      isNull,
    );
    expect(
      learnSleepWindow(
        <ScreenEvent>[
          for (final d in <int>[4, 5, 6, 7]) ..._night(d, (23, 0), (1, 30)),
        ],
        now,
        _local,
      ),
      isNull,
    );
  });

  test('a glance at the phone in the night does not end it', () {
    final glanced = <ScreenEvent>[
      for (final d in <int>[4, 5, 6]) ...<ScreenEvent>[
        ..._night(d, (23, 0), (3, 0)),
        ..._night(d, (3, 5), (7, 0)), // 5 minutes on
      ],
    ];
    final w = learnSleepWindow(glanced, now, _local)!;
    expect((w.bed, w.wake, w.nights), ('23:00', '07:00', 3));
  });

  test('a real wake in the night does end it', () {
    final awake = <ScreenEvent>[
      for (final d in <int>[4, 5, 6]) ...<ScreenEvent>[
        ..._night(d, (23, 0), (3, 0)),
        ..._night(d, (4, 0), (7, 0)), // up for an hour
      ],
    ];
    expect(learnSleepWindow(awake, now, _local)!.wake, '03:00');
  });

  test('a night still going (no «on» yet) is not counted', () {
    final events = <ScreenEvent>[
      for (final d in <int>[5, 6, 7]) ..._night(d, (23, 0), (7, 0)),
      (on: false, at: DateTime.utc(2026, 10, 8, 20)),
    ];
    expect(learnSleepWindow(events, now, _local)!.nights, 3);
  });

  test('hh:mm wraps past midnight', () {
    expect(SleepWindow.hhmm(24 * 60 + 15), '00:15');
    expect(SleepWindow.hhmm(7 * 60 + 5), '07:05');
  });
}
