/// What a pharmacy receipt does to the pharmacy and the shopping list.
///
/// The grocery flow's shape (`receipt_intake.dart`): a line that names a
/// medicine already tracked adds to it, anything else becomes a new medicine,
/// and an open shopping-list line the receipt satisfies is ticked off. Pure:
/// the lines, the medicines and the list go in, a plan comes out.
///
/// Two things differ from groceries, both because a medicine's count is what
/// the dose reminders run on:
///
/// * **Units.** A medicine is counted in what one dose takes — tablets,
///   capsules, ml — while a receipt counts boxes. Kotlin's
///   `injectPharmacyReceipt` adds the box count to the tablet count, so two
///   boxes of thirty become two tablets. Here a box's contents are read from
///   the printed name when it says them ("30 قرص"), and when it does not, the
///   line is left for the customer to count rather than guessed.
/// * **Names.** Medicines differ by a letter or a strength: "فيتامين د" is not
///   "فيتامين سي", and "كونكور 5" is not "كونكور 10". The pantry's rule, which
///   ignores short words and numbers, would put one into the other; the rule
///   here needs every word of the shorter name, and no conflicting strength.
library;

import 'package:zad/features/inventory/domain/receipt_intake.dart';
import 'package:zad/features/inventory/domain/shopping_item.dart';
import 'package:zad/features/pharmacy/domain/medicine.dart';

/// A receipt line, as the pharmacy will take it.
class PharmacyLine {
  /// Creates a line.
  const new({
    required this.name,
    required this.packs,
    this.unit,
    this.category,
  });

  /// The name as printed.
  final String name;

  /// How many were bought, as a whole count — usually boxes.
  final int packs;

  /// The receipt's unit for [packs], a stored value.
  final String? unit;

  /// The line's category, a stored value.
  final String? category;
}

/// What one receipt line would do, shown before anything is written.
class RestockProposal {
  /// Creates a proposal.
  const new({
    required this.line,
    required this.unit,
    this.medicine,
    this.count,
  });

  /// The line.
  final PharmacyLine line;

  /// The tracked medicine it adds to, or null for a new one.
  final Medicine? medicine;

  /// How many [unit]s it adds, or null when the receipt does not say — a box
  /// whose contents the name does not print, going to a medicine counted in
  /// tablets.
  final int? count;

  /// The unit [count] is in: the medicine's own, for a tracked one.
  final String unit;

  /// Whether this starts a new medicine.
  bool get isNew => medicine == null;

  /// Whether the customer has to say how many.
  bool get needsCount => count == null;

  /// The same proposal with the customer's count.
  RestockProposal withCount(int count) =>
      RestockProposal(line: line, unit: unit, medicine: medicine, count: count);
}

/// What to do.
class PharmacyIntakePlan {
  /// Creates a plan.
  const new({
    required this.restocks,
    required this.additions,
    required this.bought,
    required this.uncounted,
  });

  /// Tracked medicines, and how many units to add to each.
  final List<({Medicine medicine, int add})> restocks;

  /// New medicines, with their first stock.
  final List<({String name, int count, String unit, String? category})>
  additions;

  /// Open shopping-list lines this receipt satisfies.
  final List<ShoppingItem> bought;

  /// Lines left out because nobody said how many they hold.
  final int uncounted;
}

/// The categories a medicine is stored under — Kotlin's
/// `PharmacyScreen.PHARMACY_CATEGORIES`, and the list its scanner prompt
/// allows.
const Set<String> kMedicineCategories = <String>{
  'عام',
  'مسكن',
  'مضاد حيوي',
  'فيتامين',
  'مزمن',
};

/// A receipt line's category if it is a medicine's, or null for the column's
/// default. A grocery-style one (`ألبان`) is the model reading the line as
/// food, not a category to store on a medicine.
String? medicineCategory(String? category) => switch (category?.trim()) {
  final c? when kMedicineCategories.contains(c) => c,
  _ => null,
};

/// The unit a new medicine is counted in when its box's contents are unknown.
const String kPackUnit = 'علبة';

