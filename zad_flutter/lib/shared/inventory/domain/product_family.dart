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
import 'package:zad/shared/inventory/domain/shopping_item.dart';

/// First word (normalised with [normalizeItemName]) → the family it names.
const Map<String, String> _staples = <String, String>{
  'ماء': 'مياه',
  'مياه': 'مياه',
  'ميه': 'مياه',
  // «كرتونة ماية» on the owner's list (2026-10-01): ماية, normalised.
  'مايه': 'مياه',
  'ميا': 'مياه',
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

/// How a staple is packed, written before it: «عبوة مياه», «كرتونة ماية»,
/// «كيس سكر». Skipped when looking for the staple — the owner's list had
/// «عبوة مياه» and «كرتونة ماية» as lines of their own beside five brands of
/// water (2026-10-01). Normalised like [normalizeItemName]; data, not UI text.
const Set<String> _packaging = <String>{
  'عبوه',
  'كرتونه',
  'كرتون',
  'زجاجه',
  'ازازه',
  'قزازه',
  'جالون',
  'باكو',
  'باكت',
  'كيس',
  'علبه',
  'شكاره',
  'كيلو',
  'لتر',
  'صندوق',
};

/// The family [name] belongs to, or null when it is not a grouped staple.
String? productFamilyOf(String name) {
  final words = normalizeItemName(name)
      .split(' ')
      .where((w) => w.isNotEmpty)
      .toList();
  var i = 0;
  while (i < words.length - 1 && _packaging.contains(words[i])) {
    i++;
  }
  if (i >= words.length) return null;
  final first = _staples[words[i]];
  if (first != null) return first;
  // Brand first: «صافي مياه معدنية 1.5 لتر» stood alone beside nine water
  // rows (2026-10-01). Water only — «بسكويت شاي» is not tea.
  final next = i + 1 < words.length ? _staples[words[i + 1]] : null;
  return next == 'مياه' ? next : null;
}

/// What tells [name] apart inside its family: «ماء إيلان» → «إيلان». The
/// whole name when nothing is left, or when it is not a staple.
String brandWithinFamily(String name) {
  if (productFamilyOf(name) == null) return name.trim();
  final words = name.trim().split(RegExp(r'\s+'));
  final rest = <String>[
    for (final w in words)
      if (!_packaging.contains(normalizeItemName(w)) &&
          _staples[normalizeItemName(w)] == null)
        w,
  ];
  return rest.isEmpty ? name.trim() : rest.join(' ');
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

/// Shopping lines that are one need: a staple's brands, or a single line.
class ShoppingGroup {
  /// Creates a group.
  const new({required this.lines, this.family});

  /// The staple, or null for a line that stands alone.
  final String? family;

  /// Its lines, in list order.
  final List<ShoppingItem> lines;

  /// More than one line under one staple.
  bool get isFamily => family != null && lines.length > 1;

  /// What the list calls it: the staple, or the line's own name.
  String get name => isFamily ? family! : lines.first.itemName;

  /// Every line ticked.
  bool get allPurchased => lines.every((l) => l.isPurchased);
}

/// [lines] as needs: the owner's list held seven lines of water — five
/// brands, «عبوة مياه» and «كرتونة ماية» — each with its own tick, over
/// lines from August (2026-10-01). A staple's lines are one group, placed
/// where its first line was.
List<ShoppingGroup> groupShoppingLines(Iterable<ShoppingItem> lines) {
  final byFamily = <String, List<ShoppingItem>>{};
  final order = <Object>[];
  for (final line in lines) {
    final family = productFamilyOf(line.itemName);
    if (family == null) {
      order.add(line);
      continue;
    }
    final members = byFamily[family];
    if (members == null) {
      byFamily[family] = <ShoppingItem>[line];
      order.add(family);
    } else {
      members.add(line);
    }
  }
  return <ShoppingGroup>[
    for (final entry in order)
      if (entry is ShoppingItem)
        ShoppingGroup(lines: <ShoppingItem>[entry])
      else
        ShoppingGroup(family: entry as String, lines: byFamily[entry]!),
  ];
}

/// How much of [name] the house holds, or null when the pantry has none of
/// it: the staple across every brand, or the rows with the same name.
({int total, bool isLow})? pantryStockFor(
  String name,
  List<InventoryItem> pantry,
) {
  final family = productFamilyOf(name);
  final rows = <InventoryItem>[
    for (final item in pantry)
      if (family != null
          ? productFamilyOf(item.itemName) == family
          : normalizeItemName(item.itemName) == normalizeItemName(name))
        item,
  ];
  if (rows.isEmpty) return null;
  final group = PantryGroup(members: rows, family: family);
  if (group.total <= 0) return null;
  return (total: group.total, isLow: group.isLow);
}
