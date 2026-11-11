// Owner 11/11: native ads sit between cards, and the content always
// outweighs them — after the third card, then after every sixth.

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/shared/ads/presentation/native_ad.dart';

void main() {
  test('one ad after the third card, then every sixth', () {
    final after = <int>[
      for (var i = 0; i < 20; i++)
        if (nativeAdAfter(i)) i,
    ];
    expect(after, <int>[2, 8, 14]);
  });
}