/// The countable unit a stored unit stands for, or null for a pack whose
/// contents it does not say (`علبة`, `عبوة`, `شريط`, `قطعة`).
///
/// Returned as the names `zad-brain`'s add-medicine tool stores, so a
/// medicine added by voice and one added from a receipt compare equal.
String? countableUnit(String? unit) {
  final u = normalizeItemName(unit ?? '');
  if (u.isEmpty) return null;
  if (_startsWithAny(u, const <String>['قرص', 'اقراص', 'حب', 'tab', 'pill'])) {
    return 'قرص';
  }
  if (_startsWithAny(u, const <String>['كبسول', 'cap'])) return 'كبسولة';
  if (_startsWithAny(u, const <String>['كيس', 'اكياس', 'sachet'])) {
    return 'كيس';
  }
  if (_startsWithAny(u, const <String>['امبول', 'amp'])) return 'أمبول';
  if (u == 'مل' || u == 'ml' || u.startsWith('مللي')) return 'مل';
  return null;
}

/// What one box holds, read off a printed name: "كونكور 5 مجم 30 قرص" holds
/// 30 tablets. Strengths (`مجم`, `mg`) are never a count.
({int count, String unit})? packContents(String name) {
  final match = _packPattern.firstMatch(normalizeItemName(_latinDigits(name)));
  if (match == null) return null;
  final count = int.tryParse(match.group(1)!);
  final unit = countableUnit(match.group(2));
  if (count == null || count < 1 || unit == null) return null;
  return (count: count, unit: unit);
}

/// Whether two medicine names are the same medicine.
///
/// Every word of the shorter name must be in the longer one, and two
/// strengths that are both printed must share a number.
bool medicineNamesMatch(String a, String b) {
  final ta = _tokens(a);
  final tb = _tokens(b);
  if (ta.words.isEmpty || tb.words.isEmpty) return false;

  final (shorter, longer) = ta.words.length <= tb.words.length
      ? (ta.words, tb.words)
      : (tb.words, ta.words);
  if (!longer.containsAll(shorter)) return false;

  return ta.numbers.isEmpty ||
      tb.numbers.isEmpty ||
      ta.numbers.intersection(tb.numbers).isNotEmpty;
}

/// What [line] would do to [medicines].
RestockProposal proposeRestock(PharmacyLine line, List<Medicine> medicines) {
  final contents = packContents(line.name);
  final lineUnit = countableUnit(line.unit);

  // The line's stock in a countable unit, when it can be known.
  final (int? units, String? unit) = switch ((contents, lineUnit)) {
    (final c?, _) => (line.packs * c.count, c.unit),
    (null, final u?) => (line.packs, u),
    _ => (null, null),
  };

  final medicine = _bestMatch(line.name, medicines);
  if (medicine == null) {
    return units != null && unit != null
        ? RestockProposal(line: line, unit: unit, count: units)
        : RestockProposal(line: line, unit: kPackUnit, count: line.packs);
  }

  final tracked = countableUnit(medicine.unit);
  final count = switch ((unit, tracked)) {
    // Both in tablets (or both in ml): add them.
    (final u?, final t?) when u == t => units,
    // Both in boxes, tubes, bottles: the receipt's count is the count.
    (null, null) => line.packs,
    // Boxes into tablets, or tablets into boxes: the customer knows, we don't.
    _ => null,
  };
  return RestockProposal(
    line: line,
    unit: medicine.unit ?? kPackUnit,
    medicine: medicine,
    count: count,
  );
}

