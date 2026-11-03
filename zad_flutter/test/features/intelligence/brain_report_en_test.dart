// ZAD_PLAN 8.8: the monthly report reads in the screen's language; the
// stored category key stays as it is.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/l10n/generated/zad_l10n.dart';
import 'package:zad/features/intelligence/domain/brain_report.dart';
import 'package:zad/shared/subscriptions/domain/subscription.dart';
import 'package:zad/shared/transactions/domain/transaction.dart';

void main() {
  final en = lookupZadL10n(const Locale('en'));
  final today = DateTime.utc(2026, 9, 20);
  String money(double v) => '${v.toStringAsFixed(0)} EGP';

  test('the report and its export text in English', () {
    final r = buildBrainReport(
      transactions: <ZadTransaction>[
        ZadTransaction.expense(
          id: 'a',
          userId: 'u',
          amount: 400,
          title: 'بقالة',
          createdAt: DateTime.utc(2026, 9, 3),
          wallet: Wallet.card,
          category: 'البقالة',
        ),
      ],
      subscriptions: <Subscription>[],
      pantryNames: const <String>[],
      categoryBudgets: const <String, double>{'البقالة': 300},
      standardCategories: const <String>['البقالة'],
      budget: 1000,
      today: today,
      local: (t) => t,
      predictDaysLeft: (_) => null,
      money: money,
      l10n: en,
    );
    expect(
      r.insights,
      contains('⛔ You went over the البقالة budget by 100 EGP'),
    );
    final text = buildExportText(r, today: today, money: money, l10n: en);
    expect(text, contains('📊 Zad money report — 9/2026'));
    expect(text, contains('• البقالة: 400 EGP of 300 (133%)'));
    expect(text, contains('— A report from the Zad app 🥕'));
    expect(text, isNot(contains('الميزانية:')));
  });
}
