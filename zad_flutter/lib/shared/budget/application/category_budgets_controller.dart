/// The category ceilings — kept on this device, as Kotlin keeps them.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/shared/budget/data/category_budgets_store.dart';

/// The ceilings on screen.
class CategoryBudgetsController extends Notifier<Map<String, double>> {
  @override
  Map<String, double> build() => ref.read(categoryBudgetsStoreProvider).read();

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
