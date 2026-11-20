// What the statement world says comes from real rows, on the account's
// calendar.

import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/features/statement/domain/statement_months.dart';
import 'package:zad/shared/transactions/domain/transaction.dart';

ZadTransaction _tx(
  String at,
  double amount, {
  bool income = false,
  String? category,
}) => ZadTransaction.fromJson(<String, dynamic>{
  'id': at + amount.toString(),
  'user_id': 'u',
  'amount': amount,
  'title': 't',
  'category': category,
  'created_at': at,
  'wallet': 'card',
  'txn_kind': income ? 'income' : 'expense',
  'is_expense': !income,
});

void main() {
  late tz.Location cairo;
  setUpAll(() {
    tz_data.initializeTimeZones();
    cairo = tz.getLocation('Africa/Cairo');
  });
  final now = DateTime.utc(2026, 11, 15, 12);

  test('months are totalled on the account calendar, empty ones left out', () {
    final out = monthlyTotals(
      <ZadTransaction>[
        _tx('2026-09-05T10:00:00Z', 100),
        _tx('2026-11-02T10:00:00Z', 40),
        _tx('2026-11-03T10:00:00Z', 1000, income: true),
        // 23:30 UTC on the 31st is already November 1st in Cairo.
        _tx('2026-10-31T23:30:00Z', 10),
      ],
      cairo,
      now,
    );
    expect(out.map((m) => m.month), <int>[9, 11]);
    expect(out.last.spent, 50);
    expect(out.last.income, 1000);
  });

  test('the pace compares the same days of the two months', () {
    final change = spendingPaceChange(
      <ZadTransaction>[
        _tx('2026-10-03T10:00:00Z', 100),
        // After the 15th: not part of the comparison.
        _tx('2026-10-20T10:00:00Z', 900),
        _tx('2026-11-03T10:00:00Z', 92),
      ],
      cairo,
      now,
    );
    expect(change, closeTo(-0.08, 1e-9));
  });

  test('no spending to compare with is null, not zero', () {
    expect(
      spendingPaceChange(
        <ZadTransaction>[_tx('2026-11-03T10:00:00Z', 92)],
        cairo,
        now,
      ),
      isNull,
    );
  });

  test('the breakdown is this month only, biggest category first', () {
    final b = monthBreakdown(
      <ZadTransaction>[
        _tx('2026-11-03T10:00:00Z', 30, category: 'أ'),
        _tx('2026-11-04T10:00:00Z', 90, category: 'ب'),
        _tx('2026-11-05T10:00:00Z', 5000, income: true),
        _tx('2026-10-05T10:00:00Z', 777, category: 'ج'),
      ],
      cairo,
      now,
    );
    expect(b.income, 5000);
    expect(b.spent.map((e) => e.$1), <String>['ب', 'أ']);
  });
}
