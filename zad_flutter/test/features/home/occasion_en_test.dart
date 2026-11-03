// ZAD_PLAN 8.8: the occasion card in English is one text; in Arabic it
// still follows the market's dialect.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/l10n/generated/zad_l10n.dart';
import 'package:zad/shared/brain/domain/occasion.dart';

void main() {
  test('new year card in English, and both Arabic dialects unchanged', () {
    final en = occasionOn(
      DateTime(2027),
      country: 'SA',
      l10n: lookupZadL10n(const Locale('en')),
    )!;
    expect(en.title, 'Happy New Year! 🎉');
    expect(en.question, contains('for 2027 in one tap'));
    expect(
      occasionOn(DateTime(2027), country: 'SA')!.question,
      'تبي زاد يجهّز لك خطة أهدافك المالية لسنة 2027 بضغطة وحدة؟',
    );
    expect(
      occasionOn(DateTime(2027), country: 'EG')!.question,
      'حابب زاد يجهّزلك خطة أهدافك المالية لسنة 2027 بنقرة واحدة؟',
    );
  });
}
