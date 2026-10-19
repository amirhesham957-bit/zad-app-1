// One purchase door (ZAD_PLAN ٣.٦ هـ, docs/agent/ZAD_PURCHASE_DOOR.md).
//
// A purchase with lines is money + pantry + pharmacy + crowd prices, and it
// goes through `PurchasesRepository.record` (`zad_record_purchase`), which
// writes all of it or none. Before ٣.٦ the receipt sheet and the camera wrote
// the expense and then the pantry as separate calls, and a failure between
// them left half a purchase.
//
// An expense written straight through `TransactionsRepository.record` is
// money only. The doors allowed to do that are listed here; each one writes
// no lines. A new one fails this test until someone decides: money only (add
// it below, saying why), or a purchase (use the purchase door).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The money-only doors, and why each has no lines.
const Map<String, String> _moneyOnly = <String, String>{
  'lib/features/transactions/presentation/add_transaction_sheet.dart':
      'typed by hand: an amount and a title',
  'lib/features/transactions/presentation/quick_expense_sheet.dart':
      'the quick amount pad',
  'lib/features/statement/presentation/statement_import_screen.dart':
      'a bank statement: rows of money, no items',
  'lib/features/bank/presentation/stuck_notifications.dart':
      'a bank notification recorded by hand',
  'lib/shared/subscriptions/application/subscriptions_controller.dart':
      'a subscription renewal',
};

/// The doors that carry lines, and must go through the purchase door.
const List<String> _purchaseDoors = <String>[
  'lib/features/scan/application/scan_controller.dart',
  'lib/features/scan/application/camera_actions.dart',
];

/// `TransactionsRepository.record((id) => …)` — the direct expense write.
final RegExp _directRecord = RegExp(r'\.record\(\s*\(\s*\w+\s*\)\s*=>');

void main() {
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test('only the money-only doors write an expense directly', () {
    final writers = <String>{
      for (final f in files)
        if (_directRecord.hasMatch(f.readAsStringSync()))
          f.path.replaceAll(r'\', '/'),
    };
    expect(
      writers.difference(_moneyOnly.keys.toSet()),
      isEmpty,
      reason:
          'A new direct expense write. If it has lines (pantry, pharmacy), '
          'send it through PurchasesRepository.record; if it is money only, '
          'add it to _moneyOnly with the reason.',
    );
    expect(
      _moneyOnly.keys.toSet().difference(writers),
      isEmpty,
      reason:
          'A listed door no longer writes directly — drop it from the list.',
    );
  });

  test('the receipt doors go through the purchase door', () {
    for (final path in _purchaseDoors) {
      final source = File(path).readAsStringSync();
      expect(source, contains('purchasesRepositoryProvider'), reason: path);
      expect(_directRecord.hasMatch(source), isFalse, reason: path);
    }
  });
}
