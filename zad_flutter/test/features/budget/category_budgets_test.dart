import 'package:flutter_test/flutter_test.dart';
import 'package:zad/features/budget/domain/category_budgets.dart';
import 'package:zad/features/transactions/domain/transaction.dart';

ZadTransaction _t(
  String id,
  double amount,
  String? category, {
  bool income = false,
}) => ZadTransaction.fromJson(<String, dynamic>{
  'id': id,
  'user_id': 'u',
  'amount': amount,
  'title': id,
  'created_at': '2026-09-20T10:00:00Z',
  'txn_kind': income ? 'income' : 'expense',
  'is_expense': !income,
  'category': category,
});

void main() {
  test('expenses only, the uncategorised under أخرى', () {
    final spent = spentByCategory(<ZadTransaction>[
      _t('a', 100, 'البقالة'),
      _t('b', 50, 'البقالة'),
      _t('c', 30, null),
      _t('d', 999, 'البقالة', income: true),
    ]);
    expect(spent, <String, double>{'البقالة': 150, 'أخرى': 30});
  });

  test('a category shows with a budget or spending, most spent first', () {
    final lines = categoryLines(
      standard: const <String>['البقالة', 'المطاعم', 'الوقود'],
      budgets: const <String, double>{'الوقود': 500},
      spent: const <String, double>{'البقالة': 100, 'المطاعم': 300},
    );
    expect(lines.map((l) => l.category), <String>[
      'المطاعم',
      'البقالة',
      'الوقود',
    ]);
  });

  test('the insight tiers at 60, 85 and 100 percent', () {
    expect(budgetInsight(spent: 50, budget: 100).tier, 0);
    expect(budgetInsight(spent: 60, budget: 100).tier, 1);
    expect(budgetInsight(spent: 85, budget: 100).tier, 2);
    expect(budgetInsight(spent: 100, budget: 100).tier, 3);
  });
}