/// Plans what [proposals] — the ticked lines, with any counts the customer
/// gave — do to the pharmacy and to [shopping].
PharmacyIntakePlan planPharmacyIntake({
  required List<RestockProposal> proposals,
  required List<ShoppingItem> shopping,
}) {
  final restocks = <String, ({Medicine medicine, int add})>{};
  final additions =
      <String, ({String name, int count, String unit, String? category})>{};
  var uncounted = 0;

  for (final p in proposals) {
    final count = p.count;
    if (count == null || count < 1) {
      uncounted++;
      continue;
    }
    if (p.medicine case final medicine?) {
      final soFar = restocks[medicine.id]?.add ?? 0;
      restocks[medicine.id] = (medicine: medicine, add: soFar + count);
      continue;
    }

    final key = additions.keys
        .where((k) => medicineNamesMatch(k, p.line.name))
        .firstOrNull;
    final prior = key == null ? null : additions[key];
    if (prior == null) {
      additions[p.line.name] = (
        name: p.line.name.trim(),
        count: count,
        unit: p.unit,
        category: p.line.category,
      );
    } else if (prior.unit == p.unit) {
      additions[key!] = (
        name: prior.name,
        count: prior.count + count,
        unit: prior.unit,
        category: prior.category,
      );
    } else {
      // The same new medicine counted two ways. The server would put the
      // second count into the first one's unit, so it is left out.
      uncounted++;
    }
  }

  // Bought is about the purchase, not the count: a line the customer did not
  // count was still bought, and is still off the list.
  final names = <String>[
    for (final p in proposals) p.medicine?.name ?? p.line.name,
  ];
  final bought = <ShoppingItem>[
    for (final s in shopping)
      if (!s.isPurchased && names.any((n) => medicineNamesMatch(s.itemName, n)))
        s,
  ];

  return PharmacyIntakePlan(
    restocks: restocks.values.toList(),
    additions: additions.values.toList(),
    bought: bought,
    uncounted: uncounted,
  );
}

Medicine? _bestMatch(String name, List<Medicine> medicines) {
  final normalized = normalizeItemName(name);
  final exact = medicines
      .where((m) => normalizeItemName(m.name) == normalized)
      .firstOrNull;
  if (exact != null) return exact;

  // The most specific tracked name wins: "بانادول اكسترا" over "بانادول".
  Medicine? best;
  var bestWords = 0;
  for (final m in medicines) {
    if (!medicineNamesMatch(m.name, name)) continue;
    final words = _tokens(m.name).words.length;
    if (words > bestWords) {
      best = m;
      bestWords = words;
    }
  }
  return best;
}

/// Words that describe a pack or a strength rather than name a medicine.
const Set<String> _packWords = <String>{
  'مجم', 'ملجم', 'ملغ', 'مغ', 'جم', 'mg', 'mcg', 'g', 'ml', 'مل', 'iu', //
  'قرص', 'اقراص', 'حبه', 'حبات', 'tab', 'tabs', 'tablet', 'tablets',
  'كبسوله', 'كبسولات', 'cap', 'caps', 'capsule', 'capsules',
  'كيس', 'اكياس', 'امبول', 'امبولات', 'علبه', 'عبوه', 'شريط', 'x', '×',
};

({Set<String> words, Set<String> numbers}) _tokens(String name) {
  // Digits and letters apart, so "5mg" and "د3" are two tokens each.
  final spaced = _latinDigits(name).replaceAllMapped(
    RegExp(r'(\d+(?:\.\d+)?)'),
    (m) => ' ${m.group(1)} ',
  );
  final tokens = normalizeItemName(
    spaced,
  ).split(' ').where((t) => t.isNotEmpty);

  final words = <String>{};
  final numbers = <String>{};
  for (final t in tokens) {
    if (RegExp(r'^\d+(?:\.\d+)?$').hasMatch(t)) {
      numbers.add(t);
    } else if (!_packWords.contains(t)) {
      words.add(t);
    }
  }
  return (words: words, numbers: numbers);
}

final RegExp _packPattern = RegExp(
  r'(\d+)\s*(قرص|اقراص|حبه|حبات|tablets?|tabs?|كبسوله|كبسولات|capsules?|caps?'
  '|كيس|اكياس|sachets?|امبول|امبولات|ampoules?|amps?|مل|ml)'
  // Not followed by another letter: "مل" is not the start of "ملغ".
  '(?![a-z\u0600-\u06FF])',
);

String _latinDigits(String s) => s.replaceAllMapped(
  RegExp('[٠-٩]'),
  (m) => '${m.group(0)!.codeUnitAt(0) - 0x0660}',
);

bool _startsWithAny(String s, List<String> prefixes) =>
    prefixes.any(s.startsWith);
