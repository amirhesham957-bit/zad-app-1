import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// م٦.٥: ولا حاجة من الإشعارات (أو أي بيانات مستخدم) بتوصل AdMob.
/// كل طلب إعلان لازم يكون AdRequest فاضي، من غير keywords ولا
/// contentUrl ولا extras.
void main() {
  final files = Directory('lib/shared/ads')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test('there are ad request sites to check', () {
    var n = 0;
    for (final f in files) {
      n += 'AdRequest('.allMatches(f.readAsStringSync()).length;
    }
    expect(n, greaterThanOrEqualTo(5));
  });

  test('every AdRequest is empty (no targeting data)', () {
    for (final f in files) {
      final src = f.readAsStringSync();
      for (final m in RegExp(r'AdRequest\(([^)]*)\)').allMatches(src)) {
        expect(m.group(1)!.trim(), isEmpty, reason: f.path);
      }
      expect(src.contains('keywords:'), isFalse, reason: f.path);
      expect(src.contains('contentUrl'), isFalse, reason: f.path);
      expect(src.contains('mediationExtras'), isFalse, reason: f.path);
    }
  });
}
