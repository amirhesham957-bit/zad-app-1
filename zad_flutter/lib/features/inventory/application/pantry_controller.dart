/// The pantry screen's state, and the one automatic write in the app.
///
/// After every refresh and every count change, whatever has run out is put on
/// the shopping list. That is safe to do on every pass because
/// `ShoppingListRepository.addShortages` only adds, adds each name at most
/// once, and is idempotent — and it is worth doing on every pass because a
/// pantry that ran out on another phone in the household should reach this
/// phone's list the next time it looks.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/core/period/account_time_zone.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/features/inventory/data/consumption_learner.dart';
import 'package:zad/features/inventory/data/consumption_observations.dart';
import 'package:zad/features/inventory/domain/inventory_item.dart';
import 'package:zad/features/inventory/domain/shortage.dart';

/// What the pantry screen draws.
class PantryView {
  /// Creates a view.
  const new({
    this.items = const <InventoryItem>[],
    this.shortages = const <Shortage>[],
    this.isRefreshing = false,
    this.addedToList = 0,
    this.error,
  });

  /// Everything in the pantry, by name.
  final List<InventoryItem> items;

  /// What needs buying, most urgent first.
  final List<Shortage> shortages;

  /// Whether a fetch is in flight.
  final bool isRefreshing;

  /// How many lines the last pass put on the shopping list — for the one
  /// sentence the screen says about it, and only when it is not zero.
  final int addedToList;

  /// The last refresh failure.
  final Object? error;

  /// Whether the pantry is empty.
  bool get isEmpty => items.isEmpty;

  /// A copy with the given fields replaced.
  PantryView copyWith({
    List<InventoryItem>? items,
    List<Shortage>? shortages,
    bool? isRefreshing,
    int? addedToList,
    Object? error,
    bool clearError = false,
  }) => PantryView(
    items: items ?? this.items,
    shortages: shortages ?? this.shortages,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    addedToList: addedToList ?? this.addedToList,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Holds the pantry.
class PantryController extends Notifier<PantryView> {
  /// How long a re-entry reuses what it already fetched. The budget's figure.
  static const Duration cooldown = Duration(minutes: 5);

  DateTime? _lastFetch;
  bool _fetching = false;

  @override
  PantryView build() {
    final items = ref.read(inventoryRepositoryProvider).cached();
    unawaited(Future<void>.microtask(() => ref.mounted ? refresh() : null));
    return PantryView(items: items, shortages: _shortagesOf(items));
  }

  /// Fetches, unless inside the cooldown and [force] is false.
  Future<void> refresh({bool force = false}) async {
    if (_fetching || !ref.mounted) return;

    final now = ref.read(nowProvider)();
    final last = _lastFetch;
    if (!force && last != null && now.difference(last) < cooldown) return;

    _fetching = true;
    state = state.copyWith(isRefreshing: true, clearError: true);

    try {
      final items = await ref.read(inventoryRepositoryProvider).refresh();
      if (!ref.mounted) return;
      _lastFetch = now;
      await _settle(items);
    } on Object catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(isRefreshing: false, error: error);
    } finally {
      _fetching = false;
    }
  }

  /// Adds a row.
  Future<void> add({
    required String itemName,
    int quantity = 1,
    String? unit,
    String? category,
    int? lowStockThreshold,
    DateTime? expiryDate,
  }) async {
    final added = await ref
        .read(inventoryRepositoryProvider)
        .add(
          itemName: itemName,
          quantity: quantity,
          unit: unit,
          category: category,
          lowStockThreshold: lowStockThreshold,
          expiryDate: expiryDate,
        );
    // The first level the learner hears of. Without it the first − has
    // nothing to be a drop from.
    await _reading(added);
    await _reload();
  }

  /// Moves a count by [delta], and tells the consumption learner the new
  /// level.
  ///
  /// After + as well as −. The learner counts drops between consecutive
  /// readings; a + that went unreported leaves the last reading at the lower
  /// level, and the next − then reads as no drop at all.
  Future<void> adjust(String id, int delta) async {
    final updated = await ref
        .read(inventoryRepositoryProvider)
        .adjustQuantity(id, delta);
    // Kotlin's `consumeItem` feeds the on-device learner on every use.
    if (updated != null && delta < 0) {
      ref.read(consumptionLearnerProvider).recordConsumption(updated.itemName);
    }
    if (updated != null) await _reading(updated);
    await _reload();
  }

  Future<void> _reading(InventoryItem item) => ref
      .read(consumptionObservationsProvider)
      .record(item.itemName, item.quantity, ObservationSource.manual);

  /// Kotlin's `EditInventoryDialog`: name, count and unit. The learner hears
  /// the new count, as it does after −/+.
  Future<void> edit(
    InventoryItem item, {
    required String itemName,
    required int quantity,
    String? unit,
  }) async {
    final updated = await ref
        .read(inventoryRepositoryProvider)
        .update(
          item.copyWith(
            itemName: itemName.trim(),
            quantity: quantity,
            unit: unit,
          ),
        );
    if (updated.quantity != item.quantity) await _reading(updated);
    await _reload();
  }

  /// Removes a row.
  Future<void> remove(String id) async {
    await ref.read(inventoryRepositoryProvider).remove(id);
    await _reload();
  }

  Future<void> _reload() async {
    if (!ref.mounted) return;
    await _settle(ref.read(inventoryRepositoryProvider).cached());
  }

  /// Recomputes the shortages and puts them on the list.
  Future<void> _settle(List<InventoryItem> items) async {
    final shortages = _shortagesOf(items);
    final added = await ref
        .read(shoppingListRepositoryProvider)
        .addShortages(shortages, at: ref.read(nowProvider)());
    if (!ref.mounted) return;

    state = PantryView(
      items: items,
      shortages: shortages,
      addedToList: added.length,
    );
  }

  /// Today in the account's market zone, as a civil date.
  ///
  /// The shortage rules take the day as an argument so they cannot quietly
  /// ask the device, and this is the one place that decides what day it is.
  List<Shortage> _shortagesOf(List<InventoryItem> items) {
    final now = ref.read(nowProvider)();
    final zone = tz.getLocation(ref.read(accountTimeZoneProvider));
    final local = tz.TZDateTime.from(now.toUtc(), zone);
    return shortagesIn(
      items,
      today: DateTime.utc(local.year, local.month, local.day),
    );
  }
}

/// The pantry.
final pantryControllerProvider = NotifierProvider<PantryController, PantryView>(
  PantryController.new,
);
