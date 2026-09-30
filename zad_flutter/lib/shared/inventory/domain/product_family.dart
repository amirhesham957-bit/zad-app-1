/// Product families: rows of the same staple under different brands.
///
/// The owner's pantry held eight bottles of water as five rows — «ماء
/// إيلان», «ماء بونا», «مياه إيلا…», «مياه دا…», «مياه نـ…» — and every one
/// of them read as its own thing: each flagged «منخفض», each put on the
/// shopping list, while the house had plenty of water (2026-09-30). For a
/// staple the question is "do we have water", not "do we have this brand".
///
/// So rows whose name starts with the same staple are one family: its stock
/// is the sum of the rows, it runs low once, and it goes on the list once,
/// under the staple's name. Only the staples below are grouped. Everything
/// else keeps one row per name — olive oil is not sunflower oil, and white
/// cheese is not a slice of rumi.
///
/// These words are matched against what the scanner and the customer wrote,
/// so they are data, not UI text: never translate them.
library;

import 'package:zad/shared/inventory/domain/inventory_item.dart';
import 'package:zad/shared/inventory/domain/receipt_intake.dart';

/// First word (normalised with [normalizeItemName]) → the family it names.
const Map<String, String> _staples = <String, String>{
  'ماء': 'مياه',
  'مياه': 'مياه',
  'ميه': 'مياه',
  'water': 'مياه',
  'رز': 'رز',
  'ارز': 'رز',
  'سكر': 'سكر',
  'ملح': 'ملح',
  'دقيق': 'دقيق',
  'بيض': 'بيض',
  'بيضه': 'بيض',
  'عيش': 'عيش',
  'خبز': 'عيش',
  'مكرونه': 'مكرونه',
  'معكرونه': 'مكرونه',
  'شاي': 'شاي',
  'حليب': 'حليب',
  'لبن': 'لبن',
  'زبادي': 'زبادي',
  'مناديل': 'مناديل',
};

/// The family [name] belongs to, or null when it is not a grouped staple.
String? productFamilyOf(String name) {
  final words = normalizeItemName(name).split(' ');
  if (words.isEmpty) return null;
  return _staples[words.first];
}

/// Whether [a] and [b] are the same staple under any brand.
bool sameProductFamily(String a, String b) {
  final fa = productFamilyOf(a);
  return fa != null && fa == productFamilyOf(b);
}

/// Rows that count as one stock: a staple's brands, or a single row.
class PantryGroup {
  /// Creates a group.
  const new({required this.members, this.family});

  /// The staple, or null for a row that stands alone.
  final String? family;

  /// Its rows, largest stock first.
  final List<InventoryItem> members;

  /// More than one row under one staple.
  bool get isFamily => family != null && members.length > 1;

  /// The stock across every row.
  int get total => members.fold(0, (sum, m) => sum + m.quantity);

  /// The highest threshold any row set — a family runs low when the whole
  /// house is down to what one row would call low.
  int get threshold =>
      members.map((m) => m.effectiveThreshold).reduce((a, b) => a > b ? a : b);

  /// Out of every brand at once.
  bool get isOut => total <= 0;

  /// At or below [threshold] across every row.
  bool get isLow => total <= threshold;

  /// What the shopping list and the shortage banner call it: the staple
  /// («مياه»), or the row's own name. Always the staple's one spelling, never
  /// the largest row's: a list line named «ماء» one day and «مياه» the next
  /// would be two lines for one need.
  String get name => isFamily ? family! : members.first.itemName;

  /// The one row standing for the whole family on a list: the largest row,
  /// renamed to [name] and carrying [total].
  InventoryItem get representative => isFamily
      ? members.first.copyWith(itemName: name, quantity: total)
      : members.first;
}

/// [items] as stock groups, in the order their first row appears.
List<PantryGroup> groupPantry(List<InventoryItem> items) {
  final byFamily = <String, List<InventoryItem>>{};
  final order = <Object>[];
  for (final item in items) {
    final family = productFamilyOf(item.itemName);
    if (family == null) {
      order.add(item);
      continue;
    }
    final members = byFamily[family];
    if (members == null) {
      byFamily[family] = <InventoryItem>[item];
      order.add(family);
    } else {
      members.add(item);
    }
  }
  return <PantryGroup>[
    for (final entry in order)
      if (entry is InventoryItem)
        PantryGroup(members: <InventoryItem>[entry])
      else
        PantryGroup(
          family: entry as String,
          members: byFamily[entry]!
            ..sort((a, b) => b.quantity.compareTo(a.quantity)),
        ),
  ];
}
