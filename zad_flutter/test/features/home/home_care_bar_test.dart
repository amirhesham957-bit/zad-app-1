// Home's care bar: what it lists and in what order, what it says about
// renewals, where its cards lead, and that it fits a small phone.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/features/home/presentation/home_care_bar.dart';
import 'package:zad/shared/budget/application/budget_controller.dart';
import 'package:zad/shared/navigation/zad_screens.dart';
import 'package:zad/shared/pharmacy/application/pharmacy_controller.dart';
import 'package:zad/shared/pharmacy/domain/dose_slot.dart';
import 'package:zad/shared/pharmacy/domain/dose_time.dart';
import 'package:zad/shared/pharmacy/domain/medicine.dart';
import 'package:zad/shared/subscriptions/application/subscriptions_controller.dart';
import 'package:zad/shared/subscriptions/domain/subscription.dart';

import '../../support/fonts.dart';
import '../../support/quiet_household.dart';

/// 09:00 UTC: a dose set for 09:00 is due, one for 12:00 is still to come.
final DateTime _now = DateTime.utc(2026, 9, 25, 9);

class _Budget extends BudgetController {
  @override
  BudgetView build() => const BudgetView();
}

class _Subs extends SubscriptionsController {
  new(this.items, this.day);

  final List<Subscription> items;
  final DateTime day;

  @override
  SubscriptionsView build() => SubscriptionsView(items: items, today: day);

  @override
  Future<void> refresh({bool force = false}) async {}
}

Medicine _med(String name) => Medicine(
  id: name,
  userId: 'u',
  name: name,
  doseTimesRaw: '09:00',
  dailyDoseCount: 1,
  remainingQuantity: 20,
);

DoseSlot _slot(Medicine m, int hour, {DateTime? takenAt}) => DoseSlot(
  medicine: m,
  time: DoseTime(hour, 0),
  scheduledAt: DateTime.utc(2026, 9, 25, hour),
  takenAt: takenAt,
);

Subscription _sub(String title, int dueDay) => Subscription(
  id: title,
  userId: 'u',
  title: title,
  amount: 50,
  dueDay: dueDay,
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
    await loadZadFonts();
  });

  Future<void> pump(
    WidgetTester tester, {
    List<DoseSlot> slots = const <DoseSlot>[],
    List<Subscription> subs = const <Subscription>[],
    DateTime? today,
    double width = 360,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nowProvider.overrideWithValue(() => _now),
          pharmacyControllerProvider.overrideWith(
            () => QuietPharmacy(PharmacyView(today: slots)),
          ),
          subscriptionsControllerProvider.overrideWith(
            () => _Subs(subs, today ?? DateTime.utc(2026, 9, 25)),
          ),
          budgetControllerProvider.overrideWith(_Budget.new),
        ],
        child: MaterialApp(
          theme: ZadTheme.light(),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: HomeCareBar(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // RTL: the first card sits furthest right.
  double right(WidgetTester tester, String text) =>
      tester.getTopRight(find.text(text)).dx;

  testWidgets('doses first, soonest first, then renewals soonest first', (
    tester,
  ) async {
    await pump(
      tester,
      slots: <DoseSlot>[
        _slot(_med('دواء المساء'), 12),
        _slot(_med('دواء الصبح'), 9),
      ],
      subs: <Subscription>[_sub('بعيد', 29), _sub('قريب', 27)],
      width: 1400,
    );

    final order = <String>['دواء الصبح', 'دواء المساء', 'قريب', 'بعيد'];
    for (var i = 0; i < order.length - 1; i++) {
      expect(
        right(tester, order[i]),
        greaterThan(right(tester, order[i + 1])),
        reason: '${order[i]} should come before ${order[i + 1]}',
      );
    }
    expect(find.text('اشتراكاتك وأدويتك'), findsOneWidget);
  });

  testWidgets('a dose already taken is not offered', (tester) async {
    await pump(tester, slots: <DoseSlot>[_slot(_med('خلص'), 9, takenAt: _now)]);
    expect(find.text('خلص'), findsNothing);
    expect(find.text('اشتراكاتك وأدويتك'), findsNothing);
  });

  testWidgets('nothing to show renders nothing', (tester) async {
    await pump(tester);
    expect(find.byType(HomeCareBar), findsOneWidget);
    expect(find.byType(ListView), findsNothing);
    expect(find.text('اشتراكاتك وأدويتك'), findsNothing);
  });

  testWidgets('renewal days count from the account day, not the device', (
    tester,
  ) async {
    // The device clock (real today) is irrelevant: the view's day is Sep 25.
    await pump(
      tester,
      subs: <Subscription>[
        _sub('اليوم', 25),
        _sub('بكرة', 26),
        _sub('بعد ثلاث', 28),
      ],
      width: 1400,
    );
    expect(find.text('بيتجدد النهارده'), findsOneWidget);
    expect(find.text('بيتجدد بكرة'), findsOneWidget);
    expect(find.text('بيتجدد بعد 3 يوم'), findsOneWidget);
  });

  testWidgets(
    'a subscription card opens subscriptions, a dose opens pharmacy',
    (tester) async {
      var subsOpened = 0;
      final household = <Object>[];
      ZadScreens.showSubscriptionsScreen = (_) async => subsOpened++;
      ZadScreens.showHouseholdSection = (_, section) async =>
          household.add(section);

      await pump(
        tester,
        slots: <DoseSlot>[_slot(_med('بنادول'), 9)],
        subs: <Subscription>[_sub('نتفلكس', 28)],
      );

      await tester.tap(find.text('نتفلكس'));
      await tester.pump();
      expect(subsOpened, 1);

      await tester.tap(find.text('بنادول'));
      await tester.pump();
      expect(household, hasLength(1));
      expect(household.single.toString(), contains('pharmacy'));
    },
  );

  testWidgets('the cards fit a 360 wide screen with no overflow', (
    tester,
  ) async {
    await pump(
      tester,
      slots: <DoseSlot>[_slot(_med('دواء باسم طويل جدا جدا جدا جدا'), 9)],
      subs: <Subscription>[_sub('اشتراك باسم طويل جدا جدا جدا جدا جدا', 28)],
    );
    expect(tester.takeException(), isNull);
    final bar = tester.getSize(find.byType(ListView));
    expect(bar.width, lessThanOrEqualTo(360));
  });
}
