/// «نمط استهلاكك» (ZAD_PLAN phase 3, the cumulative behavioral profile,
/// owner 6/11): what the nightly `update-behavior-profile` learned about the
/// home — its stores, when it shops, and each pantry item's purchase cycle.
///
/// Read from the customer's own `user_behavior_profile` row (RLS: own row
/// only). Nothing here is computed on the device; a malformed part is dropped,
/// never guessed.
library;

/// One store the home buys from.
typedef PatternStore = ({String store, int visits, int share});

/// When the home shops. `topWeekday` is 0 = Sunday; null fields mean there
/// is no pattern yet (fewer than four shopping days).
typedef ShoppingRhythm = ({
  int? topWeekday,
  String? topPart,
  int? everyDays,
  int shoppingDays,
});

/// Where an item's cycle comes from.
enum CycleSource {
  /// The customer set it.
  customer,

  /// Learned from the home's own purchases.
  learned,

  /// Zad's first estimate for that kind of item.
  estimate,
}

/// One pantry item's cycle.
typedef ItemCycle = ({
  String item,
  int cycleDays,
  CycleSource source,
  int? dueInDays,
  bool due,
});

/// The whole page.
typedef ConsumptionPattern = ({
  double? weeklySpending,
  List<PatternStore> stores,
  ShoppingRhythm rhythm,
  List<ItemCycle> items,
  DateTime? updatedAt,
});

/// Parts of the day the server writes, in order.
const List<String> dayParts = <String>['morning', 'noon', 'evening', 'night'];

/// Reads the profile row. Null when there is no row yet.
ConsumptionPattern? consumptionPatternFromJson(Object? raw) {
  if (raw is! Map) return null;
  final stores = <PatternStore>[
    for (final s in _list(raw['favorite_stores']))
      if (s is Map && _str(s['store']).isNotEmpty)
        (
          store: _str(s['store']),
          visits: _int(s['visits']) ?? 0,
          share: (_int(s['share']) ?? 0).clamp(0, 100),
        ),
  ];
  final r = raw['shopping_rhythm'];
  final rhythm = r is Map
      ? (
          topWeekday: switch (_int(r['top_weekday'])) {
            final int d when d >= 0 && d <= 6 => d,
            _ => null,
          },
          topPart: dayParts.contains(r['top_part'])
              ? r['top_part'] as String
              : null,
          everyDays: switch (_int(r['typical_gap_days'])) {
            final int d when d >= 1 => d,
            _ => null,
          },
          shoppingDays: _int(r['shopping_days']) ?? 0,
        )
      : _noRhythm;
  final items = <ItemCycle>[
    for (final i in _list(raw['item_cycles']))
      if (i is Map &&
          _str(i['item']).isNotEmpty &&
          (_int(i['cycle_days']) ?? 0) >= 1)
        (
          item: _str(i['item']),
          cycleDays: _int(i['cycle_days'])!,
          source: i['set_by_customer'] == true
              ? CycleSource.customer
              : i['learned'] == true
              ? CycleSource.learned
              : CycleSource.estimate,
          dueInDays: _int(i['due_in_days']),
          due: i['due'] == true,
        ),
  ];
  return (
    weeklySpending: switch (raw['avg_weekly_spending']) {
      final num n when n > 0 => n.toDouble(),
      final String s => double.tryParse(s),
      _ => null,
    },
    stores: stores,
    rhythm: rhythm,
    items: items,
    updatedAt: switch (raw['last_updated_at']) {
      final String s => DateTime.tryParse(s),
      _ => null,
    },
  );
}

/// Whether anything has been learned at all.
bool hasLearnedAnything(ConsumptionPattern p) =>
    p.stores.isNotEmpty || p.items.isNotEmpty || p.rhythm.shoppingDays > 0;

const ShoppingRhythm _noRhythm = (
  topWeekday: null,
  topPart: null,
  everyDays: null,
  shoppingDays: 0,
);

List<Object?> _list(Object? v) => v is List ? v : const <Object?>[];

String _str(Object? v) => v is String ? v.trim() : '';

int? _int(Object? v) => switch (v) {
  final int n => n,
  final num n when n.isFinite => n.round(),
  _ => null,
};
