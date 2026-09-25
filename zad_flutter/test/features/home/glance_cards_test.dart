// Home's glance cards: what each shows from its controller's view, and what
// its buttons do.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/design/zad_theme.dart';
import 'package:zad/features/budget/application/budget_controller.dart';
import 'package:zad/features/home/presentation/glance_cards.dart';
import 'package:zad/features/inventory/application/pantry_controller.dart';
import 'package:zad/features/inventory/application/shopping_controller.dart';
import 'package:zad/features/inventory/domain/inventory_item.dart';
import 'package:zad/features/inventory/domain/shortage.dart';
import 'package:zad/features/pharmacy/application/pharmacy_controller.dart';
import 'package:zad/features/pharmacy/domain/dose_slot.dart';
import 'package:zad/features/pharmacy/domain/dose_time.dart';
import 'package:zad/features/pharmacy/domain/medicine.dart';
import 'package:zad/features/subscriptions/application/subscriptions_controller.dart';
import 'package:zad/features/subscriptions/domain/subscription.dart';

import '../../support/fonts.dart';
import '../../support/quiet_household.dart';

final DateTime _now = DateTime.utc(2026, 9, 25, 9);

class _Budget extends BudgetController {
  @override
  BudgetView build() => const BudgetView();
}

class _Subs extends SubscriptionsController {
  new(this.items);

  final List<Subscription> items;

  @override
  SubscriptionsView build() =>
      SubscriptionsView(items: items, today: DateTime.utc(2026, 9, 25));

  @override
  Future<void> refresh({bool force = false}) async {}
}

InventoryItem _item(String id, String name, int qty, {int? threshold}) =>
    InventoryItem(
      id: id,
      userId: 'u',
      itemName: name,
      quantity: qty,
      unit: 'علبة',
      lowStockThreshold: threshold,
    );

Medicine _med(String name, {String times = '08:00'}) => Medicine(
  id: name,
  userId: 'u',
  name: name,
  doseTimesRaw: times,
  dailyDoseCount: 1,
  remainingQuantity: 20,
);

