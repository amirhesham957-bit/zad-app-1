/// What counts as running out, and why.
///
/// A pure function over the pantry: no clock, no storage, no network. The day
/// is passed in because "is this expiring" is a civil-date question, and
/// reading `DateTime.now()` inside would answer it against the device's own
/// zone — which is the wrong zone for an account whose market is elsewhere,
/// and the wrong answer by a whole day either side of midnight.
library;

import 'package:zad/features/inventory/domain/inventory_item.dart';
import 'package:zad/features/inventory/domain/shopping_item.dart';

/// Why something needs buying.
enum ShortageReason {
  /// None left at all.
  outOfStock,

  /// Past its date.
  expired,

  /// At or below the threshold.
  runningLow,

  /// Still in date, but not for long.
  expiringSoon,
}

/// One thing that needs buying, and the reason.
class Shortage {
  /// Creates a shortage.
  const new({required this.item, required this.reason});

  /// The pantry row.
  final InventoryItem item;

  /// Why it is here.
  final ShortageReason reason;

  /// How the shopping list should rank it.
  ///
  /// Nothing left, or nothing usable left, is the only case that earns
  /// `high`. If everything a pantry scan turned up were urgent, the ranking
  /// would say nothing at all.
  ShoppingPriority get priority => switch (reason) {
    ShortageReason.outOfStock ||
    ShortageReason.expired => ShoppingPriority.high,
    ShortageReason.runningLow ||
    ShortageReason.expiringSoon => ShoppingPriority.medium,
  };
}

/// Everything in [items] that needs buying, most urgent first.
///
/// Each row appears **once**, under its most urgent reason. A carton that is
/// both the last one and going off tomorrow is one line on the shopping list,
/// not two — the Kotlin screens dedupe the same way (`distinctBy { it.id }`)
/// after unioning the two sets.
List<Shortage> shortagesIn(
  List<InventoryItem> items, {
  required DateTime today,
  int expiringWithinDays = 3,
}) {
  final shortages = <Shortage>[];

  for (final item in items) {
    final reason = shortageReasonFor(
      item,
      today: today,
      expiringWithinDays: expiringWithinDays,
    );
    if (reason != null) shortages.add(Shortage(item: item, reason: reason));
  }

  // Most urgent first, then by name so the order is stable between two runs
  // over the same pantry — a list that reshuffles itself on every rebuild is
  // a list nobody can scan.
  shortages.sort((a, b) {
    final byReason = a.reason.index.compareTo(b.reason.index);
    return byReason != 0
        ? byReason
        : a.item.itemName.compareTo(b.item.itemName);
  });

  return shortages;
}

/// Why one row needs buying, or null when it does not.
ShortageReason? shortageReasonFor(
  InventoryItem item, {
  required DateTime today,
  int expiringWithinDays = 3,
}) {
  if (item.quantity <= 0) return ShortageReason.outOfStock;

  final days = item.daysUntilExpiry(today);
  // Past its date first: a full jar of something that went off last week is
  // not "running low", and calling it that would put it below an item there
  // are two of.
  if (days != null && days < 0) return ShortageReason.expired;

  if (item.isLowStock) return ShortageReason.runningLow;
  if (days != null && days <= expiringWithinDays) {
    return ShortageReason.expiringSoon;
  }
  return null;
}
