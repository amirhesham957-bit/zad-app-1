import 'package:flutter_test/flutter_test.dart';
import 'package:zad/shared/transactions/domain/for_person.dart';

/// The cases `zad-brain/storeSeen_test.ts` holds for the server's
/// `normalizeForPerson`, so the app and the chat store one name per person.
void main() {
  test('cleans, trims and caps like the server', () {
    expect(normalizeForPerson(' ماما '), 'ماما');
    expect(normalizeForPerson('أنا'), isNull);
    expect(normalizeForPerson(''), isNull);
    expect(normalizeForPerson(null), isNull);
    expect(normalizeForPerson('«يوسف»\n'), 'يوسف');
    expect(normalizeForPerson('x' * 80), hasLength(40));
  });

  test('kinship words become one name', () {
    for (final w in <String>[
      'ماما', 'أمي', 'امي', 'والدتي', 'لماما', 'لـ ماما', 'Mom', //
    ]) {
      expect(normalizeForPerson(w), 'ماما', reason: w);
    }
    for (final w in <String>['بابا', 'أبويا', 'والدي', 'لبابا']) {
      expect(normalizeForPerson(w), 'بابا', reason: w);
    }
    expect(normalizeForPerson('جدتي'), 'تيتا');
    expect(normalizeForPerson('زوجتي'), 'مراتي');
  });

  test('a name that starts with ل stays a name; «ليا» is the customer', () {
    expect(normalizeForPerson('لينا'), 'لينا');
    expect(normalizeForPerson('سارة'), 'سارة');
    expect(normalizeForPerson('ليا'), isNull);
  });
}
