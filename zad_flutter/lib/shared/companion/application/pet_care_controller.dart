/// The virtual pet's care (`pet_care.dart`) for the signed-in account, kept
/// in the device box under the account's id, with the reminder that calls
/// the customer back when it next gets hungry or thirsty.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/core/data/providers.dart';
import 'package:zad/shared/alerts/application/local_reminders.dart';
import 'package:zad/shared/auth/application/session_controller.dart';
import 'package:zad/shared/companion/domain/pet_care.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/orb/domain/companion_state.dart';

/// The clock the pet reads; tests replace it.
final petClockProvider = Provider<DateTime Function()>((_) => DateTime.now);

/// The account's wall clock at [now], or the device's when the zone is
/// unknown (tests, a first launch before the market is read).
DateTime petWallClock(String zone, DateTime now) {
  try {
    return tz.TZDateTime.from(now.toUtc(), tz.getLocation(zone));
  } on Object {
    return now.toLocal();
  }
}

String _day(DateTime wall) =>
    '${wall.year.toString().padLeft(4, '0')}-'
    '${wall.month.toString().padLeft(2, '0')}-'
    '${wall.day.toString().padLeft(2, '0')}';

/// The care, or null when signed out.
class PetCareController extends Notifier<PetCare?> {
  String? _key;

  @override
  PetCare? build() {
    final user = ref.watch(sessionControllerProvider);
    if (user == null) return null;
    final key = _key = 'pet_care_$user';
    final box = ref.read(localStoreProvider).device;
    PetCare? stored;
    try {
      stored = PetCare.fromJson(jsonDecode(box.get(key) ?? 'null'));
    } on Object catch (e) {
      debugPrint('[pet] unreadable care, starting over: $e');
    }
    if (stored != null) return stored;
    final born = PetCare.newborn(ref.read(petClockProvider)());
    unawaited(box.put(key, jsonEncode(born.toJson())));
    return born;
  }

  DateTime get _now => ref.read(petClockProvider)();

  /// The mood right now, on the account's clock.
  CompanionState moodNow() {
    final care = state;
    if (care == null) return CompanionState.idle;
    final now = _now;
    return care.mood(
      now,
      hour: petWallClock(ref.read(accountTimeZoneProvider), now).hour,
    );
  }

  /// One meal.
  PetCareOutcome feed() => _act((c, now, day, yesterday) {
    return c.feed(now, day: day, yesterday: yesterday);
  });

  /// One drink.
  PetCareOutcome water() => _act((c, now, day, yesterday) {
    return c.water(now, day: day, yesterday: yesterday);
  });

  /// A pat.
  void pet() {
    _act((c, now, _, _) => (c.pet(now), PetCareOutcome.done));
  }

  PetCareOutcome _act(
    (PetCare, PetCareOutcome) Function(
      PetCare care,
      DateTime now,
      String day,
      String yesterday,
    )
    step,
  ) {
    final care = state;
    final key = _key;
    if (care == null || key == null) return PetCareOutcome.full;
    final now = _now;
    final wall = petWallClock(ref.read(accountTimeZoneProvider), now);
    final yesterday = DateTime(wall.year, wall.month, wall.day - 1);
    final (next, outcome) = step(care, now, _day(wall), _day(yesterday));
    if (outcome == PetCareOutcome.done) {
      state = next;
      unawaited(
        ref.read(localStoreProvider).device.put(key, jsonEncode(next.toJson())),
      );
      unawaited(ref.read(localRemindersProvider).syncCompanionCare(next));
    }
    return outcome;
  }
}

/// The pet's care.
final petCareProvider = NotifierProvider<PetCareController, PetCare?>(
  PetCareController.new,
);
