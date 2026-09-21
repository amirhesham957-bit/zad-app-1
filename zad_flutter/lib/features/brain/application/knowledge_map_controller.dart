/// خريطة زاد's state: the map, recomputed from every screen's cache plus the
/// four reads only the map makes.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:zad/data/providers.dart';
import 'package:zad/features/brain/data/knowledge_map_repository.dart';
import 'package:zad/features/brain/domain/knowledge_map.dart';
import 'package:zad/features/budget/domain/budget_snapshot.dart';
import 'package:zad/features/inventory/domain/inventory_item.dart';
import 'package:zad/features/inventory/domain/shopping_item.dart';
import 'package:zad/features/pharmacy/domain/medicine.dart';
import 'package:zad/features/subscriptions/domain/subscription.dart';

String _n(num v) => NumberFormat('#,##0.##', 'en').format(v);

/// The map's inputs from the app's own models. Pure; tested.
MapInputs mapInputsFrom({
  required BudgetSnapshot? budget,
  required List<Subscription> subscriptions,
  required List<InventoryItem> pantry,
  required List<ShoppingItem> shopping,
  required List<Medicine> medicines,
  required MapExtras extras,
}) {
  final limit = budget != null && budget.limitConfirmed
      ? budget.openingBalance
      : null;
  return MapInputs(
    limit: limit,
    committed: budget?.committed ?? 0,
    available: budget?.available,
    obligations: extras.obligations,
    subscriptions: <MapLine>[
      for (final s in subscriptions)
        if (s.isActive)
          MapLine(s.title, s.amount, detail: '${_n(s.amount)}/شهر'),
    ],
    debts: <MapLine>[
      for (final d in extras.debts)
        MapLine(d.name, d.amount, detail: 'فاضل ${_n(d.amount)}'),
    ],
    lowPantry: <MapStock>[
      for (final i in pantry)
        if (i.isLowStock)
          MapStock(i.itemName, '${i.quantity} ${i.unit ?? ''}'.trim()),
    ],
    pendingShopping: <MapStock>[
      for (final s in shopping)
        if (s.isOutstanding)
          MapStock(s.itemName, '× ${s.quantity}', price: s.estimatedPrice),
    ],
    lowPharmacy: <MapStock>[
      for (final m in medicines)
        if (m.isRunningOut || m.isOutOfStock)
          MapStock(
            m.name,
            'فاضل ${m.remainingQuantity ?? 0} ${m.unit ?? ''}'.trim(),
          ),
    ],
    maintenance: extras.maintenance,
    insights: extras.insights,
  );
}

/// What the screen draws.
class KnowledgeMapView {
  /// Creates a view.
  const new({
    required this.map,
    this.currency,
    this.isRefreshing = false,
    this.error,
  });

  /// The map.
  final KnowledgeMap map;

  /// The account's currency.
  final String? currency;

  /// Whether the four reads are in flight.
  final bool isRefreshing;

  /// Why the last read failed.
  final Object? error;
}

/// Holds the map.
class KnowledgeMapController extends Notifier<KnowledgeMapView> {
  bool _fetching = false;

  @override
  KnowledgeMapView build() {
    unawaited(Future<void>.microtask(() => ref.mounted ? refresh() : null));
    return KnowledgeMapView(
      map: _compute(ref.read(knowledgeMapRepositoryProvider).cached()),
      currency: ref.read(settingsRepositoryProvider).cached()?.currency,
    );
  }

  KnowledgeMap _compute(MapExtras extras) => buildKnowledgeMap(
    mapInputsFrom(
      budget: ref.read(budgetRepositoryProvider).cached(),
      subscriptions: ref.read(subscriptionsRepositoryProvider).cached(),
      pantry: ref.read(inventoryRepositoryProvider).cached(),
      shopping: ref.read(shoppingListRepositoryProvider).cached(),
      medicines: ref.read(pharmacyRepositoryProvider).cached(),
      extras: extras,
    ),
  );

  /// Reads the four again and redraws — the other screens' caches are read
  /// fresh at the same time. Keeps the last map if the read fails.
  Future<void> refresh() async {
    if (_fetching || !ref.mounted) return;
    _fetching = true;
    state = KnowledgeMapView(
      map: state.map,
      currency: state.currency,
      isRefreshing: true,
    );
    final repository = ref.read(knowledgeMapRepositoryProvider);
    try {
      final extras = await repository.refresh();
      if (!ref.mounted) return;
      state = KnowledgeMapView(map: _compute(extras), currency: state.currency);
    } on Object catch (error) {
      if (!ref.mounted) return;
      state = KnowledgeMapView(
        map: _compute(repository.cached()),
        currency: state.currency,
        error: error,
      );
    } finally {
      _fetching = false;
    }
  }
}

/// The map.
final knowledgeMapControllerProvider =
    NotifierProvider<KnowledgeMapController, KnowledgeMapView>(
      KnowledgeMapController.new,
    );
