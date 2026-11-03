import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/l10n/generated/zad_l10n.dart';
import 'package:zad/shared/insights/domain/insight.dart';

void main() {
  final en = lookupZadL10n(const Locale('en'));

  test('each dismissal reason has its own words, Arabic by default', () {
    expect(DismissReason.wrongData.label(), 'الرقم غلط');
    expect(
      DismissReason.values.map((r) => r.label(en)).toSet(),
      hasLength(DismissReason.values.length),
    );
  });

  test('the card tags in English', () {
    expect(en.insightKindLabel('question'), 'Question');
    expect(en.insightKindLabel('alert'), 'Alert');
    expect(en.insightKindLabel('tip'), 'Info');
  });
}
