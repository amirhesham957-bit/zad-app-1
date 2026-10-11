// One card payment, two messages — the bank's and the receipt's — must not be
// two expenses.

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/shared/scan/domain/bank_twin.dart';
import 'package:zad/shared/transactions/domain/transaction.dart';

ZadTransaction _row(
  String id,
  double amount,
  DateTime at, {
  String? source = kBankSourceType,
  bool expense = true,
}) => ZadTransaction.fromJson(<String, dynamic>{
  'id': id,
  'user_id': 'u',
  'amount': amount,
  'title': 'BDC',
  'created_at': at.toIso8601String(),
  'txn_kind': expense ? 'expense' : 'income',
  'is_expense': expense,
  'source_type': source,
  'bank_name': 'BDC',
});

void main() {
  final paid = DateTime.utc(2026, 10, 8, 18);

  test('the bank row with the same amount within a day and a half', () {
    final twin = bankTwinOf(
      total: 820,
      spentAt: DateTime.utc(2026, 10, 9, 12),
      rows: <ZadTransaction>[_row('a', 820, paid), _row('b', 422.22, paid)],
    );
    expect(twin?.id, 'a');
  });

  test('the closest in time when two fit', () {
    final twin = bankTwinOf(
      total: 820,
      spentAt: paid,
      rows: <ZadTransaction>[
        _row('far', 820, paid.subtract(const Duration(hours: 30))),
        _row('near', 820, paid.add(const Duration(minutes: 5))),
      ],
    );
    expect(twin?.id, 'near');
  });

  test(
    'nothing for another amount, another day, or a row not from the bank',
    () {
      final rows = <ZadTransaction>[
        _row('amount', 819.5, paid),
        _row('late', 820, paid.add(const Duration(hours: 40))),
        _row('typed', 820, paid, source: null),
        _row('income', 820, paid, expense: false),
      ];
      expect(bankTwinOf(total: 820, spentAt: paid, rows: rows), isNull);
    },
  );

  test('a cash receipt has no bank twin', () {
    expect(
      bankTwinOf(
        total: 820,
        spentAt: paid,
        rows: <ZadTransaction>[_row('a', 820, paid)],
        paidWith: Wallet.cash,
      ),
      isNull,
    );
  });
}
