/// The shopping list's state.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/features/inventory/domain/shopping_item.dart';

/// What the shopping list draws.
class ShoppingView {
  /// Creates a view.
  const new({
    this.items = const <ShoppingItem>[],
    this.isRefreshing = false,
    this.error,
  });

  /// Every line, newest first.
  final List<ShoppingItem> items;

  /// Whether a fetch is in flight.
  final bool isRefreshing;

  /// The last refresh failure.
  final Object? error;

  /// Lines still to buy, most urgent first.
  List<ShoppingItem> get outstanding =>
      items.where((i) => i.isOutstanding).toList()
        ..sort((a, b) => b.priority.index.compareTo(a.priority.index));

  /// Lines already bought.
  List<ShoppingItem> get bought => items.where((i) => i.isPurchased).toList();

  /// Whether there is nothing on the list at all.
  bool get isEmpty => items.isEmpty;
}

/// Holds the shopping list.
class ShoppingController extends Notifier<ShoppingView> {
  bool _fetching = false;

  @override
  ShoppingView build() {
    final items = ref.read(shoppingListRepositoryProvider).cached();
    unawaited(Future<void>.microtask(() => ref.mounted ? refresh() : null));
    return ShoppingView(items: items);
  }

  /// Fetches.
  Future<void> refresh() async {
    if (_fetching || !ref.mounted) return;
    _fetching = true;
    state = ShoppingView(items: state.items, isRefreshing: true);

    try {
      final items = await ref.read(shoppingListRepositoryProvider).refresh();
      if (!ref.mounted) return;
      state = ShoppingView(items: items);
    } on Object catch (error) {
      if (!ref.mounted) return;
      state = ShoppingView(items: state.items, error: error);
    } finally {
      _fetching = false;
    }
  }

  /// Adds a line the customer typed.
  Future<void> add(String itemName, {int quantity = 1}) async {
    final name = itemName.trim();
    if (name.isEmpty) return;
    await ref
        .read(shoppingListRepositoryProvider)
        .add(itemName: name, quantity: quantity, at: ref.read(nowProvider)());
    _reload();
  }

  /// Ticks a line off, or back on.
  Future<void> toggle(String id, {required bool purchased}) async {
    await ref
        .read(shoppingListRepositoryProvider)
        .setPurchased(id, purchased: purchased);
    _reload();
  }

  /// Removes a line.
  Future<void> remove(String id) async {
    await ref.read(shoppingListRepositoryProvider).remove(id);
    _reload();
  }

  void _reload() {
    if (!ref.mounted) return;
    state = ShoppingView(
      items: ref.read(shoppingListRepositoryProvider).cached(),
    );
  }
}

/// The shopping list.
final shoppingControllerProvider =
    NotifierProvider<ShoppingController, ShoppingView>(ShoppingController.new);
