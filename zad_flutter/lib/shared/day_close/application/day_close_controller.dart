/// «اقفل يومك» on the phone (ZAD_PLAN ٣.٢): which account-day was last
/// closed, and the close itself — the server records it and gives the
/// companion its points, and the pet eats its dinner.
///
/// The closed day is cached in the device box so the evening card does not
/// come back after a close while offline or on the next launch; the server's
/// `zad_day_closes` is asked once per build and wins when it answers.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/shared/auth/application/session_controller.dart';
import 'package:zad/shared/companion/application/pet_care_controller.dart';
import 'package:zad/shared/companion/domain/pet_care.dart';
import 'package:zad/shared/day_close/data/day_close_remote.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';

/// The account's day (yyyy-mm-dd) at [now] in [zone].
String accountDayOf(String zone, DateTime now) {
  final wall = petWallClock(zone, now);
  return '${wall.year.toString().padLeft(4, '0')}-'
      '${wall.month.toString().padLeft(2, '0')}-'
      '${wall.day.toString().padLeft(2, '0')}';
}

/// What a close did, for the sheet to say.
typedef DayCloseDone = ({DayCloseResult result, bool petAte});

/// The last closed account-day, or null when none is known.
class DayCloseController extends Notifier<String?> {
  String? _key;

  @override
  String? build() {
    final user = ref.watch(sessionControllerProvider);
    if (user == null) return _key = null;
    final key = _key = 'day_closed_$user';
    final cached = ref.read(localStoreProvider).device.get(key);
    unawaited(_check(key, cached));
    return cached;
  }

  /// The account's day right now.
  String today() =>
      accountDayOf(ref.read(accountTimeZoneProvider), ref.read(nowProvider)());

  /// The account's hour right now (0–23).
  int hourNow() => petWallClock(
    ref.read(accountTimeZoneProvider),
    ref.read(nowProvider)(),
  ).hour;

  /// Whether today is already closed.
  bool get closedToday => state == today();

  // Runs from build, before there is a state to read: compare with what
  // build is about to return.
  Future<void> _check(String key, String? cached) async {
    final day = today();
    if (cached == day) return;
    final closed = await ref.read(dayCloseRemoteProvider).closedOn(day);
    if (closed == true && ref.mounted && _key == key) _remember(key, day);
  }

  void _remember(String key, String day) {
    state = day;
    unawaited(ref.read(localStoreProvider).device.put(key, day));
  }

  /// Closes today. The pet eats only on a first close: a second tap gives
  /// no points and no second dinner.
  Future<DayCloseDone> close(DayCloseOutcome outcome) async {
    final result = await ref.read(dayCloseRemoteProvider).close(outcome);
    final key = _key;
    var petAte = false;
    if (result.ok && key != null && ref.mounted) {
      _remember(key, today());
      if (!result.already) {
        petAte =
            ref.read(petCareProvider.notifier).feed() == PetCareOutcome.done;
      }
    }
    return (result: result, petAte: petAte);
  }
}

/// The last closed account-day.
final dayCloseProvider = NotifierProvider<DayCloseController, String?>(
  DayCloseController.new,
);