DoseSlot _slot(Medicine m, int hour, {DateTime? takenAt}) => DoseSlot(
  medicine: m,
  time: DoseTime(hour, 0),
  scheduledAt: DateTime.utc(2026, 9, 25, hour),
  takenAt: takenAt,
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
    await loadZadFonts();
  });

  Future<void> pump(
    WidgetTester tester,
    Widget card, {
    PantryView pantry = const PantryView(),
    PharmacyView pharmacy = const PharmacyView(),
    List<Subscription> subs = const <Subscription>[],
    QuietShopping? shopping,
    QuietPharmacy? pharmacyController,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nowProvider.overrideWithValue(() => _now),
          pantryControllerProvider.overrideWith(() => QuietPantry(pantry)),
          pharmacyControllerProvider.overrideWith(
            () => pharmacyController ?? QuietPharmacy(pharmacy),
          ),
          shoppingControllerProvider.overrideWith(
            () => shopping ?? QuietShopping(),
          ),
          subscriptionsControllerProvider.overrideWith(() => _Subs(subs)),
          budgetControllerProvider.overrideWith(_Budget.new),
        ],
        child: MaterialApp(
          theme: ZadTheme.light(),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: SingleChildScrollView(child: card)),
          ),
        ),
      ),
    );
  }

  group('the pantry card', () {
    testWidgets('an empty pantry says so, not a blank rail', (tester) async {
      await pump(tester, const PantryGlanceCard());

      expect(find.text('المخزن لسه فاضي'), findsOneWidget);
      expect(find.text('فتح المخزون ←'), findsOneWidget);
    });

    testWidgets('counts what is short and scores the rest', (tester) async {
      final low = _item('1', 'لبن', 0);
      final fine = _item('2', 'أرز', 6);
      await pump(
        tester,
        const PantryGlanceCard(),
        pantry: PantryView(
          items: <InventoryItem>[low, fine],
          shortages: <Shortage>[
            Shortage(item: low, reason: ShortageReason.outOfStock),
          ],
        ),
      );

      expect(find.text('1 قارب النفاد'), findsOneWidget);
      expect(find.text('50% مكتمل'), findsOneWidget);
      expect(find.text('قارب ينتهي'), findsOneWidget);
      // The quantity, not a number of days it never measured.
      expect(find.text('متبقي 6 علبة'), findsOneWidget);
    });

    testWidgets('"أضف للسلة" puts the short item on the list', (tester) async {
      final low = _item('1', 'لبن', 0);
      final shopping = QuietShopping();
      await pump(
        tester,
        const PantryGlanceCard(),
        pantry: PantryView(
          items: <InventoryItem>[low],
          shortages: <Shortage>[
            Shortage(item: low, reason: ShortageReason.outOfStock),
          ],
        ),
        shopping: shopping,
      );

      await tester.tap(find.text('أضف للسلة'));
      await tester.pump();

      expect(shopping.added, <String>['لبن']);
    });
  });

  group('the pharmacy card', () {
    testWidgets('an empty pharmacy says so', (tester) async {
      await pump(tester, const PharmacyGlanceCard());

      expect(find.text('الصيدلية فاضية'), findsOneWidget);
      expect(find.text('مفيش أدوية مسجّلة'), findsOneWidget);
    });

    testWidgets('offers the dose that is due, and records it', (tester) async {
      final m = _med('بنادول', times: '09:00');
      final slot = _slot(m, 9);
      final controller = QuietPharmacy(
        PharmacyView(
          medicines: <Medicine>[m],
          today: <DoseSlot>[slot],
          adherence: 90,
        ),
      );
      await pump(
        tester,
        const PharmacyGlanceCard(),
        pharmacyController: controller,
      );

      expect(find.text('الالتزام بالجرعات: 90% • منتظم'), findsOneWidget);
      expect(find.text('بنادول • 09:00'), findsOneWidget);

      await tester.tap(find.text('خدت الجرعة'));
      await tester.pump();

      expect(controller.taken, <DoseSlot>[slot]);
    });

    testWidgets('a dose hours away is shown but cannot be taken yet', (
      tester,
    ) async {
      final m = _med('فيتامين', times: '20:00');
      await pump(
        tester,
        const PharmacyGlanceCard(),
        pharmacy: PharmacyView(
          medicines: <Medicine>[m],
          today: <DoseSlot>[_slot(m, 20)],
        ),
      );

      expect(find.text('فيتامين • 20:00'), findsOneWidget);
      expect(find.text('خدت الجرعة'), findsNothing);
      expect(
        find.text('1 دواء نشط • لسه بنجمّع بيانات الالتزام'),
        findsOneWidget,
      );
    });
  });

  group('the subscriptions card', () {
    testWidgets('none yet says so', (tester) async {
      await pump(tester, const SubscriptionsGlanceCard());

      expect(find.text('مفيش اشتراكات لسه'), findsOneWidget);
      expect(find.text('مفيش اشتراكات مسجّلة'), findsOneWidget);
    });

    testWidgets("totals the month and shows each one's share", (tester) async {
      await pump(
        tester,
        const SubscriptionsGlanceCard(),
        subs: const <Subscription>[
          Subscription(
            id: 'a',
            userId: 'u',
            title: 'نتفليكس',
            amount: 300,
            dueDay: 28,
          ),
          Subscription(
            id: 'b',
            userId: 'u',
            title: 'إنترنت',
            amount: 100,
            dueDay: 3,
          ),
        ],
      );

      expect(find.text('إجمالي شهري: 400'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
      expect(find.text('25%'), findsOneWidget);
      expect(find.textContaining('التجديد القادم: نتفليكس'), findsOneWidget);
    });
  });

  group('the dose rules', () {
    test('a due dose comes before an upcoming one', () {
      final m = _med('x', times: '09:00,20:00');
      final due = _slot(m, 9);
      final later = _slot(m, 20);
      expect(nextDoseOf(<DoseSlot>[due, later], _now), due);
    });

    test('taken and missed doses are not offered', () {
      final m = _med('x');
      final taken = _slot(m, 8, takenAt: DateTime.utc(2026, 9, 25, 8));
      final missed = _slot(m, 2);
      expect(nextDoseOf(<DoseSlot>[missed, taken], _now), isNull);
    });

    test('the week counts taken over settled, not over pending', () {
      final m = _med('x');
      final slots = <DoseSlot>[
        _slot(m, 1, takenAt: DateTime.utc(2026, 9, 25, 1)),
        _slot(m, 2),
        _slot(m, 3, takenAt: DateTime.utc(2026, 9, 25, 3)),
        _slot(m, 4, takenAt: DateTime.utc(2026, 9, 25, 4)),
        // Due now, still answerable: neither taken nor missed.
        _slot(m, 8),
      ];
      expect(weeklyAdherence(slots, _now), 75);
    });

    test('nothing settled yet reads as no figure, not 0%', () {
      final m = _med('x');
      expect(weeklyAdherence(<DoseSlot>[_slot(m, 20)], _now), isNull);
    });
  });

  test('a pantry line gets its picture from its name', () {
    expect(foodEmoji('لبن كامل الدسم'), '🥛');
    expect(foodEmoji('صابون'), '🧼');
    expect(foodEmoji('حاجة غريبة'), '🍽️');
  });

  testWidgets('the three cards, as Home draws them', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1180));
    final milk = _item('1', 'لبن', 0);
    final rice = _item('2', 'أرز بسمتي', 6);
    final m = _med('بنادول', times: '09:00');
    await pump(
      tester,
      const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            PantryGlanceCard(),
            SizedBox(height: 16),
            PharmacyGlanceCard(),
            SizedBox(height: 16),
            SubscriptionsGlanceCard(),
          ],
        ),
      ),
      pantry: PantryView(
        items: <InventoryItem>[milk, rice],
        shortages: <Shortage>[
          Shortage(item: milk, reason: ShortageReason.outOfStock),
        ],
      ),
      pharmacy: PharmacyView(
        medicines: <Medicine>[m],
        today: <DoseSlot>[_slot(m, 9)],
        adherence: 86,
      ),
      subs: const <Subscription>[
        Subscription(
          id: 'a',
          userId: 'u',
          title: 'نتفليكس',
          amount: 300,
          dueDay: 28,
        ),
        Subscription(
          id: 'b',
          userId: 'u',
          title: 'إنترنت',
          amount: 100,
          dueDay: 3,
        ),
      ],
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/glance_cards.png'),
    );
  });
}
