// وقفة التفكير قبل الشرا (الشريحة ٣٦): رسالة الموافقة اللي جت بدري.

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/shared/family/domain/family_life.dart';

void main() {
  final now = DateTime.utc(2026, 10, 5, 12);

  test('says how many hours are left, rounded up', () {
    expect(
      coolingOffMessage(now.add(const Duration(hours: 5, minutes: 10)), now),
      startsWith('وقفة التفكير: تقدر توافق بعد 6 ساعة'),
    );
  });

  test('the last hour, and an old server without a time, still read right', () {
    expect(
      coolingOffMessage(now.add(const Duration(minutes: 20)), now),
      startsWith('وقفة التفكير: تقدر توافق خلال ساعة'),
    );
    expect(coolingOffMessage(null, now), contains('لسه ماكملش ٢٤ ساعة'));
  });

  test('always says a no is possible now', () {
    expect(
      coolingOffMessage(now.add(const Duration(hours: 20)), now),
      endsWith('أو ارفضه دلوقتي لو مش مقتنع.'),
    );
  });
}
