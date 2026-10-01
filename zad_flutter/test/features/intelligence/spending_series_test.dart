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

  group('behaviour (owner, 2026-10-01: «تحليل الصرف والسلوك»)', () {
    final today = DateTime.utc(2026, 10); // a Thursday
    DateTime local(DateTime utc) => utc;

    test('the weekday spent on most, averaged over the weeks', () {
      final rows = <ZadTransaction>[
        // Two Thursdays and one Saturday inside the 8 weeks.
        _t('a', 400, DateTime.utc(2026, 10, 1, 10)),
        _t('b', 400, DateTime.utc(2026, 9, 24, 10)),
        _t('c', 160, DateTime.utc(2026, 9, 26, 10)),
        _t('in', 9000, DateTime.utc(2026, 9, 25), kind: TxnKind.income),
      ];
      final week = weekdayAverages(rows, today: today, local: local);
      expect(week.first.$1, 'السبت');
      expect(week[5], ('الخميس', 100.0)); // 800 over 8 weeks
      expect(week[0], ('السبت', 20.0));
      expect(week[6].$2, 0, reason: 'income is not spending');
    });

    test('where the money goes: merchant first, else the title', () {
      final rows = <ZadTransaction>[
        ZadTransaction.expense(
          id: 'c1',
          userId: 'u',
          amount: 50,
          title: 'قهوة',
          createdAt: today,
          wallet: Wallet.bank,
          merchantName: 'Starbucks',
        ),
        ZadTransaction.expense(
          id: 'c2',
          userId: 'u',
          amount: 70,
          title: 'قهوة',
          createdAt: today,
          wallet: Wallet.bank,
          merchantName: 'Starbucks',
        ),
        _t('بقالة', 300, today),
      ];
      expect(topPlaces(rows), <(String, double, int)>[
        ('بقالة', 300, 1),
        ('Starbucks', 120, 2),
      ]);
    });

    test('what changed since last month, the largest move first', () {
      final rows = <ZadTransaction>[
        _t('1', 100, DateTime.utc(2026, 9, 25), category: 'قهوة'),
        _t('2', 50, DateTime.utc(2026, 8, 20), category: 'قهوة'),
        _t('3', 400, DateTime.utc(2026, 9, 20), category: 'إلكترونيات'),
        _t('4', 200, DateTime.utc(2026, 8, 25), category: 'بقالة'),
        _t('5', 210, DateTime.utc(2026, 9, 10), category: 'بقالة'),
      ];
      final changes = categoryChanges(rows, today: today, local: local);
      expect(changes.first, ('إلكترونيات', 400.0, 0.0));
      expect(changes[1], ('قهوة', 100.0, 50.0));
      expect(changes.length, 3);
    });
  });
}
