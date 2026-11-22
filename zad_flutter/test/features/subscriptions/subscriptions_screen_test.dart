// Kotlin's SubscriptionsScreen: the banner, «النشطة»/«الكل», the renewal
// line, «تم الدفع ✓» on a running row only, and AddEditSubscriptionDialog.
//
// The controller is a recording fake: every write in this app ends in a Hive
// put, and one inside a widget test never completes under the fake clock.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/features/obligations/application/obligations_controller.dart';
import 'package:zad/features/obligations/domain/obligation.dart';
import 'package:zad/features/subscriptions/presentation/subscriptions_screen.dart';
import 'package:zad/shared/budget/application/budget_controller.dart';
import 'package:zad/shared/subscriptions/application/subscriptions_controller.dart';
import 'package:zad/shared/subscriptions/data/subscriptions_repository.dart';
import 'package:zad/shared/subscriptions/domain/renewal.dart';
import 'package:zad/shared/subscriptions/domain/subscription.dart';

import '../../support/fonts.dart';
import '../../support/quiet_household.dart';

final DateTime _today = DateTime.utc(2026, 9, 21);

class _Subs extends SubscriptionsController {
  new(this.items);

  final List<Subscription> items;
  final List<String> calls = <String>[];

  @override
  SubscriptionsView build() => SubscriptionsView(items: items, today: _today);

  @override
  Future<void> refresh({bool force = false}) async {}

  @override
  Future<void> add({
    required String title,
    required double amount,
    required BillingCycle cycle,
    DateTime? renewsOn,
    String? category,
    String type = SubscriptionType.subscription,
    String? provider,
  }) async => calls.add('add:$title:$amount:${cycle.wireName}:$type');

  @override
  Future<PaidRenewal?> markPaid(Subscription sub) async {
    calls.add('paid:${sub.id}');
    return null;
  }

  @override
  Future<void> setActive(Subscription sub, {required bool active}) async =>
      calls.add('active:${sub.id}:$active');
}

class _Obligations extends ObligationsController {
  new(this.items);

  final List<Obligation> items;
  final List<String> calls = <String>[];

  @override
  Future<void> add({
    required String title,
    required double amount,
    required ObligationKind kind,
    required Recurrence recurrence,
    int? dueDay,
  }) async => calls.add('add:$title:$amount:${kind.name}:${recurrence.name}');

  @override
  ObligationsView build() => ObligationsView(items: items, today: _today);

  @override
  Future<void> refresh({bool force = false}) async {}
}

class _Budget extends BudgetController {
  @override
  BudgetView build() => const BudgetView();
}

Subscription _sub(
  String id,
  String title, {
  String? renewalDate,
  bool active = true,
  String type = SubscriptionType.subscription,
  double amount = 150,
}) => Subscription(
  id: id,
  userId: 'u',
  title: title,
  amount: amount,
  renewalDate: renewalDate,
  billingCycle: 'MONTHLY',
  type: type,
  isActive: active,
);

