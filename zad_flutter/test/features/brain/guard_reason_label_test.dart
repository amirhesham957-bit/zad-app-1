// A refusal's reason, in words: every door code has its ARB string in each
// language, an unknown code shows the fallback, and a validator's Arabic
// sentence is shown as it was written.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/l10n/generated/zad_l10n.dart';
import 'package:zad/features/brain/domain/guard_event.dart';

void main() {
  final ar = lookupZadL10n(const Locale('ar'));
  final en = lookupZadL10n(const Locale('en'));

  test('a door code reads as its ARB string in the app language', () {
    expect(
      guardReasonLabel(ar, 'qty_too_large'),
      'الكمية كبيرة بشكل مش منطقي — اتأكد من العميل',
    );
    expect(
      guardReasonLabel(en, 'qty_too_large'),
      'The quantity is unreasonably large — check with the customer',
    );
  });

  test('an unknown code shows the fallback, never the raw code', () {
    expect(guardReasonLabel(ar, 'no_such_code'), ar.guardReason_fallback);
    expect(guardReasonLabel(en, 'no_such_code'), en.guardReason_fallback);
    expect(guardReasonLabel(ar, '   '), ar.guardReason_fallback);
  });

  test('an Arabic sentence from a validator is shown as written', () {
    const sentence = 'الكمية لازم تكون أكبر من صفر';
    expect(guardReasonLabel(en, sentence), sentence);
  });
}
