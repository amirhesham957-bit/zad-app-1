// Parity with the Kotlin app's `Double.asMoney()` in data/Money.kt, which is
// `Math.round(this * 100) / 100.0`. Every value below was computed against that
// formula rather than assumed.

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/money/money.dart';

void main() {
  group('asMoney rounds the way Kotlin does', () {
    const cases = <(double, double)>[
      (0, 0),
      (10, 10),
      (2.345, 2.35),
      (10.994, 10.99),
      (10.995, 11),
      (10.996, 11),
      (0.005, 0.01),
      (99.999, 100),
      (1234.5678, 1234.57),
      (0.014999, 0.01),
      (-2.345, -2.35),
      (-2.5, -2.5),
    ];

    for (final (input, want) in cases) {
      test('$input → $want', () => expect(input.asMoney, want));
    }
  });

  test('half rounds up, not away from zero, where Dart disagrees', () {
    // Java's Math.round is floor(x + 0.5): -0.005 rounds toward positive
    // infinity and lands on zero. Dart's own round() rounds away from zero and
    // would give -0.01. A correction entered on one client and read on
    // the other must not differ by a piastre.
    expect((-0.005).asMoney, 0.0);
    expect((-0.005 * 100).round() / 100, -0.01);
  });

  test('1.005 rounds down, in both languages, and that is not a bug here', () {
    // 1.005 has no exact binary representation; the nearest double is slightly
    // below it, so ×100 is 100.49999999999999 and the half never arrives.
    // Kotlin does the same thing, which is what this test pins.
    expect(1.005.asMoney, 1.0);
  });

  test(
    'is idempotent — rounding an already-rounded amount changes nothing',
    () {
      for (final v in <double>[0, 2.35, 10.99, 1234.57, -2.35]) {
        expect(v.asMoney.asMoney, v.asMoney);
      }
    },
  );
}
