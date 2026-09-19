// The table's CHECK constraints, mirrored as constructors. A row that would be
// refused must be impossible to build, because a refused row becomes a dead
// letter and a dead letter is a write the user was told had saved.

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/features/transactions/domain/transaction.dart';

void main() {
  final at = DateTime.utc(2026, 9, 19, 10, 30);

  group('the shape the table will accept', () {
    test('an expense carries no transfer target', () {
      final txn = ZadTransaction.expense(
        id: 'a',
        userId: 'u',
        amount: 50,
        title: 'قهوة',
        createdAt: at,
        wallet: Wallet.cash,
        category: 'مأكولات',
      );

      final row = txn.toInsertJson();
      expect(row['txn_kind'], 'expense');
      expect(row['is_expense'], true);
      // transfer_needs_target: a non-transfer must have a null target.
      expect(row['transfer_to'], isNull);
    });

    test('income agrees with is_expense, which the trigger trusts', () {
      final txn = ZadTransaction.income(
        id: 'a',
        userId: 'u',
        amount: 5000,
        title: 'راتب',
        createdAt: at,
        wallet: Wallet.bank,
      );

      // zad_enforce_txn_kind rewrites txn_kind from is_expense, so sending the
      // two disagreeing would silently change the row. They cannot disagree.
      expect(txn.isExpense, isFalse);
      expect(txn.kind, TxnKind.income);
    });

    test('a transfer always names where the money went', () {
      final txn = ZadTransaction.transfer(
        id: 'a',
        userId: 'u',
        amount: 200,
        title: 'من الكاش للبنك',
        createdAt: at,
        from: Wallet.cash,
        to: Wallet.bank,
      );

      expect(txn.toInsertJson()['transfer_to'], 'bank');
      expect(txn.countsTowardBudget, isFalse, reason: 'moving is not spending');
    });

    test('a transfer to the wallet it came from is refused here', () {
      expect(
        () => ZadTransaction.transfer(
          id: 'a',
          userId: 'u',
          amount: 200,
          title: 'لا شيء',
          createdAt: at,
          from: Wallet.cash,
          to: Wallet.cash,
        ),
        throwsArgumentError,
      );
    });
  });

  test('amounts are rounded on the way in', () {
    final txn = ZadTransaction.expense(
      id: 'a',
      userId: 'u',
      amount: 33.333333,
      title: 'x',
      createdAt: at,
      wallet: Wallet.card,
    );
    expect(txn.amount, 33.33);
  });

  group('reading the server back', () {
    test('the server row wins, including an amount it converted', () {
      // What zad_normalize_transaction_currency does to a foreign-currency row:
      // the amount becomes the account's currency and the original moves aside.
      final txn = ZadTransaction.fromJson(<String, dynamic>{
        'id': 'a',
        'user_id': 'u',
        'amount': 1550.25,
        'title': 'فندق',
        'created_at': '2026-09-19T10:30:00Z',
        'wallet': 'card',
        'txn_kind': 'expense',
        'is_expense': true,
        'currency': 'EGP',
        'counts_toward_budget': true,
      });

      expect(txn.amount, 1550.25);
      expect(txn.currency, 'EGP');
      expect(txn.isPending, isFalse);
    });

    test('an unknown wallet or kind falls back to the column default', () {
      final txn = ZadTransaction.fromJson(<String, dynamic>{
        'id': 'a',
        'user_id': 'u',
        'amount': 10.0,
        'title': 'x',
        'created_at': '2026-09-19T10:30:00Z',
        'wallet': 'crypto',
        'txn_kind': 'refund',
      });

      expect(txn.wallet, Wallet.card);
      expect(txn.kind, TxnKind.expense);
    });

    test('created_at is normalised to UTC so period comparison is exact', () {
      final txn = ZadTransaction.fromJson(<String, dynamic>{
        'id': 'a',
        'user_id': 'u',
        'amount': 10.0,
        'title': 'x',
        'created_at': '2026-09-19T13:30:00+03:00',
        'wallet': 'card',
        'txn_kind': 'expense',
      });

      expect(txn.createdAt.isUtc, isTrue);
      expect(txn.createdAt, DateTime.utc(2026, 9, 19, 10, 30));
    });
  });

  test('the pending flag is local and never sent', () {
    final txn = ZadTransaction.expense(
      id: 'a',
      userId: 'u',
      amount: 1,
      title: 'x',
      createdAt: at,
      wallet: Wallet.card,
      isPending: true,
    );

    expect(txn.toInsertJson().containsKey('_pending'), isFalse);
    expect(txn.toCacheJson()['_pending'], isTrue);
  });
}
