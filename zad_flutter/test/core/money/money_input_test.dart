// What the amount field accepts.
//
// The app is written in Arabic and an Arabic keyboard produces Arabic-Indic
// digits. A form that silently refuses ١٢٥٫٥ does not work in its own
// language, and the failure looks like a broken save button rather than a
// parse error.

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/money/money.dart';

void main() {
  group('parseMoneyInput', () {
    test('plain Latin digits', () {
      expect(parseMoneyInput('125.5'), 125.5);
      expect(parseMoneyInput('50'), 50);
    });

    test('Arabic-Indic digits, with the Arabic decimal separator', () {
      expect(parseMoneyInput('١٢٥٫٥'), 125.5);
      expect(parseMoneyInput('٥٠'), 50);
    });

    test('Persian digits too — the same keyboard family', () {
      expect(parseMoneyInput('۱۲۵'), 125);
    });

    test('a comma is a decimal point, since that is what the key produces', () {
      expect(parseMoneyInput('125,5'), 125.5);
    });

    test('stray characters are dropped, not treated as a failure', () {
      // Somebody pastes "125 ج.م" out of a bank message.
      expect(parseMoneyInput('125 ج.م'), 125);
      expect(parseMoneyInput('  50  '), 50);
    });

    test('rounds to two decimals, like every other amount in the app', () {
      expect(parseMoneyInput('33.333333'), 33.33);
    });

    test('nothing, zero and nonsense are all null', () {
      // Zero is null on purpose: a transaction of nothing is not a
      // transaction, and the save button stays disabled rather than writing
      // one.
      expect(parseMoneyInput(''), isNull);
      expect(parseMoneyInput('0'), isNull);
      expect(parseMoneyInput('٠'), isNull);
      expect(parseMoneyInput('abc'), isNull);
      expect(parseMoneyInput('-'), isNull);
    });

    test('a minus sign is dropped, so a negative cannot be typed in', () {
      // Direction is a choice on the form, not a character in the field.
      expect(parseMoneyInput('-50'), 50);
    });
  });
}
