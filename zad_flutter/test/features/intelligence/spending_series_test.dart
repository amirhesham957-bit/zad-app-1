// The brain screen's charts: per day and per category, from expenses only.

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/features/intelligence/domain/spending_series.dart';
import 'package:zad/shared/transactions/domain/transaction.dart';

ZadTransaction _t(
  String id,
  double amount,
  DateTime at, {
  String? category,
  TxnKind kind = TxnKind.expense,
}) => switch (kind) {
  TxnKind.expense => ZadTransaction.expense(
    id: id,
    userId: 'u',
    amount: amount,
    title: id,
    createdAt: at,
    wallet: Wallet.cash,
    category: category,
  ),
  TxnKind.income => ZadTransaction.income(
    id: id,
    userId: 'u',
    amount: amount,
    title: id,
    createdAt: at,
    wallet: Wallet.bank,
  ),
  TxnKind.transfer => ZadTransaction.transfer(
    id: id,
    userId: 'u',
    amount: amount,
    title: id,
    createdAt: at,
    from: Wallet.cash,
    to: Wallet.bank,
  ),
};

void main() {
  final today = DateTime.utc(2026, 10);
  DateTime local(DateTime t) => t;

  test('spending per day, oldest first, income and transfers left out', () {
    final days = dailySpend(
      <ZadTransaction>[
        _t('a', 100, DateTime.utc(2026, 10, 1, 9)),
        _t('b', 50, DateTime.utc(2026, 10, 1, 20)),
        _t('c', 30, DateTime.utc(2026, 9, 30, 12)),
        _t('d', 999, DateTime.utc(2026, 10), kind: TxnKind.income),
        _t('e', 70, DateTime.utc(2026, 10), kind: TxnKind.transfer),
        _t('f', 5, DateTime.utc(2026, 9)),
      ],
      today: today,
      local: local,
    );
    expect(days, hasLength(14));
    expect(days.last.$1, today);
    expect(days.last.$2, 150);
    expect(days[days.length - 2].$2, 30);
    expect(days.fold<double>(0, (s, d) => s + d.$2), 180);
  });

  test(
    'categories most first; past the top ones and the unnamed are «أخرى»',
    () {
      final shares = categoryShares(<ZadTransaction>[
        _t('a', 300, today, category: 'بقالة'),
        _t('b', 200, today, category: 'مطاعم'),
        _t('c', 100, today, category: 'مواصلات'),
        _t('d', 40, today),
      ], top: 2);
      expect(shares, <(String, double)>[
        ('بقالة', 300),
        ('مطاعم', 200),
        ('أخرى', 140),
      ]);
    },
  );
}
