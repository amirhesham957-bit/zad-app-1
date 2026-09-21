// The sheet says what saving will do: for groceries, which lines go into the
// pantry, with a switch to keep them out; for anything else, the lines are for
// checking only.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/design/zad_theme.dart';
import 'package:zad/features/pharmacy/domain/medicine.dart';
import 'package:zad/features/pharmacy/domain/pharmacy_intake.dart';
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

  Future<void> pump(
    WidgetTester tester,
    ReceiptType type, {
    List<RestockProposal> pharmacy = const <RestockProposal>[],
  }) async {
    fake = _Scan(
      ScanView(
        stage: ScanStage.ready,
        receipt: _receipt(type),
        pharmacy: pharmacy,
      ),
    );
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

  testWidgets('a pharmacy receipt says where each line goes, and how many', (
    tester,
  ) async {
    const concor = Medicine(id: 'm1', userId: 'u', name: 'كونكور 5');
    await pump(
      tester,
      ReceiptType.pharmacy,
      pharmacy: const <RestockProposal>[
        RestockProposal(
          line: PharmacyLine(name: 'كونكور 5 مجم 30 قرص', packs: 2),
          medicine: concor,
          count: 60,
          unit: 'قرص',
        ),
        RestockProposal(
          line: PharmacyLine(name: 'فيتامين د3', packs: 1),
          unit: 'قرص',
        ),
      ],
    );

    expect(find.text('ضيف الأدوية للصيدلية (2)'), findsOneWidget);
    expect(find.text('يزيد: كونكور 5'), findsOneWidget);
    expect(find.text('جديد في الصيدلية'), findsOneWidget);
    expect(find.text('+60 قرص'), findsOneWidget);
    // Not guessed: asked.
    expect(find.text('كام قرص؟'), findsOneWidget);
    expect(find.text('احفظ وضيف للصيدلية'), findsOneWidget);
    expect(find.textContaining('للمراجعة بس'), findsNothing);
  });
}
