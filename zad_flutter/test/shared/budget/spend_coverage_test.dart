import 'package:flutter_test/flutter_test.dart';
import 'package:zad/shared/budget/domain/spend_coverage.dart';

SpendCoverage? _at({
  required double spent,
  required int daysLeft,
  double? cap = 3000,
  bool confirmed = true,
  int length = 30,
}) => spendCoverage(
  spent: spent,
  cap: cap,
  capConfirmed: confirmed,
  cycleLengthDays: length,
  daysLeft: daysLeft,
);

void main() {
  test('half way through, 600 of a 3000 cap reads as a 40–50% range', () {
    // Day 15 of 30 (daysLeft counts today): 1500 expected at the full cap,
    // 1125 at three quarters of it.
    final c = _at(spent: 600, daysLeft: 16)!;
    expect((c.low, c.high), (40, 50));
    expect(c.label, '40–50٪');
  });

  test('both ends rounding alike print one figure', () {
    final c = _at(spent: 100, daysLeft: 16)!;
    expect((c.low, c.high), (10, 10));
    expect(c.label, '10٪');
  });

  test('nothing recorded is blind, not hidden', () {
    final c = _at(spent: 0, daysLeft: 20)!;
    expect(c.isBlind, isTrue);
  });

  test('spending past the pace caps at 100 and reads as full', () {
    final c = _at(spent: 2900, daysLeft: 16)!;
    expect((c.low, c.high), (100, 100));
    expect(c.isFull, isTrue);
  });

  test('no confirmed cap says nothing', () {
    expect(_at(spent: 600, confirmed: false, daysLeft: 16), isNull);
    expect(_at(spent: 600, cap: null, daysLeft: 16), isNull);
    expect(_at(spent: 600, cap: 0, daysLeft: 16), isNull);
  });

  test('the first two days of a cycle say nothing', () {
    expect(_at(spent: 50, daysLeft: 30), isNull); // day 1
    expect(_at(spent: 50, daysLeft: 29), isNull); // day 2
    expect(_at(spent: 50, daysLeft: 28), isNotNull); // day 3
  });
}
