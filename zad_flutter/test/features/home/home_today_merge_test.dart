// «النهارده في بيتك» carries what the dropped care bar offered (each
// medicine's next dose, every subscription with its amount, each leading to
// its world), and the tasbih card shows a real count or a start state.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/home/presentation/home_today_card.dart';
import 'package:zad/features/home/presentation/tasbiha_home_widget.dart';
import 'package:zad/shared/budget/application/budget_controller.dart';
import 'package:zad/shared/navigation/zad_screens.dart';
import 'package:zad/shared/pharmacy/application/pharmacy_controller.dart';
import 'package:zad/shared/pharmacy/domain/dose_slot.dart';
import 'package:zad/shared/pharmacy/domain/dose_time.dart';
import 'package:zad/shared/pharmacy/domain/medicine.dart';
import 'package:zad/shared/subscriptions/application/subscriptions_controller.dart';
import 'package:zad/shared/subscriptions/domain/subscription.dart';
import 'package:zad/shared/tasbiha/domain/tasbiha.dart';

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

  Future<void> pumpCard(
    WidgetTester tester, {
    List<DoseSlot> slots = const <DoseSlot>[],
    List<Subscription> subs = const <Subscription>[],
  }) async {
    tester.view
      ..physicalSize = const Size(800, 2400)
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nowProvider.overrideWithValue(() => _now),
          ...quietHouseholdOverrides.take(1),
          ...quietHouseholdOverrides.skip(2),
          pharmacyControllerProvider.overrideWith(
            () => QuietPharmacy(PharmacyView(today: slots)),
          ),
          subscriptionsControllerProvider.overrideWith(() => _Subs(subs)),
          budgetControllerProvider.overrideWith(_Budget.new),
        ],
        child: MaterialApp(
          theme: ZadTheme.light(),
          locale: const Locale('ar'),
          localizationsDelegates: ZadL10n.localizationsDelegates,
          supportedLocales: ZadL10n.supportedLocales,
          home: const Scaffold(
            body: SingleChildScrollView(child: HomeTodayCard()),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('every medicine and every subscription is a row, soonest first', (
    tester,
  ) async {
    await pumpCard(
      tester,
      slots: <DoseSlot>[
        _slot(_med('دواء المساء'), 12),
        _slot(_med('دواء الصبح'), 9),
      ],
      subs: <Subscription>[_sub('بعيد', 29), _sub('قريب', 27)],
    );
    final order = <String>['دواء الصبح', 'دواء المساء', 'قريب', 'بعيد'];
    for (var i = 0; i < order.length - 1; i++) {
      expect(
        tester.getTopLeft(find.text(order[i])).dy,
        lessThan(tester.getTopLeft(find.text(order[i + 1])).dy),
      );
    }
    expect(find.text('اشتراكاتك وأدويتك'), findsNothing);
  });

  testWidgets('a taken dose is not offered; nothing due says so', (
    tester,
  ) async {
    await pumpCard(
      tester,
      slots: <DoseSlot>[_slot(_med('خلص'), 9, takenAt: _now)],
    );
    expect(find.text('خلص'), findsNothing);
    expect(
      find.text(tester.element(find.byType(HomeTodayCard)).l10n.homeTodayEmpty),
      findsOneWidget,
    );
  });

  testWidgets('rows lead to subscriptions and the pharmacy, amount shown', (
    tester,
  ) async {
    var subsOpened = 0;
    final household = <Object>[];
    ZadScreens.showSubscriptionsScreen = (_) async => subsOpened++;
    ZadScreens.showHouseholdSection = (_, s) async => household.add(s);
    await pumpCard(
      tester,
      slots: <DoseSlot>[_slot(_med('بنادول'), 9)],
      subs: <Subscription>[_sub('نتفلكس', 28)],
    );
    expect(find.text('50'), findsOneWidget);
    await tester.tap(find.text('نتفلكس'));
    await tester.pump();
    expect(subsOpened, 1);
    await tester.tap(find.text('بنادول'));
    await tester.pump();
    expect(household.single.toString(), contains('pharmacy'));
  });

  Future<void> pumpTasbih(WidgetTester tester, GardenTree? tree) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(
      MaterialApp(
        theme: ZadTheme.light(),
        locale: const Locale('ar'),
        localizationsDelegates: ZadL10n.localizationsDelegates,
        supportedLocales: ZadL10n.supportedLocales,
        home: Scaffold(
          body: TasbihaHomeWidget(tree: tree, onTasbih: () {}, onOpen: () {}),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('no tree: a start line, never 0 / 0, no tasbih button', (
    tester,
  ) async {
    await pumpTasbih(tester, null);
    expect(find.text('ابدأ بستانك بأول تسبيحة'), findsOneWidget);
    expect(find.textContaining('0 / 0'), findsNothing);
    expect(find.text('سبحان الله'), findsNothing);
  });

  testWidgets('a tree: the real count towards its next stage', (tester) async {
    await pumpTasbih(
      tester,
      const GardenTree(id: 't', familyId: 'f', userId: 'u', score: 40),
    );
    expect(find.text('40 / 99'), findsOneWidget);
    expect(find.text('سبحان الله'), findsOneWidget);
  });
}
