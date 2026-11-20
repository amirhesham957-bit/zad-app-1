/// Which drawing an item gets. Everything matched here is **data**
/// (CLAUDE.md i18n rule): words as the customer or the scanner types them,
/// Egyptian and Gulf spellings alike — never moved to l10n.
library;

import 'package:flutter/widgets.dart';
import 'package:zad/shared/worlds/art/zad_art.dart';
import 'package:zad/shared/worlds/art/zad_art_kinds.dart';

// l10n: data-begin
const Map<ZadProductArt, List<String>> _words = <ZadProductArt, List<String>>{
  ZadProductArt.milk: <String>['لبن', 'حليب', 'milk'],
  ZadProductArt.rice: <String>['=رز', 'ارز', 'أرز', 'rice', 'بسمتي'],
  ZadProductArt.eggs: <String>['بيض', 'egg'],
  ZadProductArt.tomato: <String>['طماطم', 'بندورة', 'قوطة', 'tomato'],
  ZadProductArt.bread: <String>[
    'عيش', 'خبز', 'صامولي', 'توست', 'رغيف', 'bread', //
  ],
  ZadProductArt.coffee: <String>[
    'قهوة', 'قهوه', 'نسكافيه', 'كوفي', 'شاي', 'coffee', 'tea', //
  ],
  ZadProductArt.oil: <String>['زيت', 'سمنة', 'سمن', 'oil'],
  ZadProductArt.detergent: <String>[
    'مسحوق', 'منظف', 'صابون سائل', 'سائل غسيل', 'كلور', 'detergent', //
  ],
  ZadProductArt.tissue: <String>[
    'مناديل', 'محارم', 'تواليت', 'tissue', //
  ],
  ZadProductArt.shampoo: <String>['شامبو', 'شمبو', 'بلسم', 'shampoo'],
  ZadProductArt.chickpeas: <String>[
    'حمص', 'فول', 'عدس', 'معلب', 'chickpea', //
  ],
  ZadProductArt.vinegar: <String>['=خل', 'vinegar'],
  ZadProductArt.medicine: <String>[
    'دواء', '=دوا', 'علاج', 'بنادول', 'فيتامين', 'medicine', 'pill', //
  ],
  ZadProductArt.pasta: <String>[
    'مكرونة', 'مكرونه', 'معكرونة', 'باستا', 'سباغيتي', 'pasta', //
  ],
  ZadProductArt.chicken: <String>[
    'فراخ', 'دجاج', 'دجاجة', 'chicken', //
  ],
  ZadProductArt.fish: <String>['سمك', 'سمكة', 'fish'],
  ZadProductArt.meat: <String>[
    'لحم', 'لحمة', 'كفتة', 'ستيك', 'برجر', 'meat', 'beef', //
  ],
  ZadProductArt.koshari: <String>['كشري', 'koshari'],
  ZadProductArt.salad: <String>['سلطة', 'سلطه', '=خس', 'salad'],
  ZadProductArt.blender: <String>['خلاط', 'blender'],
  ZadProductArt.airfryer: <String>['قلاية', 'اير فراير', 'airfryer'],
  ZadProductArt.ball: <String>['كورة', 'كرة', 'ball'],
};

/// Category key (what `zad_inventory.category` stores) to a carton tint.
const Map<String, Color> _tints = <String, Color>{
  'البقالة': Color(0xFFF57C00),
  'الخضار': Color(0xFF43A047),
  'الفواكه': Color(0xFFD81B60),
  'اللحوم': Color(0xFFC62828),
  'الألبان': Color(0xFF1976D2),
  'المشروبات': Color(0xFF8E24AA),
  'العناية': Color(0xFF00838F),
};
// l10n: data-end

final RegExp _split = RegExp(r'[^\p{L}]+', unicode: true);

bool _hit(String word, String text, Set<String> tokens) {
  if (word.startsWith('=')) {
    final w = word.substring(1);
    return tokens.contains(w) || tokens.contains('ال$w');
  }
  // Latin words match whole words ("egg" is not "eggplant"); Arabic ones
  // match inside a word, so "الألبان" and "ببيض" still hit.
  if (RegExp(r'^[a-z]+$').hasMatch(word)) {
    return tokens.contains(word) || tokens.contains('${word}s');
  }
  return text.contains(word);
}

bool _any(List<String> words, String text) {
  final tokens = text.split(_split).where((t) => t.isNotEmpty).toSet();
  return words.any((w) => _hit(w, text, tokens));
}

/// The drawing whose words match [itemName] (else [category] when that is
/// itself a product word); null when none does. The map's order breaks ties.
ZadProductArt? productArtFor(String itemName, {String? category}) {
  final name = itemName.toLowerCase();
  for (final e in _words.entries) {
    if (_any(e.value, name)) return e.key;
  }
  final cat = (category ?? '').toLowerCase();
  if (cat.isNotEmpty) {
    for (final e in _words.entries) {
      if (_any(e.value, cat)) return e.key;
    }
  }
  return null;
}

/// The carton tint for [category]; a neutral grey-green when unknown.
Color zadCategoryTint(String? category) =>
    _tints[category?.trim()] ?? const Color(0xFF9AA0A6);

/// The drawing for an item: its product when a word matches, else the
/// generic carton tinted by [category].
Widget zadItemArt(
  String itemName, {
  required double size,
  String? category,
  String? semanticLabel,
}) {
  final art = productArtFor(itemName, category: category);
  return art != null
      ? ZadArt.product(art, size: size, semanticLabel: semanticLabel)
      : ZadArt.box(
          tint: zadCategoryTint(category),
          size: size,
          semanticLabel: semanticLabel,
        );
}
