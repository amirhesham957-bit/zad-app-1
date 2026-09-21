// Dose times, and the moments they land on.
//
// This file exists to keep the client agreeing with `zad_enqueue_missed_doses`.
// The cron decides when to nudge; these rules decide what the screen says is
// due. When they drift, the app either asks about a dose the server has
// already counted or stays quiet through one it is shouting about — and
// nothing in the build says so.
//
// The zone is the account's market zone, never the device's. Every test here
// passes it explicitly for that reason.

import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:zad/features/pharmacy/domain/dose_slot.dart';
import 'package:zad/features/pharmacy/domain/dose_time.dart';
import 'package:zad/features/pharmacy/domain/medicine.dart';

Medicine medicine({
  String? doseTimes = '08:00,20:00',
  int? remaining = 30,
  bool invalidFlag = false,
}) => Medicine(
  id: 'm-1',
  userId: 'user-1',
  name: 'كونكور',
  doseTimesRaw: doseTimes,
  remainingQuantity: remaining,
  serverSaysInvalidDoseTime: invalidFlag,
);

void main() {
  setUpAll(tz_data.initializeTimeZones);

  group('reading a dose time', () {
    test('takes the forms the server takes', () {
      expect(DoseTime.parse('08:00'), const DoseTime(8, 0));
      // The regex allows a single-digit hour, so the column may hold one.
      expect(DoseTime.parse('8:00'), const DoseTime(8, 0));
      expect(DoseTime.parse('23:59'), const DoseTime(23, 59));
      expect(DoseTime.parse('00:00'), const DoseTime(0, 0));
      expect(DoseTime.parse(' 16:30 '), const DoseTime(16, 30));
    });

    test('rejects 24:00, because midnight is 00:00', () {
      // The SQL hour class is `2[0-3]`, and the agent prompt says "ممنوع
      // 24:00" for the same reason. A row carrying it is skipped by the cron,
      // so quietly reading it as midnight would show a dose nothing will ever
      // remind anybody about.
      expect(DoseTime.parse('24:00'), isNull);
    });

    test('rejects anything else that is not a time', () {
      for (final bad in <String>[
        '23:70',
        '25:00',
        '8',
        '08',
        '08:0',
        '8:000',
        'صباحاً',
        '',
        '-1:00',
      ]) {
        expect(DoseTime.parse(bad), isNull, reason: bad);
      }
    });

    test('writes back zero-padded', () {
      // So a round trip through this app cannot change the stored string.
      expect(DoseTime.parse('8:05')!.wireName, '08:05');
      expect(const DoseTime(0, 0).wireName, '00:00');
    });
  });

  group('reading a whole schedule', () {
    test('sorts, dedupes, and drops what the server would refuse', () {
      expect(
        parseDoseTimes('20:00, 08:00 ,24:00,08:00,nonsense')
            .map((t) => t.wireName),
        <String>['08:00', '20:00'],
      );
    });

    test('an empty or missing column is an empty schedule', () {
      expect(parseDoseTimes(null), isEmpty);
      expect(parseDoseTimes('   '), isEmpty);
      expect(hasInvalidDoseTime(null), isFalse);
    });

    test('says when a column holds something unreadable', () {
      // Which is what can explain to a customer why a medicine is quiet.
      expect(hasInvalidDoseTime('08:00,24:00'), isTrue);
      expect(hasInvalidDoseTime('08:00,20:00'), isFalse);
      // Trailing commas are not a bad entry.
      expect(hasInvalidDoseTime('08:00,'), isFalse);
    });
  });

  group('when a dose is due', () {
    // +03, no daylight saving, so the arithmetic is checkable by hand.
    const riyadh = 'Asia/Riyadh';

    test('is the civil time in the account market, not in UTC', () {
      final slots = doseSlotsFor(
        medicine(doseTimes: '08:00'),
        now: DateTime.utc(2026, 9, 20, 12),
        timeZone: riyadh,
        daysBack: 0,
      );

      // 08:00 in Riyadh is 05:00Z. Reading the column as UTC would put the
      // morning tablet three hours early for everybody in the market.
      expect(slots.single.scheduledAt, DateTime.utc(2026, 9, 20, 5));
    });

    test('yesterday is included, as the cron includes it', () {
      final slots = doseSlotsFor(
        medicine(doseTimes: '08:00'),
        now: DateTime.utc(2026, 9, 20, 12),
        timeZone: riyadh,
      );

      expect(slots.map((s) => s.scheduledAt), <DateTime>[
        DateTime.utc(2026, 9, 19, 5),
        DateTime.utc(2026, 9, 20, 5),
      ]);
    });

    test('a midnight slot lands on its own day, not the one before', () {
      // The case `values (0), (1)` is there for. Getting this wrong shifts a
      // whole schedule by a day.
      final slots = doseSlotsFor(
        medicine(doseTimes: '00:00'),
        now: DateTime.utc(2026, 9, 20, 12),
        timeZone: riyadh,
        daysBack: 0,
      );

      // 00:00 on the 20th in Riyadh is 21:00Z on the 19th.
      expect(slots.single.scheduledAt, DateTime.utc(2026, 9, 19, 21));
    });

    test("after midnight in the market, today is the market's today", () {
      // The day shift itself. At 22:00Z it is already 01:00 on the 21st in
      // Riyadh, so "today's" eight o'clock tablet is the one on the 21st.
      // Reading the calendar date off the UTC instant instead gives the 20th
      // and moves the whole schedule back a day — which every test pinned at
      // midday UTC was blind to, because at noon the two calendars agree.
      final slots = doseSlotsFor(
        medicine(doseTimes: '08:00'),
        now: DateTime.utc(2026, 9, 20, 22),
        timeZone: riyadh,
        daysBack: 0,
      );

      expect(slots.single.scheduledAt, DateTime.utc(2026, 9, 21, 5));
    });

    test(
      'and before midnight in a market behind UTC, it is still yesterday',
      () {
        // The mirror case, west of Greenwich: at 02:00Z on the 21st it is
        // still 22:00 on the 20th in New York, so today's slot is the 20th's.
        final slots = doseSlotsFor(
          medicine(doseTimes: '08:00'),
          now: DateTime.utc(2026, 9, 21, 2),
          timeZone: 'America/New_York',
          daysBack: 0,
        );

        expect(slots.single.scheduledAt, DateTime.utc(2026, 9, 20, 12));
      },
    );

    test('the same instant gives the same slots however it is expressed', () {
      // The device's own zone must not enter into it anywhere.
      final fromUtc = doseSlotsFor(
        medicine(doseTimes: '08:00'),
        now: DateTime.utc(2026, 9, 20, 12),
        timeZone: riyadh,
        daysBack: 0,
      );
      final fromOffset = doseSlotsFor(
        medicine(doseTimes: '08:00'),
        now: DateTime.parse('2026-09-20T20:00:00+08:00'),
        timeZone: riyadh,
        daysBack: 0,
      );

      expect(fromOffset.single.scheduledAt, fromUtc.single.scheduledAt);
    });

    test('a daylight change moves the instant, not the civil time', () {
      // Cairo went to +03 for the summer. The tablet is still taken at eight
      // in the morning; only the instant behind it moves.
      final summer = doseSlotsFor(
        medicine(doseTimes: '08:00'),
        now: DateTime.utc(2026, 7, 15, 12),
        timeZone: 'Africa/Cairo',
        daysBack: 0,
      ).single.scheduledAt;
      final winter = doseSlotsFor(
        medicine(doseTimes: '08:00'),
        now: DateTime.utc(2026, 1, 15, 12),
        timeZone: 'Africa/Cairo',
        daysBack: 0,
      ).single.scheduledAt;

      expect(summer.hour, 5, reason: '08:00 at +03');
      expect(winter.hour, 6, reason: '08:00 at +02');
    });

    test('slots come back in order', () {
      final slots = doseSlotsFor(
        medicine(doseTimes: '20:00,08:00'),
        now: DateTime.utc(2026, 9, 20, 12),
        timeZone: riyadh,
        daysBack: 0,
      );

      expect(slots.first.time.wireName, '08:00');
      expect(slots.last.time.wireName, '20:00');
    });
  });

  group('a medicine the server would skip has no slots', () {
    const riyadh = 'Asia/Riyadh';
    final now = DateTime.utc(2026, 9, 20, 12);

    test('no schedule', () {
      expect(
        doseSlotsFor(medicine(doseTimes: null), now: now, timeZone: riyadh),
        isEmpty,
      );
    });

    test('flagged as having an invalid time', () {
      // The cron filters on `has_invalid_dose_time`, so a flagged row is
      // silent on the server whatever the column now says.
      expect(
        doseSlotsFor(medicine(invalidFlag: true), now: now, timeZone: riyadh),
        isEmpty,
      );
    });

    test('nothing left to take', () {
      expect(
        doseSlotsFor(medicine(remaining: 0), now: now, timeZone: riyadh),
        isEmpty,
      );
      // But an uncounted medicine still has slots — null is "nobody counted",
      // which is what the SQL's `remaining_quantity is null or > 0` says.
      expect(
        doseSlotsFor(medicine(remaining: null), now: now, timeZone: riyadh),
        isNotEmpty,
      );
    });
  });

  group('matching recorded doses to slots', () {
    const riyadh = 'Asia/Riyadh';
    final slotAt = DateTime.utc(2026, 9, 20, 5); // 08:00 Riyadh

    List<DoseSlot> slots() => doseSlotsFor(
      medicine(),
      now: DateTime.utc(2026, 9, 20, 12),
      timeZone: riyadh,
      daysBack: 0,
    );

    test('a record inside the window answers the slot', () {
      final applied = applyRecords(slots(), <DateTime>[
        slotAt.add(const Duration(minutes: 40)),
      ]);

      expect(applied.first.isTaken, isTrue);
      expect(applied.last.isTaken, isFalse);
    });

    test('taking it early still counts', () {
      // The window reaches backwards, as the server's does: somebody who
      // takes the eight o'clock tablet at ten to eight has taken it.
      final applied = applyRecords(slots(), <DateTime>[
        slotAt.subtract(const Duration(minutes: 10)),
      ]);

      expect(applied.first.isTaken, isTrue);
    });

    test('a record outside the window answers nothing', () {
      final applied = applyRecords(slots(), <DateTime>[
        slotAt.subtract(const Duration(hours: 5)),
      ]);

      expect(applied.every((s) => !s.isTaken), isTrue);
    });

    test('one record cannot answer two slots', () {
      // A single tablet at eight does not settle the eight o'clock dose and
      // the four o'clock one. Without this a customer who logged once would
      // watch a whole day go quiet.
      final close = doseSlotsFor(
        medicine(doseTimes: '08:00,09:00'),
        now: DateTime.utc(2026, 9, 20, 12),
        timeZone: riyadh,
        daysBack: 0,
      );

      final applied = applyRecords(close, <DateTime>[slotAt]);

      expect(applied.where((s) => s.isTaken), hasLength(1));
    });
  });

  group('where a slot stands', () {
    final slotAt = DateTime.utc(2026, 9, 20, 5);
    final slot = DoseSlot(
      medicine: medicine(),
      time: const DoseTime(8, 0),
      scheduledAt: slotAt,
    );

    test('still to come', () {
      expect(
        slot.stateAt(slotAt.subtract(const Duration(hours: 1))),
        DoseState.upcoming,
      );
    });

    test('due inside the grace window', () {
      expect(slot.stateAt(slotAt), DoseState.due);
      expect(
        slot.stateAt(slotAt.add(const Duration(hours: 2, minutes: 59))),
        DoseState.due,
      );
    });

    test('missed once the window has passed', () {
      // The same three hours the cron stops looking after.
      expect(
        slot.stateAt(slotAt.add(const Duration(hours: 3, minutes: 1))),
        DoseState.missed,
      );
    });

    test('taken beats the clock', () {
      expect(
        slot.markTaken(slotAt).stateAt(slotAt.add(const Duration(days: 1))),
        DoseState.taken,
      );
    });
  });
}
