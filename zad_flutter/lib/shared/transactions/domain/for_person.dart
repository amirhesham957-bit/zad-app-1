/// «لمين؟» on a transaction — `zad_transactions.for_person` (ZAD_PLAN 5.3).
///
/// The same normalising the brain does in `zad-brain/shared.ts`'
/// `normalizeForPerson`, character for character. It is not cosmetic: the
/// brain's «صرفنا كام على يوسف؟» groups rows by the exact stored string, so a
/// «أمي» written here and a «ماما» written by the chat would be two people.
/// `test/shared/transactions/for_person_test.dart` pins the two together.
library;

/// One canonical name per known kinship word («أمي» ← «ماما»). Any other
/// name («سارة», «عم أحمد») stays as typed.
final List<(RegExp, String)> _kin = <(RegExp, String)>[
  (
    RegExp(
      r'^(ماما|مامتي|امي|أمي|إمي|والدتي|الوالدة|امى|أمى|mama|mom|mum|mother)$',
      caseSensitive: false,
    ),
    'ماما',
  ),
  (
    RegExp(
      '^(بابا|باباي|ابويا|أبويا|ابوي|أبوي|ابي|أبي|والدي|الوالد'
      r'|papa|dad|father)$',
      caseSensitive: false,
    ),
    'بابا',
  ),
  (
    RegExp(r'^(تيتا|ستي|ستّي|جدتي|جدّتي|نانا|grandma)$', caseSensitive: false),
    'تيتا',
  ),
  (RegExp(r'^(جدو|جدي|جدّي|grandpa)$', caseSensitive: false), 'جدو'),
  (RegExp(r'^(مراتي|زوجتي|المدام|wife)$', caseSensitive: false), 'مراتي'),
  (RegExp(r'^(جوزي|زوجي|husband)$', caseSensitive: false), 'جوزي'),
];

final RegExp _control = RegExp('[\u0000-\u001f\u007f«»]');
final RegExp _spaces = RegExp(r'\s+');
final RegExp _laTatweel = RegExp(r'^لـ\s*');
final RegExp _laKin = RegExp(
  r'^ل(?=(ماما|بابا|تيتا|جدو|مراتي|جوزي|امي|أمي|ابويا|أبويا|والدتي|والدي)$)',
);
final RegExp _self = RegExp(
  r'^(انا|أنا|ليا|لي|نفسي|me|myself)$',
  caseSensitive: false,
);

/// The name to store, or null meaning the customer or the whole house.
String? normalizeForPerson(String? raw) {
  if (raw == null) return null;
  var name = raw.replaceAll(_control, ' ').replaceAll(_spaces, ' ').trim();
  if (name.length > 40) name = name.substring(0, 40);
  if (name.isEmpty) return null;
  // «لماما» / «لـ ماما»: the preposition is not part of the name — only in
  // front of a kinship word, so «لينا» stays a name.
  name = name.replaceFirst(_laTatweel, '').replaceFirst(_laKin, '').trim();
  if (name.isEmpty) return null;
  if (_self.hasMatch(name)) return null;
  for (final (re, canonical) in _kin) {
    if (re.hasMatch(name)) return canonical;
  }
  return name;
}