void main() {
  late _Subs subs;
  late _Obligations obligationsFake;

  // Arabic month names, as `bootstrap` loads them. DateFormat throws without.
  setUpAll(() => initializeDateFormatting('ar'));

  Future<void> pump(
    WidgetTester tester,
    List<Subscription> items, {
    List<Obligation> obligations = const <Obligation>[],
  }) async {
    subs = _Subs(items);
    // The world is a screenful of scene before its first row: a phone-sized
    // window, unless the test already chose one.
    if (tester.view.devicePixelRatio != 1 &&
        tester.view.devicePixelRatio != 2) {
      tester.view
        ..physicalSize = const Size(430, 932)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...quietOrbOverrides,
          subscriptionsControllerProvider.overrideWith(() => subs),
          obligationsControllerProvider.overrideWith(
            () => obligationsFake = _Obligations(obligations),
          ),
          budgetControllerProvider.overrideWith(_Budget.new),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ZadTheme.light(),
          // The scene loops forever; a still one lets pumpAndSettle finish.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: SubscriptionsScreen(),
          ),
        ),
      ),
    );
  }

  testWidgets("an empty list: Kotlin's banner, empty state and FAB", (
    tester,
  ) async {
    await pump(tester, <Subscription>[]);
    expect(find.text('إجمالي الاشتراكات الشهرية'), findsOneWidget);
    expect(find.text('لا توجد اشتراكات'), findsOneWidget);
    expect(find.byTooltip('إضافة'), findsOneWidget);
  });

  testWidgets('the world: its title, and the total with the next charge', (
    tester,
  ) async {
    await pump(tester, <Subscription>[
      _sub('a', 'Netflix', renewalDate: '2026-09-24'),
      _sub('b', 'Spotify', renewalDate: '2026-09-30', amount: 50),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('الاشتراكات'), findsWidgets);
    expect(find.text('200 · Netflix بعد 3 يوم'), findsNothing);
    expect(find.text('200 في الشهر · Netflix بعد 3 يوم'), findsOneWidget);
  });

  testWidgets('the world with nothing in it: its state line and empty state', (
    tester,
  ) async {
    await pump(tester, <Subscription>[]);
    await tester.pumpAndSettle();
    expect(find.text('مفيش اشتراكات لسه'), findsOneWidget);
    expect(find.text('لا توجد اشتراكات'), findsOneWidget);
    expect(
      find.text('اضغط «إضافة» وزاد يحسب لك التجديد الجاي.'),
      findsOneWidget,
    );
  });

  testWidgets('a bill and a plan saved as obligations sit in their tabs', (
    tester,
  ) async {
    // Tall, so the rows under the scene are all built.
    tester.view
      ..physicalSize = const Size(430, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(
      tester,
      <Subscription>[_sub('a', 'Netflix', renewalDate: '2026-09-22')],
      obligations: const <Obligation>[
        Obligation(
          id: 'w',
          userId: 'u',
          title: 'فاتورة المية',
          amount: 120,
          dueDay: 5,
          kind: ObligationKind.utility,
        ),
        Obligation(
          id: 'v',
          userId: 'u',
          title: 'قسط فاليو',
          amount: 900,
          dueDay: 10,
          kind: ObligationKind.installment,
        ),
      ],
    );
    await tester.pumpAndSettle();
    // «الكل»: the subscription, then both obligations under their header.
    expect(find.text('التزامات ثابتة'), findsOneWidget);
    expect(find.text('فاتورة المية'), findsOneWidget);
    expect(find.text('قسط فاليو'), findsOneWidget);

    await tester.tap(find.text('فواتير'));
    await tester.pumpAndSettle();
    expect(find.text('فاتورة المية'), findsOneWidget);
    expect(find.text('قسط فاليو'), findsNothing);
    expect(find.text('لا توجد عناصر في هذا التصنيف'), findsNothing);

    await tester.tap(find.text('أقساط'));
    await tester.pumpAndSettle();
    expect(find.text('قسط فاليو'), findsOneWidget);
    expect(find.text('فاتورة المية'), findsNothing);

    await tester.tap(find.text('اشتراكات'));
    await tester.pumpAndSettle();
    expect(find.text('فاتورة المية'), findsNothing);
    expect(find.text('Netflix'), findsOneWidget);
  });

  testWidgets('rows say when they renew; a stopped one shows under «الكل»', (
    tester,
  ) async {
    await pump(tester, <Subscription>[
      _sub('a', 'Netflix', renewalDate: '2026-09-22'),
      _sub('b', 'Shahid', renewalDate: '2026-09-25', active: false),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('يُجدد بعد 1 يوم'), findsOneWidget);
    expect(find.text('Shahid'), findsNothing, reason: 'النشطة only');

    await tester.tap(find.widgetWithText(FilterChip, 'الكل'));
    await tester.pumpAndSettle();
    expect(find.text('Shahid'), findsOneWidget);
  });

  testWidgets('«تم الدفع ✓» pays that row', (tester) async {
    await pump(tester, <Subscription>[
      _sub('a', 'Netflix', renewalDate: '2026-09-25'),
    ]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('تم الدفع'));
    await tester.pump();
    expect(subs.calls, <String>['paid:a']);
  });

  testWidgets("a card's actions are full targets and fit a small phone", (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(360, 720)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(tester, <Subscription>[
      _sub('a', 'Netflix Premium Family', renewalDate: '2026-09-25'),
    ]);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('تم الدفع'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    for (final tooltip in <Finder>[
      find.byIcon(Icons.bolt),
      find.byIcon(Icons.pause_circle),
      find.byIcon(Icons.edit_note),
      find.byIcon(Icons.delete_outline),
    ]) {
      final target = tester.getSize(
        find.ancestor(of: tooltip, matching: find.byType(InkResponse)).first,
      );
      expect(target.shortestSide, greaterThanOrEqualTo(44));
    }
    final paid = tester.getSize(
      find
          .ancestor(of: find.text('تم الدفع'), matching: find.byType(InkWell))
          .first,
    );
    expect(paid.height, greaterThanOrEqualTo(44));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a stopped row is not offered «تم الدفع ✓»', (tester) async {
    await pump(tester, <Subscription>[
      _sub('b', 'Shahid', renewalDate: '2026-09-25', active: false),
    ]);
    await tester.tap(find.widgetWithText(FilterChip, 'الكل'));
    await tester.pumpAndSettle();
    expect(find.text('تم الدفع'), findsNothing);
    await tester.tap(find.byTooltip('تفعيل'));
    await tester.pump();
    expect(subs.calls, <String>['active:b:true']);
  });

  testWidgets('the dialog saves only with a name and an amount', (
    tester,
  ) async {
    await pump(tester, <Subscription>[]);
    await tester.tap(find.byTooltip('إضافة'));
    await tester.pumpAndSettle();
    expect(find.text('إضافة اشتراك جديد'), findsOneWidget);

    FilledButton save() =>
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'حفظ'));
    expect(save().onPressed, isNull);

    await tester.enterText(
      find.widgetWithText(TextField, 'اسم الاشتراك (مثال: Netflix)'),
      'الكهربا',
    );
    await tester.pump();
    expect(save().onPressed, isNull, reason: 'no amount yet');

    await tester.tap(find.widgetWithText(FilterChip, 'فاتورة'));
    await tester.enterText(
      find.ancestor(
        of: find.textContaining('المبلغ'),
        matching: find.byType(TextField),
      ),
      '420',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'حفظ'));
    await tester.pumpAndSettle();

    // A new bill is an obligation — bills have one home (20261005235107).
    expect(subs.calls, isEmpty);
    expect(obligationsFake.calls, <String>[
      'add:الكهربا:420.0:utility:monthly',
    ]);
  });

  testWidgets('screenshot: the subscriptions world', (tester) async {
    await loadZadFonts();
    tester.view
      ..physicalSize = const Size(860, 1864)
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await pump(tester, <Subscription>[
      _sub('a', 'Netflix', renewalDate: '2026-09-23', amount: 169),
      _sub('b', 'Spotify', renewalDate: '2026-09-28', amount: 59),
      _sub('c', 'Shahid', renewalDate: '2026-10-04', amount: 99),
      _sub('d', 'YouTube Premium', renewalDate: '2026-10-12', amount: 69),
      _sub('e', 'فاتورة إنترنت', renewalDate: '2026-10-16', amount: 350),
    ]);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../../build/screens/world_subs.png'),
    );
  }, skip: Platform.environment['ZAD_SCREENS'] != '1');
}
