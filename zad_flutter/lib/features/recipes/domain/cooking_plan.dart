/// «طبختها» (ZAD_PLAN 10.1 slice 4c): which pantry rows a cooked recipe
/// used, and how much to take off each, before the customer confirms.
///
/// The recipe's lines say «٢ كوب رز» or «بصلة», never the pantry's unit, so
/// the amount is a suggestion the sheet shows with a stepper — a number Zad
/// is not sure of is asked, not written.
library;

import 'package:zad/shared/inventory/domain/inventory_item.dart';
import 'package:zad/shared/inventory/domain/receipt_intake.dart';

/// One pantry row a recipe used.
class CookLine {
  /// Creates a line.
  const new({required this.item, required this.amount});

  /// The row.
  final InventoryItem item;

  /// What to take off, in the row's unit; never more than it holds.
  final double amount;
}

// l10n: data-begin
// Units, as stored in zad_inventory.unit — matched, never shown.
const Set<String> _bulk = <String>{
  'كجم',
  'كيلو',
  'كيلوجرام',
  'كيلوغرام',
  'كغ',
  'kg',
  'لتر',
  'l',
  'liter',
  'litre',
};
const Set<String> _fine = <String>{
  'جرام',
  'جم',
  'غرام',
  'غ',
  'g',
  'gm',
  'مل',
  'ملي',
  'ml',
};
const Map<String, String> _arabicDigits = <String, String>{
  '٠': '0',
  '١': '1',
  '٢': '2',
  '٣': '3',
  '٤': '4',
  '٥': '5',
  '٦': '6',
  '٧': '7',
  '٨': '8',
  '٩': '9',
};
// l10n: data-end

Set<String> _words(String s) =>
    normalizeItemName(s)
        .split(' ')
        .where((w) => w.length >= 2 && double.tryParse(w) == null)
        .toSet();

/// Whether the recipe line [line] names the pantry row [itemName]: every word
/// of the row's name is in the line («رز» in «٢ كوب رز مصري»). A word of
/// three letters or more also matches the same word with up to two letters
/// more, which is how recipes write one or many: «بيض» ⇒ «بيضات»,
/// «بصل» ⇒ «بصلة». The sheet shows every match before anything is taken off.
bool ingredientUses(String line, String itemName) {
  final item = _words(itemName);
  if (item.isEmpty) return false;
  final words = _words(line);
  bool found(String w) =>
      words.contains(w) ||
      (w.length >= 3 &&
          words.any((l) => l.startsWith(w) && l.length - w.length <= 2));
  return item.every(found);
}

double? _leadingCount(String line) {
  final latin = line.split('').map((c) => _arabicDigits[c] ?? c).join();
  final m = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(latin);
  return m == null ? null : double.tryParse(m.group(1)!);
}

/// The suggested amount of [item] for the recipe line [line].
///
/// Kilos and litres: a quarter. Grams and millilitres: 250. Anything counted
/// (pieces, packs, a row with no unit): the line's own number when it has one
/// («٣ بيضات»), else one. Never more than the row holds.
double cookPortion(InventoryItem item, String line) {
  final unit = (item.unit ?? '').trim().toLowerCase();
  final suggested = _bulk.contains(unit)
      ? 0.25
      : _fine.contains(unit)
      ? 250.0
      : (_leadingCount(line) ?? 1).clamp(1, 12).toDouble();
  return suggested > item.quantity ? item.quantity : suggested;
}

/// The pantry rows in stock that the recipe's [ingredients] name, each once,
/// in the recipe's order.
List<CookLine> cookingPlan(
  List<String> ingredients,
  List<InventoryItem> pantry,
) {
  final out = <CookLine>[];
  final taken = <String>{};
  for (final line in ingredients) {
    for (final item in pantry) {
      if (item.quantity <= 0 || taken.contains(item.id)) continue;
      if (!ingredientUses(line, item.itemName)) continue;
      taken.add(item.id);
      out.add(CookLine(item: item, amount: cookPortion(item, line)));
    }
  }
  return out;
}
