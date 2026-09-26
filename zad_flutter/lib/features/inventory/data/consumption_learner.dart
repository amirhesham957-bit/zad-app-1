/// Kotlin's on-device `ConsumptionLearner` (`data/InventoryFlowEngine.kt`):
/// the purchase and use days of each pantry item, the smoothed interval
/// between purchases, and the three-day snooze of «لسه».
///
/// It is what home's «هل خلص X؟» card asks from, and it is separate from the
/// server's learner (`zad_record_observation`, `ConsumptionObservations`) —
/// Kotlin keeps both, and so does this client. Stored in the `device` box, as
/// Kotlin keeps it in SharedPreferences.
///
/// Days are civil days in the account's market zone (the Flutter port's rule
/// for civil time), where Kotlin used the device's.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/core/period/account_time_zone.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/features/inventory/application/pantry_controller.dart';
import 'package:zad/features/inventory/domain/inventory_item.dart';
import 'package:zad/features/inventory/domain/receipt_intake.dart';

/// Kotlin's `InventoryFlowEngine.CheckInCandidate`.
class CheckInCandidate {
  /// Creates a candidate.
  const new(this.item, this.predictedDaysLeft);

  /// The item.
  final InventoryItem item;

  /// Days until it runs out, by the purchase rhythm.
  final int predictedDaysLeft;
}

/// The learner.
class ConsumptionLearner {
  /// Creates the learner.
  const new(this._box, this._today);

  final Box<String> _box;
  final int Function() _today;

  static const String _prefix = 'zad_consumption:';
  static const String _buy = 'buy_';
  static const String _use = 'use_';
  static const String _smoothed = 'smoothed_interval_';
  static const String _snoozeUntil = 'checkin_snooze_until_';
  static const int _maxEvents = 8;
  static const double _alpha = 0.3;
  static const int _snoozeDays = 3;

  String _key(String prefix, String itemName) =>
      '$_prefix$prefix${normalizeItemName(itemName)}';

  List<int> _events(String prefix, String itemName) =>
      (_box.get(_key(prefix, itemName)) ?? '')
          .split(',')
          .map(int.tryParse)
          .whereType<int>()
          .toList();

  void _record(String prefix, String itemName) {
    final today = _today();
    final events = _events(prefix, itemName);
    final previousLast = events.isEmpty ? null : events.last;
    if (previousLast != today) {
      events.add(today);
      if (prefix == _buy && previousLast != null) {
        final interval = (today - previousLast).toDouble();
        if (interval > 0) _updateSmoothed(itemName, interval);
      }
    }
    while (events.length > _maxEvents) {
      events.removeAt(0);
    }
    unawaited(_box.put(_key(prefix, itemName), events.join(',')));
  }

  void _updateSmoothed(String itemName, double interval) {
    final key = _key(_smoothed, itemName);
    final previous = double.tryParse(_box.get(key) ?? '');
    final updated = previous == null || previous < 0
        ? interval
        : _alpha * interval + (1 - _alpha) * previous;
    unawaited(_box.put(key, updated.toString()));
  }

  /// A purchase — Kotlin records it when a scan puts the item in the pantry.
  void recordPurchase(String itemName) => _record(_buy, itemName);

  /// A use — Kotlin records it on every consumption.
  void recordConsumption(String itemName) => _record(_use, itemName);

  /// «لسه»: not a correction of the rate, only a three-day pause of the
  /// question.
  void snoozeCheckIn(String itemName) => unawaited(
    _box.put(_key(_snoozeUntil, itemName), '${_today() + _snoozeDays}'),
  );

  /// Whether the question is paused.
  bool isSnoozed(String itemName) {
    final until = int.tryParse(_box.get(_key(_snoozeUntil, itemName)) ?? '');
    return until != null && _today() <= until;
  }

  /// Kotlin's `averagePurchaseIntervalDays`.
  int? averagePurchaseIntervalDays(String itemName) {
    final smoothed = double.tryParse(_box.get(_key(_smoothed, itemName)) ?? '');
    if (smoothed != null && smoothed >= 0) {
      final days = smoothed.toInt();
      return days < 1 ? 1 : days;
    }
    final events = _events(_buy, itemName);
    if (events.length < 2) return null;
    final intervals = <int>[
      for (var i = 1; i < events.length; i++)
        if (events[i] - events[i - 1] > 0) events[i] - events[i - 1],
    ];
    if (intervals.isEmpty) return null;
    final avg = intervals.reduce((a, b) => a + b) / intervals.length;
    unawaited(_box.put(_key(_smoothed, itemName), avg.toString()));
    final days = avg.toInt();
    return days < 1 ? 1 : days;
  }

  /// Kotlin's `predictDaysLeft`: last purchase + the usual interval − today.
  int? predictDaysLeft(String itemName) {
    final interval = averagePurchaseIntervalDays(itemName);
    if (interval == null) return null;
    final buys = _events(_buy, itemName);
    if (buys.isEmpty) return null;
    final remaining = interval - (_today() - buys.last);
    return remaining.clamp(-30, 365);
  }

  /// Kotlin's `getCheckInCandidates`: in stock, not snoozed, and due to run
  /// out within a day — nearest first.
  List<CheckInCandidate> checkInCandidates(List<InventoryItem> inventory) {
    final out = <CheckInCandidate>[];
    for (final item in inventory) {
      if (item.quantity <= 0) continue;
      if (isSnoozed(item.itemName)) continue;
      final daysLeft = predictDaysLeft(item.itemName);
      if (daysLeft == null) continue;
      if (daysLeft <= 1) out.add(CheckInCandidate(item, daysLeft));
    }
    out.sort((a, b) => a.predictedDaysLeft.compareTo(b.predictedDaysLeft));
    return out;
  }
}

/// The learner, on this device.
final consumptionLearnerProvider = Provider<ConsumptionLearner>((ref) {
  final box = ref.watch(localStoreProvider).device;
  final now = ref.watch(nowProvider);
  final zone = ref.watch(accountTimeZoneProvider);
  return ConsumptionLearner(box, () {
    final local = tz.TZDateTime.from(now().toUtc(), tz.getLocation(zone));
    return DateTime.utc(
          local.year,
          local.month,
          local.day,
        ).millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;
  });
});

/// Bumped when «لسه» snoozes an item, so the candidates are read again —
/// Kotlin calls `refreshInventoryCheckIns()` at the same point.
class CheckInRevision extends Notifier<int> {
  @override
  int build() => 0;

  /// Reads the candidates again.
  void bump() => state++;
}

/// The snooze revision.
final checkInRevisionProvider = NotifierProvider<CheckInRevision, int>(
  CheckInRevision.new,
);

/// Home's check-in candidates, nearest to running out first.
final checkInCandidatesProvider = Provider<List<CheckInCandidate>>((ref) {
  ref.watch(checkInRevisionProvider);
  final items = ref.watch(pantryControllerProvider.select((v) => v.items));
  return ref.read(consumptionLearnerProvider).checkInCandidates(items);
});
