import 'package:flutter_test/flutter_test.dart';
import 'package:zad/shared/transactions/domain/transaction.dart';
import 'package:zad/shared/trip/domain/trip_summary.dart';

ZadTransaction _e(String id, double a, DateTime at, {bool budget = true}) =>
    ZadTransaction.expense(
      id: id,
      userId: 'u',
      amount: a,
      title: 't',
      createdAt: at,
      wallet: Wallet.card,
      countsTowardBudget: budget,
    );

void main() {
  final since = DateTime(2026, 11, 10);
  test(
    'counts only expenses since the trip began, converted to trip money',
    () {
      final s = summarizeTrip(
        rows: <ZadTransaction>[
          _e('a', 100, DateTime(2026, 11, 11)),
          _e('b', 50, DateTime(2026, 11, 9)), // before the trip
          _e('c', 30, DateTime(2026, 11, 12), budget: false),
          ZadTransaction.income(
            id: 'd',
            userId: 'u',
            amount: 900,
            title: 'x',
            createdAt: DateTime(2026, 11, 11),
            wallet: Wallet.card,
          ),
        ],
        since: since,
        homeCurrency: 'SAR',
        tripCurrency: 'AED',
        budgetTrip: 500,
      );
      expect(s.count, 1);
      expect(s.spentHome, 100);
      expect(s.spentTrip, closeTo(97.94, 0.01)); // 100 SAR ≈ 97.94 AED
      expect(s.remainingTrip, closeTo(402.06, 0.01));
      expect(s.isOver, isFalse);
    },
  );

  test('unknown currency gives no trip figure, never 1:1', () {
    final s = summarizeTrip(
      rows: <ZadTransaction>[_e('a', 100, DateTime(2026, 11, 11))],
      since: since,
      homeCurrency: 'SAR',
      tripCurrency: 'XXX',
      budgetTrip: 500,
    );
    expect(s.spentTrip, isNull);
    expect(s.remainingTrip, isNull);
  });

  test('over budget is flagged', () {
    final s = summarizeTrip(
      rows: <ZadTransaction>[_e('a', 1000, DateTime(2026, 11, 11))],
      since: since,
      homeCurrency: 'SAR',
      tripCurrency: 'SAR',
      budgetTrip: 400,
    );
    expect(s.isOver, isTrue);
  });
}
