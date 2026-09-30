import 'package:flutter_test/flutter_test.dart';
import 'package:zad/features/intelligence/domain/monthly_analysis.dart';
import 'package:zad/shared/transactions/domain/transaction.dart';

import 'sample_month.dart';

ZadTransaction _tx(String title, {String? category, double amount = 100}) =>
    ZadTransaction.expense(
      id: title,
      userId: 'u',
      amount: amount,
      title: title,
      createdAt: DateTime.utc(2026, 9, 5),
      wallet: Wallet.card,
      category: category,
    );

void main() {
  final a = analyzeMonth(
    transactions: sampleMonth(),
    start: sampleStart,
    end: sampleEnd,
    budget: 20000,
  );

  group('overview', () {
    test('totals only the cycle, expenses and income apart', () {
      expect(a.spent, 19530);
      expect(a.income, 18000);
      expect(a.count, 33);
      expect(a.usage, closeTo(0.9765, 0.0001));
    });

    test('no budget, no usage', () {
      final b = analyzeMonth(
        transactions: sampleMonth(),
        start: sampleStart,
        end: sampleEnd,
      );
      expect(b.usage, isNull);
    });

    test('an empty month is all zeros, not an error', () {
      final e = analyzeMonth(
        transactions: const <ZadTransaction>[],
        start: sampleStart,
        end: sampleEnd,
      );
      expect(e.spent, 0);
      expect(e.family.map((g) => g.total), everyElement(0));
      expect(e.family.map((g) => g.share), everyElement(0));
      expect(e.duplicates, isEmpty);
      expect(e.transport, isNull);
      expect(e.small, isNull);
      expect(e.lines, isEmpty);
      expect(e.hasHabitAlerts, isFalse);
    });
  });

  group('1. family breakdown', () {
    GroupSpend of(FamilyGroup g) => a.family.firstWhere((s) => s.group == g);

    test('always all four groups, in order', () {
      expect(a.family.map((g) => g.group), FamilyGroup.values);
      expect(FamilyGroup.values.map((g) => g.label), <String>[
        'مصاريف البيت',
        'مستلزمات الأطفال',
        'الأدوية والصيدلية',
        'الأنشطة والخروجات العائلية',
      ]);
    });

    test('sums each group and its share', () {
      expect(of(FamilyGroup.house).total, 11500);
      expect(of(FamilyGroup.house).count, 8);
      expect(of(FamilyGroup.kids).total, 3520);
      expect(of(FamilyGroup.pharmacy).total, 730);
      expect(of(FamilyGroup.activities).total, 1900);
      expect(of(FamilyGroup.kids).share, closeTo(3520 / 19530, 1e-9));
      // Transport and coffee belong to none of the four.
      expect(a.otherSpend, 1530 + 350);
    });

    test('top items are merged by title, largest first, three at most', () {
      expect(of(FamilyGroup.house).topItems, <(String, double)>[
        ('الإيجار', 5000),
        ('كارفور', 4300),
        ('فاتورة الكهرباء', 780),
      ]);
    });

    test('a child cost wins over a household one', () {
      expect(
        FamilyGroup.of(_tx('فاتورة المدرسة', category: 'الفواتير')),
        FamilyGroup.kids,
      );
      expect(
        FamilyGroup.of(_tx('روشتة', category: 'صيدلية')),
        FamilyGroup.pharmacy,
      );
      expect(FamilyGroup.of(_tx('Carrefour')), FamilyGroup.house);
      expect(FamilyGroup.of(_tx('تحويل لأخويا')), isNull);
    });
  });

  group('2. habits', () {
    test('the same thing twice inside a week is a repeat', () {
      expect(a.duplicates, hasLength(1));
      final d = a.duplicates.single;
      expect(d.title, 'زيت وسكر');
      expect(d.count, 2);
      expect(d.total, 620);
      expect(d.category, 'البقالة');
    });

    test('twelve days apart is not a repeat', () {
      expect(a.duplicates.map((d) => d.title), isNot(contains('حفاضات')));
    });

    test('transport and small purchases are not also reported as repeats', () {
      expect(a.duplicates.map((d) => d.title), isNot(contains('أوبر')));
      expect(a.duplicates.map((d) => d.title), isNot(contains('قهوة')));
    });

    test('two dear taxis in a week are transport, not a repeat', () {
      // Fewer than five purchases, so the small-purchase rule is off and
      // only the transport exclusion keeps these out of the repeats.
      ZadTransaction taxi(int day) => ZadTransaction.expense(
        id: 'taxi$day',
        userId: 'u',
        amount: 400,
        title: 'أوبر',
        createdAt: DateTime.utc(2026, 9, day),
        wallet: Wallet.card,
        category: 'المواصلات',
      );
      final m = analyzeMonth(
        transactions: <ZadTransaction>[taxi(3), taxi(5)],
        start: sampleStart,
        end: sampleEnd,
      );
      expect(m.duplicates, isEmpty);
      expect(m.transport!.trips, 2);
    });

    test('transport: total, median, outlier trips', () {
      final t = a.transport!;
      expect(t.trips, 6);
      expect(t.total, 1530);
      expect(t.median, 102.5);
      expect(t.costlyTrips, <(String, double)>[
        ('أوبر للمطار', 650),
        ('بنزين', 500),
      ]);
      expect(t.isCostly, isTrue);
    });

    test('small purchases: under half the median purchase', () {
      final s = a.small!;
      expect(s.threshold, 155);
      expect(s.count, 14);
      expect(s.total, 730);
    });
  });

  group('3. comparison and caps', () {
    CategoryLine line(String c) => a.lines.firstWhere((l) => l.category == c);

    test('largest first, against the previous calendar month', () {
      expect(a.lines.first.category, 'البقالة');
      expect(line('البقالة').current, 5370);
      expect(line('البقالة').previous, 2600);
      expect(line('البقالة').change, closeTo(5370 / 2600 - 1, 1e-9));
      // Paid on August 1st — inside the previous window.
      expect(line('إيجار').previous, 5000);
      expect(line('أطفال').change, isNull);
    });

    test('essentials keep their level', () {
      for (final c in <String>['إيجار', 'التعليم', 'الفواتير']) {
        expect(line(c).essential, isTrue, reason: c);
        expect(line(c).cap, line(c).current, reason: c);
        expect(line(c).saving, 0, reason: c);
      }
    });

    test('a grown, flagged category is capped and saves the difference', () {
      expect(line('البقالة').cap, 4295);
      expect(line('البقالة').saving, 1075);
      expect(line('المواصلات').cap, 1220);
      expect(a.savings, a.lines.fold<double>(0, (s, l) => s + l.saving));
    });

    test('suggestedCap rules', () {
      expect(suggestedCap(current: 1000, previous: 0, flagged: false), 900);
      expect(suggestedCap(current: 1000, previous: 0, flagged: true), 850);
      expect(suggestedCap(current: 1000, previous: 500, flagged: false), 800);
      expect(suggestedCap(current: 1000, previous: 900, flagged: false), 900);
      expect(suggestedCap(current: 3, previous: 0, flagged: false), 3);
      expect(suggestedCap(current: 0, previous: 0, flagged: false), 0);
    });

    test('previousWindow steps back a calendar month for monthly cycles', () {
      expect(previousWindow(DateTime.utc(2026, 9), DateTime.utc(2026, 10)), (
        DateTime.utc(2026, 8),
        DateTime.utc(2026, 9),
      ));
      expect(
        previousWindow(DateTime.utc(2026, 3, 31), DateTime.utc(2026, 4, 30)),
        (DateTime.utc(2026, 2, 28), DateTime.utc(2026, 3, 31)),
      );
      expect(previousWindow(DateTime.utc(2026), DateTime.utc(2026, 2)), (
        DateTime.utc(2025, 12),
        DateTime.utc(2026),
      ));
      expect(
        previousWindow(DateTime.utc(2026, 9, 15), DateTime.utc(2026, 9, 29)),
        (DateTime.utc(2026, 9), DateTime.utc(2026, 9, 15)),
      );
    });

    test('practical steps name what was found', () {
      final steps = savingSteps(a, (v) => '$v');
      expect(steps, hasLength(4));
      expect(steps[0], contains('«زيت وسكر» اتشرى مرتين'));
      expect(steps[1], startsWith('المواصلات أخدت 8%'));
      expect(steps[2], startsWith('14 مشترى صغير'));
      expect(steps[3], contains(a.savings.toString()));
      expect(timesLabel(3), '3 مرات');
    });
  });
}
