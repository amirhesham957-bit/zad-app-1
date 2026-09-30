/// Kotlin's market change with `convertLimitsForMarketChange`: the monthly
/// limit and every category budget are carried into the new currency with
/// Kotlin's seed rates, so a limit keeps meaning the same money after a move.
/// With no rate the figures stay as they are.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/money/fx.dart';
import 'package:zad/core/money/money.dart';
import 'package:zad/shared/budget/data/category_budgets_store.dart';
import 'package:zad/shared/market/application/market_gate_controller.dart';
import 'package:zad/shared/market/domain/market.dart';
import 'package:zad/shared/settings/application/settings_controller.dart';

/// Switches to [to] and converts the limits from [from].
Future<void> switchMarket(WidgetRef ref, Market? from, Market to) async {
  final settings = ref.read(settingsControllerProvider).settings;
  final limit = settings?.monthlyLimit ?? 0;
  final rate = from == null
      ? null
      : convertCurrency(1, from.currency, to.currency);
  await ref.read(marketGateProvider.notifier).choose(to);
  if (rate == null) return;
  if (limit > 0) {
    await ref
        .read(settingsControllerProvider.notifier)
        .setMonthlyLimit((limit * rate).asMoney);
  }
  final store = ref.read(categoryBudgetsStoreProvider);
  for (final MapEntry(key: category, value: amount) in store.read().entries) {
    if (amount > 0) await store.write(category, (amount * rate).asMoney);
  }
}
