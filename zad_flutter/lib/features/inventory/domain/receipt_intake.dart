/// What a grocery receipt does to the pantry and the shopping list.
///
/// Pure: the lines, the pantry and the list go in, a plan comes out, and the
/// scan controller carries it out. Kotlin does the same job in
/// `InventoryFlowEngine.injectScannedItems`, and the matching rules here are
/// its rules, so the two clients put the same receipt into the same rows:
///
/// * a line that names something already in the pantry adds to it;
/// * anything else becomes a new row;
/// * an open shopping-list line the receipt satisfies is ticked off — the
///   loop the list exists to close.
///
/// Two things this adds, both about a receipt the Kotlin engine mishandles:
/// two lines for the same product (two cartons rung up separately) become one
/// increment, and two differently-printed lines that both match one pantry row
/// add to it once each rather than the second overwriting the first.
library;

import 'package:zad/features/inventory/domain/inventory_item.dart';
import 'package:zad/features/inventory/domain/shopping_item.dart';

/// A receipt line, as the pantry will take it.
class IntakeLine {
  /// Creates a line.
  const new({
    required this.name,
    required this.quantity,
    this.unit,
    this.category,
  });

  /// The item's name as printed.
  final String name;

  /// How many, as a whole count — the pantry counts in whole units.
  final int quantity;

  /// The unit, a stored value (`قطعة`, `كجم`, `علبة`).
  final String? unit;

  /// The item's own category, a stored value.
  final String? category;
}

/// What to do.
class IntakePlan {
  /// Creates a plan.
  const new({
    required this.increments,
    required this.additions,
    required this.bought,
  });

  /// Rows already in the pantry, and how many to add to each.
  final List<({InventoryItem item, int add})> increments;

  /// New rows.
  final List<IntakeLine> additions;

  /// Open shopping-list lines this receipt satisfies.
  final List<ShoppingItem> bought;

  /// Whether there is anything to do.
  bool get isEmpty => increments.isEmpty && additions.isEmpty && bought.isEmpty;
}

/// A receipt quantity as a whole count: rounded, and never below one — a line
/// on a receipt is at least one of something, even when it was 0.4 kg.
int wholeCount(double quantity) {
  final rounded = quantity.round();
  return rounded < 1 ? 1 : rounded;
}

/// The Kotlin engine's `normalizeName`: case, the alef forms, taa marbuta,
/// alef maqsura, and the article on every word.
String normalizeItemName(String name) => name
    .trim()
    .toLowerCase()
    .replaceAll(RegExp('[أإآ]'), 'ا')
    .replaceAll('ة', 'ه')
    .replaceAll('ى', 'ي')
    .split(RegExp(r'\s+'))
    .map((w) => w.startsWith('ال') ? w.substring(2) : w)
    .join(' ');

/// The Kotlin engine's `namesMatch`: the same name once normalised, or enough
/// shared words of three letters or more — all of the shorter name's, up to
/// two.
bool itemNamesMatch(String a, String b) {
  final na = normalizeItemName(a);
  final nb = normalizeItemName(b);
  if (na == nb) return true;

  Set<String> words(String n) =>
      n.split(' ').where((w) => w.length > 2).toSet();
  final wa = words(na);
  final wb = words(nb);
  if (wa.isEmpty || wb.isEmpty) return false;

  final needed = (wa.length < wb.length ? wa.length : wb.length).clamp(0, 2);
  return wa.intersection(wb).length >= needed;
}

/// Plans what [lines] do to [pantry] and [shopping].
IntakePlan planIntake({
  required List<IntakeLine> lines,
  required List<InventoryItem> pantry,
  required List<ShoppingItem> shopping,
}) {
  // One entry per product on the receipt, quantities summed.
  final merged = <IntakeLine>[];
  for (final line in lines) {
    final i = merged.indexWhere((m) => itemNamesMatch(m.name, line.name));
    if (i < 0) {
      merged.add(line);
    } else {
      final m = merged[i];
      merged[i] = IntakeLine(
        name: m.name,
        quantity: m.quantity + line.quantity,
        unit: m.unit ?? line.unit,
        category: m.category ?? line.category,
      );
    }
  }

  // One increment per pantry row, however many lines point at it.
  final increments = <String, ({InventoryItem item, int add})>{};
  final additions = <IntakeLine>[];
  for (final line in merged) {
    final existing = pantry
        .where((p) => itemNamesMatch(p.itemName, line.name))
        .firstOrNull;
    if (existing == null) {
      additions.add(line);
    } else {
      final soFar = increments[existing.id]?.add ?? 0;
      increments[existing.id] = (item: existing, add: soFar + line.quantity);
    }
  }

  final bought = <ShoppingItem>[
    for (final s in shopping)
      if (!s.isPurchased &&
          merged.any((l) => itemNamesMatch(s.itemName, l.name)))
        s,
  ];

  return IntakePlan(
    increments: increments.values.toList(),
    additions: additions,
    bought: bought,
  );
}
