import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/shared/alerts/application/local_reminders.dart';
import 'package:zad/shared/companion/domain/pet_care.dart';
import 'package:zad/shared/orb/domain/companion_state.dart';

void main() {
  final now = DateTime.utc(2026, 10, 13, 12);

  PetCare at({required double full, required double water, DateTime? cared}) =>
      PetCare(
        fedAt: now.subtract(PetCare.hungerSpan * (1 - full)),
        wateredAt: now.subtract(PetCare.thirstSpan * (1 - water)),
        lastCareAt: cared,
      );

  group('levels', () {
    test('fall in a straight line from the moment it was full', () {
      final c = at(full: 1, water: 1);
      expect(c.fullness(now), 1);
      expect(
        c.fullness(now.add(PetCare.hungerSpan * 0.5)),
        closeTo(0.5, 0.001),
      );
      expect(c.hydration(now.add(PetCare.thirstSpan * 2)), 0);
    });

    test('a newborn is a little hungry, not thirsty', () {
      final c = PetCare.newborn(now);
      expect(c.mood(now, hour: 12), CompanionState.hungry);
      expect(c.hydration(now), greaterThan(PetCare.needBelow));
    });
  });

  group('mood', () {
    test('thirst shows before hunger', () {
      expect(
        at(full: 0.2, water: 0.2).mood(now, hour: 12),
        CompanionState.thirsty,
      );
      expect(
        at(full: 0.2, water: 0.8).mood(now, hour: 12),
        CompanionState.hungry,
      );
    });

    test('left without food and water too long it is sad, never worse', () {
      expect(at(full: 0, water: 0).mood(now, hour: 12), CompanionState.sad);
    });

    test('sleepy at night on the account clock, unless just cared for', () {
      expect(at(full: 1, water: 1).mood(now, hour: 23), CompanionState.sleepy);
      expect(at(full: 0, water: 0).mood(now, hour: 3), CompanionState.sleepy);
      expect(
        at(full: 1, water: 1, cared: now).mood(now, hour: 23),
        CompanionState.happy,
      );
      expect(at(full: 1, water: 1).mood(now, hour: 6), CompanionState.idle);
    });

    test('pleased for a while after being looked after', () {
      final c = at(full: 0.5, water: 0.5, cared: now);
      expect(c.mood(now, hour: 12), CompanionState.happy);
      expect(
        c.mood(now.add(const Duration(minutes: 20)), hour: 12),
        CompanionState.idle,
      );
    });

    test('the four needs are needs; the agent moods are not', () {
      expect(
        CompanionState.values.where((s) => s.isNeed).toSet(),
        <CompanionState>{
          CompanionState.sad,
          CompanionState.hungry,
          CompanionState.thirsty,
          CompanionState.sleepy,
        },
      );
    });
  });

  group('feeding and water', () {
    test('a meal fills half; a full pet refuses', () {
      final (fed, outcome) = at(
        full: 0.2,
        water: 1,
      ).feed(now, day: '2026-10-13', yesterday: '2026-10-12');
      expect(outcome, PetCareOutcome.done);
      expect(fed.fullness(now), closeTo(0.7, 0.001));
      expect(fed.lastCareAt, now);

      final (same, again) = at(
        full: 0.97,
        water: 1,
      ).feed(now, day: '2026-10-13', yesterday: '2026-10-12');
      expect(again, PetCareOutcome.full);
      expect(same.lastCareAt, isNull);
    });

    test('never above full', () {
      final (c, _) = at(
        full: 0.8,
        water: 0.9,
      ).water(now, day: '2026-10-13', yesterday: '2026-10-12');
      expect(c.hydration(now), 1);
    });

    test('a day counts once both a meal and a drink happened in it', () {
      var c = at(full: 0.1, water: 0.1);
      (c, _) = c.feed(now, day: '2026-10-12', yesterday: '2026-10-11');
      expect(c.careStreak, 0);
      (c, _) = c.water(now, day: '2026-10-12', yesterday: '2026-10-11');
      expect(c.careStreak, 1);
      expect(c.careDay, '2026-10-12');

      // The next day continues the run…
      final later = now.add(const Duration(days: 1));
      (c, _) = c.feed(later, day: '2026-10-13', yesterday: '2026-10-12');
      (c, _) = c.water(later, day: '2026-10-13', yesterday: '2026-10-12');
      expect(c.careStreak, 2);

      // …a skipped day starts it over.
      final gap = now.add(const Duration(days: 3));
      (c, _) = c.feed(gap, day: '2026-10-15', yesterday: '2026-10-14');
      (c, _) = c.water(gap, day: '2026-10-15', yesterday: '2026-10-14');
      expect(c.careStreak, 1);
    });

    test('survives the store', () {
      final (c, _) = at(
        full: 0.2,
        water: 0.4,
      ).feed(now, day: '2026-10-13', yesterday: '2026-10-12');
      final back = PetCare.fromJson(c.toJson())!;
      expect(back.fullness(now), closeTo(c.fullness(now), 0.001));
      expect(back.hydration(now), closeTo(c.hydration(now), 0.001));
      expect(back.fedDay, '2026-10-13');
      expect(PetCare.fromJson('garbage'), isNull);
      expect(PetCare.fromJson(<String, Object?>{'fed_at': 'x'}), isNull);
    });
  });

  group('the reminder', () {
    late tz.Location cairo;
    setUpAll(() {
      tzdata.initializeTimeZones();
      cairo = tz.getLocation('Africa/Cairo');
    });

    test('rings when the first need will show', () {
      final wall = tz.TZDateTime(cairo, 2026, 10, 13, 10);
      final c = PetCare(
        fedAt: wall.subtract(const Duration(hours: 2)),
        wateredAt: wall.subtract(const Duration(hours: 1)),
      );
      final r = companionCareTime(c, wall);
      // Thirst first: 70% of 14h (9h48m) after the last full drink.
      expect(r.at, wall.add(const Duration(hours: 8, minutes: 48)));
      expect(r.thirsty, isTrue);
    });

    test('moves off the night to 19:00', () {
      final wall = tz.TZDateTime(cairo, 2026, 10, 13, 20, 30);
      final c = PetCare(fedAt: wall, wateredAt: wall);
      final r = companionCareTime(c, wall);
      expect(r.at.hour, 19);
      expect(r.at.day, 14);
    });

    test('already in need: three hours on, not now', () {
      final wall = tz.TZDateTime(cairo, 2026, 10, 13, 11);
      final c = PetCare(
        fedAt: wall.subtract(const Duration(days: 2)),
        wateredAt: wall.subtract(const Duration(days: 2)),
      );
      expect(companionCareTime(c, wall).at, wall.add(const Duration(hours: 3)));
    });

    test('a pet left alone keeps calling, mornings and evenings', () {
      final wall = tz.TZDateTime(cairo, 2026, 10, 13, 11);
      final c = PetCare(
        fedAt: wall.subtract(const Duration(days: 2)),
        wateredAt: wall.subtract(const Duration(days: 2)),
      );
      final calls = companionCareCalls(c, wall, name: 'زادو');
      // The first call, then six more over the next three days.
      expect(calls, hasLength(7));
      expect(calls.first.at, wall.add(const Duration(hours: 3)));
      for (final call in calls.skip(1)) {
        expect(call.at.hour, anyOf(10, 19));
        expect(call.title, contains('زادو'));
      }
      for (var i = 1; i < calls.length; i++) {
        expect(
          calls[i].at.difference(calls[i - 1].at),
          greaterThanOrEqualTo(const Duration(hours: 6)),
        );
      }
      // The last one within three days.
      expect(calls.last.at.difference(wall), lessThan(const Duration(days: 4)));
    });
  });

  test('every mood has something to say', () {
    for (final s in CompanionState.values) {
      expect(PetLines.forMood(s, name: 'زادو', loggedToday: false), isNotEmpty);
    }
  });
}
