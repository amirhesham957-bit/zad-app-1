// "الميزانية والالتزامات": the parts Kotlin's budget screen has, fed from the
// controllers the rest of the app already uses.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:zad/core/data/local/boxes.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/features/budget/presentation/finances_screen.dart';
import 'package:zad/features/obligations/application/obligations_controller.dart';
import 'package:zad/features/obligations/domain/obligation.dart';
import 'package:zad/features/obligations/presentation/obligations_section.dart';
import 'package:zad/features/subscriptions/presentation/subscriptions_screen.dart';
import 'package:zad/shared/budget/application/budget_controller.dart';
import 'package:zad/shared/budget/application/category_budgets_controller.dart';
import 'package:zad/shared/budget/domain/budget_snapshot.dart';
import 'package:zad/shared/modes/application/modes_controller.dart';
import 'package:zad/shared/settings/application/settings_controller.dart';
import 'package:zad/shared/settings/domain/account_settings.dart';
import 'package:zad/shared/subscriptions/application/subscriptions_controller.dart';
import 'package:zad/shared/subscriptions/domain/subscription.dart';
import 'package:zad/shared/transactions/application/transactions_controller.dart';
import 'package:zad/shared/transactions/domain/transaction.dart';
import 'package:zad/shared/worlds/art/art.dart';

import '../../support/fonts.dart';
import '../../support/quiet_household.dart';

final DateTime _today = DateTime.utc(2026, 9, 25);

class _Budget extends BudgetController {
  new([this.view = const BudgetView()]);

  final BudgetView view;

  @override
  BudgetView build() => view;
}

BudgetView _realBudget() => BudgetView(
  snapshot: BudgetSnapshot(
    userId: 'u',
    currency: 'ج.م',
    timeZone: 'Africa/Cairo',
    spent: 4760,
    income: 8000,
    committed: 3000,
    daysLeft: 12,
    cycleLengthDays: 30,
    threat: BudgetThreat.safe,
    unverifiedCount: 0,
    computedAt: DateTime.utc(2026, 9, 25),
    available: 1240,
    remaining: 4240,
    openingBalance: 5000,
    limitConfirmed: true,
    cycleEnd: DateTime.utc(2026, 10, 7),
  ),
);

class _Settings extends SettingsController {
  @override
  SettingsView build() =>
      const SettingsView(settings: AccountSettings(monthlyLimit: 5000));
}

class _Txns extends TransactionsController {
  @override
  TransactionsView build() => TransactionsView(
    rows: <ZadTransaction>[
      ZadTransaction.fromJson(<String, dynamic>{
        'id': 't',
        'user_id': 'u',
        'amount': 400,
        'title': 'سوبرماركت',
        'created_at': '2026-09-20T10:00:00Z',
        'txn_kind': 'expense',
        'is_expense': true,
        'category': 'البقالة',
      }),
    ],
  );

  @override
  Future<void> refresh({bool force = false}) async {}
}

class _Obligations extends ObligationsController {
  @override
  ObligationsView build() => ObligationsView(
    today: _today,
    items: const <Obligation>[
      Obligation(
        id: 'r',
        userId: 'u',
        title: 'إيجار الشقة',
        amount: 3000,
        dueDay: 28,
      ),
    ],
  );

  @override
  Future<void> refresh({bool force = false}) async {}
}

class _Subs extends SubscriptionsController {
  @override
  SubscriptionsView build() =>
      SubscriptionsView(items: const <Subscription>[], today: _today);

  @override
  Future<void> refresh({bool force = false}) async {}
}

void main() {
  setUpAll(() async {
    tz_data.initializeTimeZones();
    await initializeDateFormatting('ar');
  });

  // The suggestion and deals cards read the device box. Opened here, never
  // inside testWidgets: a Hive write under the fake clock never completes.
  late Directory dir;
  late ZadLocalStore store;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('zad_finances_test');
    Hive.init(dir.path);
    store = await ZadLocalStore.open();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  Future<void> pumpFinances(
    WidgetTester tester, {
    BudgetView view = const BudgetView(),
    Size size = const Size(400, 2400),
    bool still = false,
    bool embedded = false,
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          budgetControllerProvider.overrideWith(() => _Budget(view)),
          settingsControllerProvider.overrideWith(_Settings.new),
          transactionsControllerProvider.overrideWith(_Txns.new),
          obligationsControllerProvider.overrideWith(_Obligations.new),
          subscriptionsControllerProvider.overrideWith(_Subs.new),
          categoryBudgetsProvider.overrideWith(_NoCeilings.new),
          ...quietOrbOverrides,
          modesControllerProvider.overrideWith(QuietModes.new),
          localStoreProvider.overrideWithValue(store),
          supabaseClientProvider.overrideWithValue(quietSupabase),
        ],
        child: MediaQuery(
          data: MediaQueryData(disableAnimations: still),
          child: MaterialApp(
            theme: ZadTheme.light(),
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: FinancesScreen(embedded: embedded),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows obligations, the summary and the category cards', (
    tester,
  ) async {
    await pumpFinances(tester);

    // The world's title (and the summary column of the same name).
    expect(find.text('الميزانية'), findsNWidgets(2));
    expect(find.text('الحركات والميزانية'), findsOneWidget);
    expect(find.text('إجمالي الالتزامات'), findsOneWidget);
    expect(find.byType(ObligationCard), findsOneWidget);
    expect(
      find.text('مستحق'),
      findsOneWidget,
      reason: 'the 28th is 3 days off',
    );
    expect(find.text('5,000'), findsOneWidget, reason: 'the budget column');
    // No snapshot, nothing spent by the server's count: the calm tier.
    expect(find.textContaining('صرفت 0% فقط'), findsOneWidget);
    // The category card's title, and the purchase's row under it.
    expect(find.textContaining('البقالة'), findsNWidgets(2));
    expect(find.textContaining('بدون حد'), findsOneWidget);
  });

  testWidgets('the state line is the real available amount and per-day '
      'allowance', (tester) async {
    await pumpFinances(tester, view: _realBudget());
    // 1,240 available over 12 days left is 103 a day.
    expect(find.text('متاح 1,240 ج.م · 103 ج.م في اليوم'), findsOneWidget);
    expect(find.text('لحد يوم 7'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('has no overflow at 360x640, embedded or pushed', (tester) async {
    for (final embedded in <bool>[true, false]) {
      await pumpFinances(
        tester,
        view: _realBudget(),
        size: const Size(360, 640),
        embedded: embedded,
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(ZadArt), findsWidgets);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('the obligations tab is still one tap away', (tester) async {
    await pumpFinances(tester, size: const Size(360, 900));
    await tester.tap(find.text('التزاماتي'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
    expect(find.byType(SubscriptionsScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('with disableAnimations the scene is still', (tester) async {
    await pumpFinances(tester, still: true, view: _realBudget());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('screenshot: the budget world', (tester) async {
    await loadZadFonts();
    await pumpFinances(tester, view: _realBudget(), still: true);
    tester.view
      ..physicalSize = const Size(860, 1864)
      ..devicePixelRatio = 2;
    await tester.pump(const Duration(milliseconds: 600));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../../build/screens/world_budget.png'),
    );
  }, skip: Platform.environment['ZAD_SCREENS'] != '1');
}

class _NoCeilings extends CategoryBudgetsController {
  @override
  Map<String, double> build() => const <String, double>{};
}
