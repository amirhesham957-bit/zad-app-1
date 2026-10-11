// The pharmacy screen's Kotlin parts: the stats, the card's badges and
// actions, and the rules behind them.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/features/pharmacy/presentation/pharmacy_view.dart';
import 'package:zad/shared/budget/application/budget_controller.dart';
import 'package:zad/shared/family/application/family_controller.dart';
import 'package:zad/shared/family/data/family_repository.dart';
import 'package:zad/shared/pharmacy/application/pharmacy_controller.dart' as pc;
import 'package:zad/shared/pharmacy/domain/medicine.dart';
import 'package:zad/shared/scan/data/receipt_scanner.dart';
import 'package:zad/shared/scan/data/vision_scanner.dart';
import 'package:zad/shared/transactions/application/transactions_controller.dart';
import 'package:zad/shared/transactions/domain/transaction.dart';

import '../../support/quiet_household.dart';

final DateTime _now = DateTime.utc(2026, 9, 25, 9);

class _Budget extends BudgetController {
  @override
  BudgetView build() => const BudgetView();
}

class _Txns extends TransactionsController {
  @override
  TransactionsView build() => const TransactionsView();

  @override
  Future<void> refresh({bool force = false}) async {}
}

class _NoFamily extends FamilyController {
  @override
  FamilyView build() => const FamilyView(status: NoFamily(), userId: 'u');
}

class _Camera implements ReceiptCamera {
  @override
  Future<Uint8List?> capture(ReceiptImageSource source) async =>
      Uint8List.fromList(<int>[1]);
}

class _Box implements VisionScanner {
  @override
  Future<List<ScannedPantryItem>> pantry({
    required String userId,
    required Uint8List image,
  }) async => const <ScannedPantryItem>[];

  @override
  Future<ScannedMedicine?> medicine({
    required String userId,
    required Uint8List image,
  }) async => medicineFrom(<String, dynamic>{
    'medicine': <String, dynamic>{
      'name': 'كونكور 5',
      'active_ingredient': 'Bisoprolol',
      'category': 'مزمن',
      'quantity': 30,
      'unit': 'شريط',
      'expiry_date': '2027-05',
      'daily_dose_count': 2,
      'suggested_times': <String>['20:00', '8:00', '24:00'],
    },
  });
}

/// Records what the add form saved.
class _Adding extends QuietPharmacy {
  final List<Map<String, Object?>> added = <Map<String, Object?>>[];

  @override
  Future<void> add({
    required String name,
    required int quantity,
    required String unit,
    required int dailyDoseCount,
    String? doseTimes,
    DateTime? expiryDate,
    double price = 0,
    String? activeIngredient,
    String? dosage,
    String? category,
    bool isRecurring = false,
    String? familyMemberId,
    String? forPerson,
  }) async => added.add(<String, Object?>{
    'name': name,
    'quantity': quantity,
    'unit': unit,
    'daily': dailyDoseCount,
    'times': doseTimes,
    'expiry': expiryDate,
    'ingredient': activeIngredient,
    'category': category,
    'for': forPerson,
  });
}

/// Records the times the sheet saved.
class _Timing extends QuietPharmacy {
  new(super.view);

  final List<(String, List<String>)> timed = <(String, List<String>)>[];

  @override
  Future<void> setDoseTimes(Medicine medicine, Iterable<String> times) async =>
      timed.add((medicine.id, times.toList()));
}

Medicine _m(
  String id, {
  int remaining = 20,
  bool knownDose = true,
  DateTime? expiry,
  String? dosage,
  double price = 0,
  bool recurring = true,
}) => Medicine.fromJson(<String, dynamic>{
  'is_recurring': recurring,
  'id': id,
  'user_id': 'u',
  'name': 'دواء $id',
  'dosage': dosage,
  'daily_dose_count': 2,
  'units_per_dose': knownDose ? 1 : null,
  'remaining_quantity': remaining,
  'expiry_date': expiry?.toIso8601String(),
  'price': price,
  'unit': 'قرص',
});

