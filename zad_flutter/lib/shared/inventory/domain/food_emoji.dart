/// An emoji for a food name — matched against the name the customer typed, so
/// its Arabic words are data, not UI text.
library;

/// A picture for a pantry line, from words in its name — Kotlin's
/// `resolveFoodEmoji`, rule for rule. The Arabic words are matched against
/// what the customer typed, so they are data and stay as they are.
String foodEmoji(String name) {
  final n = name.trim().toLowerCase();
  bool has(List<String> words) => words.any(n.contains);
  const rules = <(List<String>, String)>[
    (<String>['موز', 'banana'], '🍌'),
    (<String>['تفاح', 'apple'], '🍎'),
    (<String>['برتقال', 'يوسفي', 'orange'], '🍊'),
    (<String>['فراول', 'strawberr'], '🍓'),
    (<String>['عنب', 'grape'], '🍇'),
    (<String>['بطيخ', 'شمام', 'melon'], '🍉'),
    (<String>['تمر', 'بلح', 'رطب', 'date'], '🌴'),
    (<String>['ليمون', 'lemon'], '🍋'),
    (<String>['طماطم', 'بندورة', 'tomato'], '🍅'),
    (<String>['بطاطس', 'بطاطا', 'potato'], '🥔'),
    (<String>['بصل', 'onion'], '🧅'),
    (<String>['ثوم', 'garlic'], '🧄'),
    (<String>['خيار', 'cucumber'], '🥒'),
    (<String>['جزر', 'carrot'], '🥕'),
    (<String>['خس', 'سلطة', 'جرجير', 'salad'], '🥬'),
    (<String>['فلفل', 'شطة', 'pepper'], '🫑'),
    (<String>['أرز', 'رز', 'عيش', 'rice'], '🍚'),
    (<String>['دجاج', 'فراخ', 'شاورما', 'chicken'], '🍗'),
    (<String>['لحم', 'كفتة', 'برجر', 'ستيك', 'meat', 'beef'], '🥩'),
    (<String>['سمك', 'تونة', 'جمبري', 'سالمون', 'fish', 'tuna'], '🐟'),
    (<String>['بيض', 'egg'], '🥚'),
    (<String>['حليب', 'لبن', 'milk'], '🥛'),
    (<String>['زبادي', 'لبنة', 'روب', 'yogurt'], '🥣'),
    (<String>['جبن', 'جبنة', 'قشطة', 'cheese'], '🧀'),
    (<String>['زبدة', 'سمن', 'butter'], '🧈'),
    (<String>['خبز', 'توست', 'صامولي', 'فينو', 'فطير', 'bread'], '🍞'),
    (
      <String>[
        'مكرونة',
        'معكرونة',
        'باستا',
        'نودلز',
        'اندومي',
        'pasta',
        'noodle',
      ],
      '🍝',
    ),
    (<String>['زيت', 'زيتون', 'oil', 'olive'], '🫒'),
    (<String>['سكر', 'sugar'], '🧂'),
    (<String>['ملح', 'بهار', 'salt'], '🧂'),
    (<String>['شاي', 'كرك', 'tea'], '🫖'),
    (<String>['قهوة', 'بن', 'نسكافيه', 'اسبريسو', 'coffee'], '☕'),
    (<String>['عصير', 'juice'], '🧃'),
    (<String>['ماء', 'مياه', 'water'], '💧'),
    (<String>['مايونيز', 'mayo'], '🥫'),
    (<String>['كاتشب', 'صلصة', 'طحينة', 'sauce'], '🥫'),
    (<String>['شيبس', 'شيبسي', 'chips'], '🍟'),
    (<String>['شوكولات', 'نوتيلا', 'كيك', 'chocolate'], '🍫'),
    (<String>['بسكويت', 'كوكيز', 'cookie'], '🍪'),
    (<String>['صابون', 'مسحوق', 'شامبو', 'كلور', 'تايد', 'soap'], '🧼'),
    (<String>['مناديل', 'فاين', 'tissue'], '🧻'),
    (<String>['بنزين', 'وقود', 'fuel'], '⛽'),
    (<String>['دواء', 'علاج', 'مسكن', 'بنادول', 'panadol'], '💊'),
  ];
  for (final (words, emoji) in rules) {
    if (has(words)) return emoji;
  }
  return '🍽️';
}
