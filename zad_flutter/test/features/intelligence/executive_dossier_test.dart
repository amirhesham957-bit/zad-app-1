import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/features/intelligence/presentation/executive_dossier_sheet.dart';

ExecutiveDossier _dossier({double? daily = 120.5, int? adherence = 91}) =>
    ExecutiveDossier(
      issuedOn: DateTime(2026, 9, 7),
      totalSpent: 3250,
      safeDailySpend: daily,
      familyMembers: 4,
      lowStockItems: 2,
      adherencePct: adherence,
      currency: 'ج.م',
    );

void main() {
  test('the money section carries the cycle spend and the safe daily', () {
    final d = _dossier();
    expect(d.issuedLine, 'تاريخ الإصدار: 2026-09-07');
    expect(
      d.moneyText,
      '• إجمالي الصرف الفعلي للدورة الحالية: 3,250 ج.م.\n'
      '• معدل الصرف اليومي الآمن الموصى به: 120.5 ج.م/يوم.',
    );
  });

  test('without a spendable figure it says what is missing, not a number', () {
    expect(
      _dossier(daily: null).moneyText,
      endsWith('محتاج ميزانية ورصيد محدّدين عشان يتحسب.'),
    );
  });

  test('an overspent cycle shows a zero daily, never a negative one', () {
    expect(_dossier(daily: -40).moneyText, contains('الموصى به: 0 ج.م/يوم.'));
  });

  test('the house section, with and without doses', () {
    expect(
      _dossier().householdText,
      '• عقل العائلة المشترك: 4 أفراد متصلين ومزامنين لحظياً.\n'
      '• أصناف قاربت على النفاد في المخزون: 2 صنف.\n'
      '• الالتزام الدوائي هذا الأسبوع: 91%.',
    );
    expect(
      _dossier(adherence: null).householdText,
      endsWith('لسه مفيش جرعات كفاية مسجّلة لحساب نسبة.'),
    );
  });

  test('the shared text leaves out adherence it does not have', () {
    expect(
      _dossier().shareText,
      '📄 تقرير عقل زاد:\n• إجمالي الصرف: 3,250 ج.م\n• الالتزام الدوائي: 91%\n',
    );
    expect(_dossier(adherence: null).shareText, isNot(contains('الالتزام')));
  });

  testWidgets('the sheet shows both sections and closes', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showExecutiveDossierSheet(context, _dossier()),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('التقرير الاستراتيجي الشامل لعقل زاد'), findsOneWidget);
    expect(
      find.text('1. التنبؤات والتدفق المالي للشهر القادم'),
      findsOneWidget,
    );
    expect(find.text('2. كفاءة إدارة المنزل والعائلة'), findsOneWidget);
    expect(find.text('📤 مشاركة التقرير'), findsOneWidget);

    await tester.ensureVisible(find.text('إغلاق التقرير'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إغلاق التقرير'));
    await tester.pumpAndSettle();
    expect(find.byType(ExecutiveDossierSheet), findsNothing);
  });
}
