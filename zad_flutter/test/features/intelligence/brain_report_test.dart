import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:zad/features/intelligence/domain/brain_report.dart';
import 'package:zad/features/subscriptions/domain/subscription.dart';
import 'package:zad/features/transactions/domain/transaction.dart';

ZadTransaction _spend(String id, double amount, DateTime at, {String? cat}) =>
    ZadTransaction.expense(
      id: id,
      userId: 'u',
      amount: amount,
      title: 'بقالة',
      createdAt: at,
      wallet: Wallet.card,
      category: cat,
    );

String _money(double v) => '${v.toStringAsFixed(0)} ج.م';

void main() {
  final today = DateTime.utc(2026, 9, 20);

  BrainReport build(List<ZadTransaction> rows, {double budget = 1000}) =>
      buildBrainReport(
        transactions: rows,
        subscriptions: <Subscription>[],
        pantryNames: const <String>[],
        categoryBudgets: const <String, double>{'البقالة': 300},
        standardCategories: const <String>['البقالة', 'أخرى'],
        budget: budget,
        today: today,
        local: (t) => t,
        predictDaysLeft: (_) => null,
        money: _money,
      );

  test('money-only health score, Kotlin thresholds', () {
    expect(
      financialHealthScore(
        budget: 1000,
        totalSpent: 950,
        overBudgetCategories: 1,
        discretionaryMonthlyCost: 0,
      ),
      100 - 30 - 8,
    );
  });

  test('month totals, over-budget category and the export text', () {
    final r = build(<ZadTransaction>[
      _spend('a', 400, DateTime.utc(2026, 9, 3), cat: 'البقالة'),
      _spend('b', 100, DateTime.utc(2026, 8, 10), cat: 'البقالة'),
    ]);
    expect(r.totalSpent, 400);
    expect(r.remaining, 600);
    expect(r.categoryBreakdown.first.isOverBudget, isTrue);
    expect(r.hasEnoughData, isTrue);
    final text = buildExportText(r, today: today, money: _money);
    expect(text, contains('📊 تقرير زاد المالي — 9/2026'));
    expect(text, contains('• البقالة: 400 ج.م من 300 (133%)'));
    expect(text, contains('⛔ تجاوزت ميزانية البقالة بـ100 ج.م'));
    expect(text.trimRight(), endsWith('— تقرير من تطبيق زاد 🥕'));
  });

  test('no ceiling: remaining unknown, not zero', () {
    final r = build(<ZadTransaction>[], budget: 0);
    expect(r.remaining, isNull);
    expect(r.spendingPower.status, 'غير محدد');
    expect(r.hasEnoughData, isFalse);
  });

  test('Arabic renders into a PDF with the bundled Cairo', () async {
    final font = pw.Font.ttf(
      (await File('assets/fonts/cairo_variable.ttf').readAsBytes()).buffer
          .asByteData(),
    );
    final doc = pw.Document()
      ..addPage(
        pw.Page(
          textDirection: pw.TextDirection.rtl,
          theme: pw.ThemeData.withFont(base: font),
          build: (_) => pw.Text('تقرير زاد الشهري — الصحة المالية: 62/100'),
        ),
      );
    final bytes = await doc.save();
    expect(bytes.length, greaterThan(1000));
  });
}
