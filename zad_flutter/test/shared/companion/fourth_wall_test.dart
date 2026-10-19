import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/shared/companion/domain/fourth_wall.dart';

void main() {
  test('poked: nothing under five, then a line, the number past eight', () {
    expect(FourthWall.poked(4, name: 'زادو'), isNull);
    expect(FourthWall.poked(5, name: 'زادو'), isNotNull);
    expect(
      FourthWall.poked(9, name: 'زادو', rng: math.Random(1)),
      contains('9'),
    );
    expect(FourthWall.poked(12, name: 'زادو'), contains('12'));
  });

  test('back: six hours to two days, in hours or as a day', () {
    expect(FourthWall.back(const Duration(hours: 5)), isNull);
    expect(FourthWall.back(const Duration(hours: 7)), contains('7'));
    expect(FourthWall.back(const Duration(hours: 30)), contains('يوم'));
    // Two days and more is the sleep moment's.
    expect(FourthWall.back(const Duration(hours: 48)), isNull);
  });

  test('the clock: the small hours and dawn speak, the day does not', () {
    expect(FourthWall.clock(2, rng: math.Random(0)), isNotNull);
    expect(FourthWall.clock(5), isNotNull);
    for (final h in <int>[7, 12, 18, 23]) {
      expect(FourthWall.clock(h), isNull);
    }
  });

  test('the paywall line never pushes a price', () {
    for (var i = 0; i < 6; i++) {
      final line = FourthWall.paywall(name: 'زادو', rng: math.Random(i));
      expect(line, isNot(matches(RegExp(r'\d'))));
    }
  });
}
