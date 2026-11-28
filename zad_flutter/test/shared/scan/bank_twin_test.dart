// One card payment, two messages — the bank's and the receipt's — must not be
// two expenses.

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/shared/proposals/domain/transaction_proposal.dart';
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

TransactionProposal _proposal(
  String id,
  double amount,
  DateTime at, {
  String? kind = 'expense',
  String status = 'awaiting_confirmation',
}) => TransactionProposal.fromJson(<String, dynamic>{
  'id': id,
  'amount': amount,
  'title': 'فيزا',
  'status': status,
  'created_at': at.toIso8601String(),
  'expires_at': at.add(const Duration(days: 7)).toIso8601String(),
  'txn_kind': kind,
  'merchant_name': 'كارفور',
});

void main() {
  final paid = DateTime.utc(2026, 10, 8, 18);

  test('the bank row with the same amount within a day', () {
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
        _row('far', 820, paid.subtract(const Duration(hours: 20))),
        _row('near', 820, paid.add(const Duration(minutes: 5))),
      ],
    );
    expect(twin?.id, 'near');
  });

  test(
    'nothing for another amount, another day, or a row not from the bank',
    () {
      final rows = <ZadTransaction>[
        _row('amount', 790, paid),
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

  test('an ATM withdrawal moved to cash is not the twin of a card receipt', () {
    final atm = ZadTransaction.fromJson(<String, dynamic>{
      'id': 'atm',
      'user_id': 'u',
      'amount': 2000,
      'title': 'سحب كاش — NBE',
      'created_at': paid.toIso8601String(),
      'txn_kind': 'transfer',
      'transfer_to': 'cash',
      'is_expense': true,
      'source_type': kBankSourceType,
      'bank_name': 'NBE',
    });
    expect(
      bankTwinOf(total: 2000, spentAt: paid, rows: <ZadTransaction>[atm]),
      isNull,
    );
  });

  group('bankMatchOf', () {
    test('an exact amount matches', () {
      final m = bankMatchOf(
        total: 100,
        spentAt: paid,
        rows: <ZadTransaction>[_row('a', 100, paid)],
      );
      expect(m?.transaction?.id, 'a');
    });

    test('within 2 percent matches, beyond does not', () {
      bool fits(double bank) =>
          bankMatchOf(
            total: 100,
            spentAt: paid,
            rows: <ZadTransaction>[_row('a', bank, paid)],
          ) !=
          null;
      expect(fits(101.9), isTrue);
      expect(fits(98.1), isTrue);
      expect(fits(102.5), isFalse);
      expect(fits(97), isFalse);
    });

    test('a small total still allows a piaster of drift', () {
      final m = bankMatchOf(
        total: 0.5,
        spentAt: paid,
        rows: <ZadTransaction>[_row('a', 0.51, paid)],
      );
      expect(m, isNotNull);
    });

    test('outside 24 hours does not match', () {
      expect(
        bankMatchOf(
          total: 100,
          spentAt: paid,
          rows: <ZadTransaction>[
            _row('a', 100, paid.add(const Duration(hours: 25))),
          ],
        ),
        isNull,
      );
    });

    test('a pending bank notification matches', () {
      final m = bankMatchOf(
        total: 250,
        spentAt: paid,
        rows: const <ZadTransaction>[],
        proposals: <TransactionProposal>[
          _proposal('p', 250, paid.add(const Duration(hours: 1))),
        ],
      );
      expect(m?.proposal?.id, 'p');
      expect(m?.merchant, 'كارفور');
    });

    test('a proposal that needs classification still matches', () {
      final m = bankMatchOf(
        total: 250,
        spentAt: paid,
        rows: const <ZadTransaction>[],
        proposals: <TransactionProposal>[
          _proposal('p', 250, paid, kind: null, status: 'needs_classification'),
        ],
      );
      expect(m?.proposal?.id, 'p');
    });

    test('transfers, cash withdrawals and answered proposals are ignored', () {
      final m = bankMatchOf(
        total: 250,
        spentAt: paid,
        rows: const <ZadTransaction>[],
        proposals: <TransactionProposal>[
          _proposal('t', 250, paid, kind: 'transfer'),
          _proposal('c', 250, paid, kind: 'cash_withdrawal'),
          _proposal('r', 250, paid, status: 'rejected'),
        ],
      );
      expect(m, isNull);
    });

    test('a cash receipt matches neither', () {
      final m = bankMatchOf(
        total: 250,
        spentAt: paid,
        rows: <ZadTransaction>[_row('a', 250, paid)],
        proposals: <TransactionProposal>[_proposal('p', 250, paid)],
        paidWith: Wallet.cash,
      );
      expect(m, isNull);
    });

    test('the closest in time wins across both sources', () {
      final m = bankMatchOf(
        total: 250,
        spentAt: paid,
        rows: <ZadTransaction>[
          _row('far', 250, paid.add(const Duration(hours: 5))),
        ],
        proposals: <TransactionProposal>[
          _proposal('near', 250, paid.add(const Duration(minutes: 10))),
        ],
      );
      expect(m?.proposal?.id, 'near');
    });

    test('equal gaps prefer the exact amount', () {
      final m = bankMatchOf(
        total: 250,
        spentAt: paid,
        rows: <ZadTransaction>[
          _row('off', 251, paid.add(const Duration(hours: 1))),
          _row('exact', 250, paid.subtract(const Duration(hours: 1))),
        ],
      );
      expect(m?.transaction?.id, 'exact');
    });
  });
}