void main() {
  setUpAll(() => initializeDateFormatting('ar'));

  test('the doses spread over the waking day', () {
    expect(suggestDoseTimes(1), '09:00');
    expect(suggestDoseTimes(3), '08:00, 15:00, 22:00');
  });

  test('days of supply are never guessed', () {
    expect(_m('a').daysOfSupplyLeft, 10);
    expect(_m('b', knownDose: false).daysOfSupplyLeft, isNull);
  });

  test('the monthly cost is the larger of spending and the boxes', () {
    final cost = pharmacyMonthlyCost(
      <Medicine>[_m('a', price: 80), _m('b', price: 40)],
      <ZadTransaction>[
        ZadTransaction.fromJson(<String, dynamic>{
          'id': 't',
          'user_id': 'u',
          'amount': 200,
          'title': 'صيدلية',
          'created_at': '2026-09-20T10:00:00Z',
          'txn_kind': 'expense',
          'is_expense': true,
          'category': 'الرعاية الصحية',
        }),
      ],
    );
    expect(cost, 200);
  });

  test('the cost says whether it is spending or the boxes', () {
    final clinic = ZadTransaction.fromJson(<String, dynamic>{
      'id': 't',
      'user_id': 'u',
      'amount': 1356.5,
      'title': 'كشف',
      'created_at': '2026-09-20T10:00:00Z',
      'txn_kind': 'expense',
      'is_expense': true,
      'category': 'الرعاية الصحية',
    });
    expect(
      pharmacyCostLabel(<Medicine>[_m('a')], <ZadTransaction>[clinic]),
      'صرف الصحة الشهر ده',
    );
    expect(
      pharmacyCostLabel(<Medicine>[
        _m('a', price: 80),
      ], const <ZadTransaction>[]),
      'أسعار علب الأدوية',
    );
  });

  test('a finished course is done, not short', () {
    final course = _m('c', remaining: 0, recurring: false);
    final chronic = _m('r', remaining: 0);
    expect(course.isFinishedCourse, isTrue);
    expect(chronic.isFinishedCourse, isFalse);
    expect(_m('d', recurring: false).isFinishedCourse, isFalse);
  });

  testWidgets('a finished course goes last and is not counted as low', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 2400));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nowProvider.overrideWithValue(() => _now),
          pc.pharmacyControllerProvider.overrideWith(
            () => QuietPharmacy(
              pc.PharmacyView(
                medicines: <Medicine>[
                  _m('1', remaining: 0, recurring: false),
                  _m('2'),
                ],
              ),
            ),
          ),
          budgetControllerProvider.overrideWith(_Budget.new),
          transactionsControllerProvider.overrideWith(_Txns.new),
          familyControllerProvider.overrideWith(_NoFamily.new),
        ],
        child: MaterialApp(
          theme: ZadTheme.light(),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: PharmacyView()),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('الكورس خلص ✓'), findsOneWidget);
    final low = find.ancestor(
      of: find.text('مخزون منخفض'),
      matching: find.byType(Row),
    );
    expect(
      find.descendant(of: low.first, matching: find.text('0')),
      findsOneWidget,
    );
    final active = tester.getTopLeft(find.text('دواء 2')).dy;
    final done = tester.getTopLeft(find.text('دواء 1')).dy;
    expect(active, lessThan(done));
  });

  testWidgets('the stats, the expired warning and each card', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 2400));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nowProvider.overrideWithValue(() => _now),
          pc.pharmacyControllerProvider.overrideWith(
            () => QuietPharmacy(
              pc.PharmacyView(
                medicines: <Medicine>[
                  _m('1', expiry: DateTime.utc(2026, 9, 2)),
                  _m('2', knownDose: false, dosage: 'قرص كل 12 ساعة'),
                ],
                adherence: 90,
              ),
            ),
          ),
          budgetControllerProvider.overrideWith(_Budget.new),
          transactionsControllerProvider.overrideWith(_Txns.new),
          familyControllerProvider.overrideWith(_NoFamily.new),
        ],
        child: MaterialApp(
          theme: ZadTheme.light(),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: PharmacyView()),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('90%'), findsOneWidget);
    expect(find.text('1 دواء منتهي الصلاحية — تخلص منه بأمان'), findsOneWidget);
    expect(find.text('منتهي منذ 23 يوم'), findsOneWidget);
    expect(find.text('الكمية محتاجة تأكيد'), findsOneWidget);
    expect(find.text('تجديد الطلب'), findsNWidgets(2));

    await tester.tap(find.text('الكمية محتاجة تأكيد'));
    await tester.pumpAndSettle();
    expect(find.text('الجرعة الواحدة كام قرص؟'), findsOneWidget);
  });

  testWidgets('a box photographed opens the add form filled in', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 2400));
    final pharmacy = _Adding();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nowProvider.overrideWithValue(() => _now),
          signedInUserIdProvider.overrideWithValue(() => 'u'),
          receiptCameraProvider.overrideWithValue(_Camera()),
          visionScannerProvider.overrideWithValue(_Box()),
          pc.pharmacyControllerProvider.overrideWith(() => pharmacy),
          budgetControllerProvider.overrideWith(_Budget.new),
          transactionsControllerProvider.overrideWith(_Txns.new),
          familyControllerProvider.overrideWith(_NoFamily.new),
        ],
        child: MaterialApp(
          theme: ZadTheme.light(),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: PharmacyView()),
          ),
        ),
      ),
    );
    await tester.pump();

    // Kotlin's flow: the one add button, then the form's camera row.
    await tester.tap(find.byTooltip('إضافة'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('مسح العبوة بالكاميرا'));
    await tester.tap(find.text('مسح العبوة بالكاميرا'));
    await tester.pumpAndSettle();

    expect(find.text('إضافة دواء'), findsOneWidget);
    expect(find.text('كونكور 5'), findsOneWidget);
    // The box's own unit, kept even though Kotlin's list lacks it.
    expect(find.widgetWithText(ChoiceChip, 'شريط'), findsOneWidget);
    expect(pharmacy.added, isEmpty);

    // «لمين؟» — a medicine for someone with no account.
    final forWhom = find.widgetWithText(
      TextField,
      'لمين؟ (سيبها فاضية لو ليك)',
    );
    await tester.ensureVisible(forWhom);
    await tester.enterText(forWhom, ' ماما ');

    await tester.ensureVisible(find.text('حفظ'));
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    expect(pharmacy.added, <Map<String, Object?>>[
      <String, Object?>{
        'name': 'كونكور 5',
        'quantity': 30,
        'unit': 'شريط',
        'daily': 2,
        'times': '08:00,20:00',
        'expiry': DateTime.utc(2027, 5, 31),
        'ingredient': 'Bisoprolol',
        'category': 'مزمن',
        'for': 'ماما',
      },
    ]);
  });

  test('saved times are the server shape: valid, padded, once, in order', () {
    expect(
      pc.doseTimesWire(<String>['20:00', '8:00', '24:00', '08:00', 'x']),
      <String>['08:00', '20:00'],
    );
    expect(pc.doseTimesWire(<String>['25:00']), isEmpty);
  });

  Future<_Timing> pumpPharmacy(
    WidgetTester tester,
    List<Medicine> medicines,
  ) async {
    final pharmacy = _Timing(pc.PharmacyView(medicines: medicines));
    await tester.binding.setSurfaceSize(const Size(420, 2400));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nowProvider.overrideWithValue(() => _now),
          pc.pharmacyControllerProvider.overrideWith(() => pharmacy),
          budgetControllerProvider.overrideWith(_Budget.new),
          transactionsControllerProvider.overrideWith(_Txns.new),
          familyControllerProvider.overrideWith(_NoFamily.new),
        ],
        child: MaterialApp(
          theme: ZadTheme.light(),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: PharmacyView()),
          ),
        ),
      ),
    );
    await tester.pump();
    return pharmacy;
  }

  testWidgets('a medicine with no times says so, and the sheet sets them', (
    tester,
  ) async {
    // The owner's Diosmin (2026-10-10): read off a receipt, no times, and a
    // blank «جرعات النهارده» over it.
    final pharmacy = await pumpPharmacy(tester, <Medicine>[_m('1')]);

    expect(find.text('جرعات النهارده'), findsOneWidget);
    expect(find.textContaining('ولا دوا ليه مواعيد لسه'), findsOneWidget);
    expect(find.text('مالوش مواعيد — مش هفكّرك بيه'), findsOneWidget);

    await tester.tap(find.text('حدد مواعيده'));
    await tester.pumpAndSettle();
    expect(find.text('مواعيد دواء 1'), findsOneWidget);
    final save = find.widgetWithText(FilledButton, 'احفظ المواعيد');
    expect(tester.widget<FilledButton>(save).onPressed, isNull);

    await tester.tap(find.text('🌅 صباحاً'));
    await tester.tap(find.text('🌙 مساءً'));
    await tester.pump();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(pharmacy.timed.single.$1, '1');
    expect(pharmacy.timed.single.$2, containsAll(<String>['08:00', '20:00']));
    expect(find.text('مواعيد دواء 1'), findsNothing, reason: 'sheet closed');
  });

  testWidgets('a medicine with times has no prompt', (tester) async {
    final timed = Medicine.fromJson(<String, dynamic>{
      'id': '2',
      'user_id': 'u',
      'name': 'سوبراكس',
      'daily_dose_count': 1,
      'dose_times': '21:00',
      'remaining_quantity': 4,
      'unit': 'كبسولة',
    });
    await pumpPharmacy(tester, <Medicine>[timed]);

    expect(find.text('مالوش مواعيد — مش هفكّرك بيه'), findsNothing);
    expect(find.text('مفيش جرعات فاضلة النهارده.'), findsOneWidget);
  });
}
