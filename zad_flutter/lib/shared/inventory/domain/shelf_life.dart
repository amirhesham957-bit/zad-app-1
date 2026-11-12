/// How long a pantry item usually keeps, guessed from its name and category,
/// and the civil-date arithmetic the expiry field's quick picks use.
///
/// Measured 2026-11-12: 40 pantry rows across 6 accounts, none with an expiry
/// date — typing `YYYY-MM-DD` was too much to ask. A guess the customer can
/// overwrite is better than no date: it is what «ينتهي قريباً» reads.
///
/// Every word matched here is **data** (CLAUDE.md i18n rule): it is compared
/// with what the customer or the scanner typed, and the categories are the
/// values `zad_inventory.category` stores. Never translate them.
library;

/// A civil date: [today] moved by [days], at midnight UTC as
/// `InventoryItem.expiryDate` keeps it. [today] is the account zone's day —
/// pass it in, never read the device's clock here.
DateTime civilDatePlusDays(DateTime today, int days) =>
    DateTime.utc(today.year, today.month, today.day + days);

/// What the quick chips under the expiry field set: three days, a week, a
/// month.
const List<int> kExpiryQuickDays = <int>[3, 7, 30];

/// Days an item of this [category] called [itemName] usually keeps, or null
/// when there is no honest guess (cleaning things, medicine, anything not
/// recognised).
///
/// The name is read before the category: the add dialog starts on «البقالة»,
/// so a customer who types «عيش» and leaves the category alone has told us
/// more with the name. Frozen beats everything — «فراخ مجمدة» is not a
/// three-day item — and a non-food category or name means no guess at all.
int? guessShelfLifeDays({required String itemName, String? category}) {
  final name = itemName.trim().toLowerCase();
  final cat = (category ?? '').trim().toLowerCase();
  bool hits(String text, List<String> words) =>
      text.isNotEmpty && words.any(text.contains);

  if (hits(name, _frozen) || hits(cat, _frozen)) return 90;
  if (hits(name, _nonFood) || hits(cat, _nonFood)) return null;
  for (final text in <String>[name, cat]) {
    for (final (words, days) in _rules) {
      if (hits(text, words)) return days;
    }
  }
  return null;
}

/// The guessed expiry date for an item bought [today], or null when
/// [guessShelfLifeDays] has no guess.
DateTime? guessExpiryDate({
  required String itemName,
  required DateTime today,
  String? category,
}) {
  final days = guessShelfLifeDays(itemName: itemName, category: category);
  return days == null ? null : civilDatePlusDays(today, days);
}

// l10n: data-begin
const List<String> _frozen = <String>['مجمد', 'مجمّد', 'فريزر', 'frozen'];

const List<String> _nonFood = <String>[
  'عناي',
  'رعاية',
  'تنظيف',
  'نظاف',
  'منظف',
  'صابون',
  'شامبو',
  'معجون',
  'مناديل',
  'غسيل',
  'مسحوق',
  'كلور',
  'ديتول',
  'صيدلي',
  'دواء',
  'أدوية',
  'ادوية',
  'clean',
  'soap',
  'shampoo',
  'detergent',
  'hygiene',
  'tissue',
  'toilet',
  'pharma',
];

/// Food, most perishable first. Order matters only between rules a single
/// word could satisfy twice.
const List<(List<String>, int)> _rules = <(List<String>, int)>[
  // Fresh meat, poultry, fish.
  (
    <String>[
      'لحم',
      'لحوم',
      'دجاج',
      'فراخ',
      'دواجن',
      'سمك',
      'أسماك',
      'جمبري',
      'كفتة',
      'بانيه',
      'كبدة',
      'meat',
      'chicken',
      'poultry',
      'fish',
      'beef',
    ],
    3,
  ),
  // Bread and bakery.
  (
    <String>[
      'خبز',
      'عيش',
      'صامولي',
      'توست',
      'مخبوز',
      'معجنات',
      'bread',
      'bakery',
      'toast',
    ],
    4,
  ),
  // Eggs keep longer than milk.
  (<String>['بيض', 'egg'], 21),
  // Dairy.
  (
    <String>[
      'ألبان',
      'البان',
      'لبن',
      'حليب',
      'جبن',
      'زبادي',
      'قشطة',
      'زبدة',
      'dairy',
      'milk',
      'cheese',
      'yogurt',
      'butter',
    ],
    7,
  ),
  // Vegetables.
  (
    <String>[
      'خضر',
      'خضار',
      'طماطم',
      'بندورة',
      'خيار',
      'خس',
      'جرجير',
      'فلفل',
      'كوسة',
      'باذنجان',
      'سلطة',
      'vegetable',
      'salad',
    ],
    5,
  ),
  // Fruit.
  (
    <String>[
      'فاكه',
      'فواك',
      'تفاح',
      'موز',
      'برتقال',
      'يوسفي',
      'مانجو',
      'عنب',
      'فراولة',
      'خوخ',
      'fruit',
      'apple',
      'banana',
    ],
    7,
  ),
  // Dry goods, tins and the rest of the grocery shelf.
  (
    <String>[
      'بقال',
      'غذائي',
      'أرز',
      'ارز',
      'رز',
      'مكرونة',
      'معكرونة',
      'زيت',
      'سكر',
      'ملح',
      'دقيق',
      'عدس',
      'فول',
      'معلب',
      'تونة',
      'صلصة',
      'grocery',
      'groceries',
      'rice',
      'pasta',
      'oil',
      'sugar',
      'flour',
      'canned',
    ],
    180,
  ),
];
// l10n: data-end
