/// Kotlin's inventory categories: the eight tabs, the rule that files a row
/// under one (from its stored category, else from its name), and the picture
/// each row gets.
///
/// Everything matched here is **data** (CLAUDE.md i18n rule): the category
/// keys are what `zad_inventory.category` stores, and the words are matched
/// against what the customer or the scanner typed.
library;

/// The tabs, in Kotlin's order. The first is "everything".
const List<({String key, String emoji})> kPantryCategories =
    <({String key, String emoji})>[
      (key: 'الكل', emoji: '🏠'),
      (key: 'البقالة', emoji: '🥫'),
      (key: 'الخضار', emoji: '🥦'),
      (key: 'الفواكه', emoji: '🍎'),
      (key: 'اللحوم', emoji: '🥩'),
      (key: 'الألبان', emoji: '🥛'),
      (key: 'المشروبات', emoji: '🧃'),
      (key: 'العناية', emoji: '🧴'),
      (key: 'أخرى', emoji: '📦'),
    ];

/// The key a row files under — Kotlin's `normalizeCategoryKey`: its stored
/// category read through the word rules, and when that says nothing, its
/// name. So "كرتونة مياه" lands under المشروبات even with no category.
String pantryCategoryOf(String? category, String itemName) {
  final fromCategory = _categoryFromText(category);
  if (fromCategory != 'أخرى') return fromCategory;
  return _categoryFromText(itemName);
}

String _categoryFromText(String? raw) {
  final v = raw?.trim() ?? '';
  if (v.isEmpty) return 'أخرى';
  if (kPantryCategories.any((c) => c.key == v) && v != 'الكل') return v;
  final lower = v.toLowerCase();
  bool any(List<String> words) => words.any(v.contains);
  bool anyEn(List<String> words) => words.any(lower.contains);
  if (any(<String>[
        'خضر',
        'خضار',
        'طماطم',
        'بطاطس',
        'بصل',
        'خيار',
        'جزر',
        'فلفل',
        'سلطة', //
      ]) ||
      anyEn(<String>['vegetable'])) {
    return 'الخضار';
  }
  if (any(<String>[
        'فاكه', 'فواك', 'تفاح', 'موز', 'برتقال', 'مانجو', 'عنب', 'بطيخ', //
        'فراولة',
      ]) ||
      anyEn(<String>['fruit'])) {
    return 'الفواكه';
  }
  if (any(<String>[
        'لحم', 'لحوم', 'دجاج', 'فراخ', 'دواجن', 'سمك', 'كفتة', 'بانيه', //
      ]) ||
      anyEn(<String>['meat', 'poultry', 'fish'])) {
    return 'اللحوم';
  }
  if (any(<String>[
        'لبن',
        'ألبان',
        'البان',
        'جبن',
        'حليب',
        'زبادي',
        'قشطة',
        'زبدة',
        'بيض', //
      ]) ||
      anyEn(<String>['dairy', 'milk', 'cheese', 'yogurt'])) {
    return 'الألبان';
  }
  if (any(<String>[
        'مشروب', 'عصير', 'مياه', 'ميه', 'ماء', 'شاي', 'قهوة', 'نسكافيه', //
        'كولا', 'بيبسي',
      ]) ||
      anyEn(<String>['beverage', 'drink', 'water', 'juice', 'coffee', 'tea'])) {
    return 'المشروبات';
  }
  if (any(<String>[
        'عناي', 'تنظيف', 'نظاف', 'صابون', 'شامبو', 'معجون', 'مناديل', 'غسيل', //
        'مسحوق', 'كلور', 'ديتول',
      ]) ||
      anyEn(<String>['hygiene', 'clean', 'soap', 'shampoo'])) {
    return 'العناية';
  }
  if (any(<String>[
        'بقال', 'غذائي', 'أرز', 'ارز', 'مكرونة', 'زيت', 'سكر', 'ملح', 'دقيق', //
        'عدس', 'فول', 'خبز', 'عيش', 'معلب', 'صلصة',
      ]) ||
      anyEn(<String>[
        'grocery', 'groceries', 'rice', 'pasta', 'oil', 'sugar', 'bread', //
      ])) {
    return 'البقالة';
  }
  return 'أخرى';
}

/// A row's picture — Kotlin's `getEmojiForItem`: a known name, else its
/// category's.
String pantryEmojiOf(String itemName, String? category) {
  final n = itemName.toLowerCase();
  const byName = <(List<String>, String)>[
    (<String>['بيض'], '🥚'),
    (<String>['حليب', 'لبن'], '🥛'),
    (<String>['خبز', 'عيش', 'صامولي'], '🍞'),
    (<String>['دجاج', 'فراخ'], '🍗'),
    (<String>['لحم'], '🥩'),
    (<String>['سمك'], '🐟'),
    (<String>['طماطم', 'بندورة'], '🍅'),
    (<String>['بطاطس', 'بطاطا'], '🥔'),
    (<String>['بصل'], '🧅'),
    (<String>['تفاح'], '🍎'),
    (<String>['موز'], '🍌'),
    (<String>['برتقال'], '🍊'),
    (<String>['قهوة', 'بن'], '☕'),
    (<String>['شاي'], '🍵'),
    (<String>['سكر', 'ملح'], '🧂'),
    (<String>['زيت'], '🫙'),
    (<String>['ماء', 'مياه'], '💧'),
    (<String>['صابون'], '🧼'),
    (<String>['شامبو'], '🧴'),
    (<String>['مناديل', 'فاين'], '🧻'),
    (<String>['جبن', 'جبنة'], '🧀'),
    (<String>['أرز', 'رز'], '🍚'),
    (<String>['معكرونة', 'مكرونة'], '🍝'),
  ];
  for (final (words, emoji) in byName) {
    if (words.any(n.contains)) return emoji;
  }
  final key = pantryCategoryOf(category, itemName);
  return kPantryCategories.firstWhere((c) => c.key == key).emoji;
}

/// How full a row is, 0..1 — Kotlin assumes "full" is three times the alert
/// threshold, there being no maximum in the model.
double stockRatio(int quantity, int threshold) {
  final t = threshold < 1 ? 1 : threshold;
  return (quantity / (t * 3)).clamp(0, 1).toDouble();
}
