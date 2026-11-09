/// The category ceilings: the cache at once, then the account's.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/shared/budget/data/category_budgets_store.dart';

/// The ceilings on screen.
class CategoryBudgetsController extends Notifier<Map<String, double>> {
  @override
  Map<String, double> build() {
    unawaited(Future<void>.microtask(_pull));
    return ref.read(categoryBudgetsStoreProvider).read();
  }

  Future<void> _pull() async {
    if (!ref.mounted) return;
    try {
      final latest = await ref.read(categoryBudgetsStoreProvider).pull();
      if (ref.mounted) state = latest;
    } on Object catch (e) {
      // Offline, or no client in a test: the cache stands.
      debugPrint('[category budgets] not read: $e');
    }
  }

  /// Sets [category]'s ceiling; zero clears it.
  Future<void> set(String category, double amount) async {
    state = await ref
        .read(categoryBudgetsStoreProvider)
        .write(category, amount);
  }
}

/// The category ceilings.
final categoryBudgetsProvider =
    NotifierProvider<CategoryBudgetsController, Map<String, double>>(
      CategoryBudgetsController.new,
    );
