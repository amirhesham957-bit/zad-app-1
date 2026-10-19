/// The virtual pet's care (`pet_care.dart`) for the signed-in account, kept
/// in the device box under the account's id, with the reminder that calls
/// the customer back when it next gets hungry or thirsty.
///
/// The server holds the same times since ZAD_PLAN ٥.٥ (`pet_care_remote.dart`):
/// the phone answers from its box at once, then sends its care on every open
/// and after every meal, and takes the merged row back — the server's row
/// wins. A failed send costs nothing: the whole state goes in the next one.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/core/data/providers.dart';
import 'package:zad/shared/alerts/application/local_reminders.dart';
import 'package:zad/shared/auth/application/session_controller.dart';
import 'package:zad/shared/companion/data/pet_care_remote.dart';
import 'package:zad/shared/companion/domain/pet_care.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/orb/domain/companion_state.dart';
import 'package:zad/shared/session/product_events.dart';

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

  /// The care was just made up on this phone ([PetCare.newborn]), not read.
  bool _newborn = false;

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
    // After this build returns, so the sync's first write lands on the
    // state the build produced.
    unawaited(Future<void>.microtask(() => ref.mounted ? sync() : null));
    _newborn = stored == null;
    if (stored != null) return stored;
    final born = PetCare.newborn(ref.read(petClockProvider)());
    unawaited(box.put(key, jsonEncode(born.toJson())));
    return born;
  }

  String get _syncedKey => '${_key}_synced';

  /// Sends the care and takes the server's row. A pet just born on this
  /// phone asks first, so the newborn never overwrites a pet another phone
  /// has been feeding; a pet this phone already had is sent and merged.
  Future<void> sync() async {
    final key = _key;
    if (!ref.mounted || key == null || state == null) return;
    final box = ref.read(localStoreProvider).device;
    try {
      final remote = ref.read(petCareRemoteProvider);
      final pullFirst = _newborn && box.get(_syncedKey) != '1';
      var server = pullFirst ? await remote.sync(null) : null;
      if (server == null) {
        if (!ref.mounted || _key != key || state == null) return;
        server = await remote.sync(state);
      }
      if (!ref.mounted || _key != key || server == null) return;
      await box.put(_syncedKey, '1');
      _newborn = false;
      _adopt(server, first: pullFirst);
    } on Object catch (e) {
      // Offline, or no server (a test host): the box answers until next time.
      debugPrint('[pet] care not synced: $e');
    }
  }

  /// Takes [server]'s row unless it is behind this phone — a meal made while
  /// an earlier send was in flight comes back with its own send. [first] is a
  /// phone meeting the pet: the server's row beats its newborn either way.
  void _adopt(PetCare server, {required bool first}) {
    final key = _key;
    final current = state;
    if (key == null || current == null) return;
    if (!first &&
        (server.fedAt.isBefore(current.fedAt) ||
            server.wateredAt.isBefore(current.wateredAt))) {
      return;
    }
    if (jsonEncode(server.toJson()) == jsonEncode(current.toJson())) return;
    state = server;
    unawaited(
      ref.read(localStoreProvider).device.put(key, jsonEncode(server.toJson())),
    );
    unawaited(ref.read(localRemindersProvider).syncCompanionCare(server));
  }

  void _event(String name) {
    try {
      unawaited(
        ref
            .read(productEventsProvider)
            .log(name)
            .catchError((Object _) => false),
      );
    } on Object {
      // No session graph (a test host).
    }
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
  PetCareOutcome feed() => _act('pet.feed', (c, now, day, yesterday) {
    return c.feed(now, day: day, yesterday: yesterday);
  });

  /// One drink.
  PetCareOutcome water() => _act('pet.water', (c, now, day, yesterday) {
    return c.water(now, day: day, yesterday: yesterday);
  });

  /// A pat.
  void pet() {
    _act('pet.pat', (c, now, _, _) => (c.pet(now), PetCareOutcome.done));
  }

  /// [event] goes to `zad_product_events`: whether people who care for the
  /// pet come back more is the phase's gate (ZAD_PLAN ٥.٥).
  PetCareOutcome _act(
    String event,
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
      _event(event);
      unawaited(sync());
    }
    return outcome;
  }
}

/// The pet's care.
final petCareProvider = NotifierProvider<PetCareController, PetCare?>(
  PetCareController.new,
);
