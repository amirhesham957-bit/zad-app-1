// The sheet says what saving will do: for groceries, which lines go into the
// pantry, with a switch to keep them out; for anything else, the lines are for
// checking only.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/design/zad_theme.dart';
import 'package:zad/features/scan/application/scan_controller.dart';
import 'package:zad/features/scan/domain/scanned_receipt.dart';
import 'package:zad/features/scan/presentation/receipt_scan_sheet.dart';

class _Scan extends ScanController {
  new(this.initial);

  final ScanView initial;
  final List<String> calls = <String>[];

  @override
  ScanView build() => initial;

  @override
  void toggleItem(int index) {
    calls.add('toggle:$index');
    super.toggleItem(index);
  }
}

ScannedReceipt _receipt(ReceiptType type) => ScannedReceipt(
  total: 80,
  category: 'البقالة',
  storeName: 'كازيون',
  type: type,
  items: const <ScannedReceiptItem>[
    ScannedReceiptItem(
      name: 'لبن',
      price: 30,
      quantity: 2,
      unit: 'لتر',
      category: 'ألبان',
    ),
    ScannedReceiptItem(
      name: 'عيش',
      price: 10,
      quantity: 1,
      unit: 'قطعة',
      category: 'مخبوزات',
    ),
  ],
);

void main() {
  late _Scan fake;

  Future<void> pump(WidgetTester tester, ReceiptType type) async {
    fake = _Scan(ScanView(stage: ScanStage.ready, receipt: _receipt(type)));
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [scanControllerProvider.overrideWith(() => fake)],
        child: MaterialApp(
          theme: ZadTheme.light(),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: SingleChildScrollView(child: ReceiptScanSheet()),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('a grocery receipt offers its lines to the pantry', (
    tester,
  ) async {
    await pump(tester, ReceiptType.grocery);

    expect(find.text('ضيف الأصناف للمخزن (2)'), findsOneWidget);
    expect(find.byType(Checkbox), findsNWidgets(2));
    expect(find.text('احفظ وضيف للمخزن'), findsOneWidget);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    expect(fake.calls, <String>['toggle:0']);
    expect(find.text('ضيف الأصناف للمخزن (1)'), findsOneWidget);
  });

  testWidgets('switching the pantry off says the save is money only', (
    tester,
  ) async {
    await pump(tester, ReceiptType.grocery);

    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(find.text('احفظ كمصروف'), findsOneWidget);
  });

  testWidgets('any other receipt shows its lines for checking only', (
    tester,
  ) async {
    await pump(tester, ReceiptType.general);

    expect(find.byType(Checkbox), findsNothing);
    expect(find.textContaining('للمراجعة بس'), findsOneWidget);
    expect(find.text('احفظ كمصروف'), findsOneWidget);
  });
}
