/// The expense categories, one name each (ZAD_LIVING_BRAIN.md §11, owner's
/// decision 2026-10-05: «تصنيف الخصم السريع»).
///
/// The quick expense and the full form used free text — empty became
/// «أخرى», a default of «عام» stayed «عام», and anything typed was its own
/// category: 18 of the account's 39 rows were «أخرى» on 2026-10-05, so every
/// guard that reads categories (bills, wellbeing, life shifts) saw half the
/// spending. The names here are the scanner's and the server's
/// (`kStandardCategories`, `zad_canonical_category`) plus «الترفيه» and
/// «الملابس», which the brain uses — the server folds any other spelling into
/// them anyway. Stored values: never translate them.
library;

/// What an expense may be, in the order the picker shows them.
const List<String> kExpenseCategories = <String>[
  'البقالة',
  'المطاعم',
  'المواصلات',
  'الوقود',
  'الفواتير',
  'الاشتراكات',
  'الرعاية الصحية',
  'التعليم',
  'الترفيه',
  'الملابس',
  'الأقساط',
  'أخرى',
];

/// Words in an expense's title that say its category. Matched on the
/// normalized title (أ/إ/آ→ا, ة→ه, ى→ي), as whole words or prefixes.
/// Stored-data vocabulary, like the bank parser's: never translate.
const Map<String, List<String>> _hints = <String, List<String>>{
  'البقالة': <String>[
    'بقاله',
    'سوبر',
    'ماركت',
    'هايبر',
    'عيش',
    'لبن',
    'خضار',
    'فاكهه',
    'رز',
    'زيت',
    'سكر',
    'بيض',
    'كارفور',
    'لولو',
    'بنده',
    'خير زمان',
    'جمعيه',
  ],
  'المطاعم': <String>[
    'مطعم',
    'كافيه',
    'قهوه',
    'كوفي',
    'ستاربكس',
    'ماكدونالدز',
    'كنتاكي',
    'بيتزا',
    'شاورما',
    'برجر',
    'فطار',
    'غدا بره',
    'طلبات',
    'دليفري',
  ],
  'المواصلات': <String>[
    'اوبر',
    'تاكسي',
    'مترو',
    'ميكروباص',
    'اتوبيس',
    'مواصلات',
    'سواق',
    'جراج',
    'باركنج',
  ],
  'الوقود': <String>['بنزين', 'وقود', 'سولار', 'محطه'],
  'الفواتير': <String>[
    'فاتوره',
    'كهربا',
    'كهرباء',
    'مياه',
    'غاز',
    'انترنت',
    'نت البيت',
    'رصيد',
    'شحن كارت',
  ],
  'الاشتراكات': <String>[
    'اشتراك',
    'نتفليكس',
    'شاهد',
    'سبوتيفاي',
    'يوتيوب',
    'انغامي',
    'جيم',
  ],
  'الرعاية الصحية': <String>[
    'صيدليه',
    'دوا',
    'علاج',
    'دكتور',
    'كشف',
    'تحاليل',
    'اشعه',
    'مستشفي',
    'عياده',
  ],
  'التعليم': <String>[
    'مدرسه',
    'دروس',
    'درس',
    'كورس',
    'كتب',
    'جامعه',
    'مصاريف دراسه',
  ],
  'الترفيه': <String>[
    'سينما',
    'خروجه',
    'فسحه',
    'ملاهي',
    'العاب',
    'رحله',
    'نادي',
  ],
  'الملابس': <String>['لبس', 'هدوم', 'جزمه', 'شنطه', 'قميص', 'بنطلون', 'فستان'],
  'الأقساط': <String>['قسط', 'تقسيط', 'فاليو', 'تابي', 'تمارا'],
};

String _normalize(String s) => s
    .trim()
    .toLowerCase()
    .replaceAll(RegExp('[أإآ]'), 'ا')
    .replaceAll('ة', 'ه')
    .replaceAll('ى', 'ي')
    .replaceAll(RegExp(r'\s+'), ' ');

/// The category an expense titled [title] most likely is, or null when no
/// word says — the picker then leaves the choice to the customer instead of
/// guessing «أخرى».
String? suggestExpenseCategory(String title) {
  final text = ' ${_normalize(title)} ';
  if (text.trim().isEmpty) return null;
  for (final MapEntry(key: category, value: words) in _hints.entries) {
    for (final w in words) {
      // A word at a word start: «سوبرماركت» and «السوبر» match «سوبر»;
      // «رصيدي» matches «رصيد»; «مرز» does not match «رز».
      if (RegExp('[\\s«"(]ا?ل?$w').hasMatch(text)) return category;
    }
  }
  return null;
}
