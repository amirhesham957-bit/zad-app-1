// The four money worlds (المعاملات، الميزانية، كشف الحساب، الاشتراكات), with
// sample data, rendered to build/screens/ when ZAD_SCREENS=1:
//   ZAD_SCREENS=1 flutter test -j 1 --update-goldens \
//     test/shared/worlds/money_worlds_screens_test.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:zad/core/data/local/boxes.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/budget/presentation/budget_world.dart';
import 'package:zad/features/obligations/application/obligations_controller.dart';
import 'package:zad/features/obligations/domain/obligation.dart';
import 'package:zad/features/transactions/presentation/transactions_screen.dart';
import 'package:zad/shared/budget/application/budget_controller.dart';
import 'package:zad/shared/budget/application/category_budgets_controller.dart';
import 'package:zad/shared/budget/domain/budget_snapshot.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/modes/application/modes_controller.dart';
import 'package:zad/shared/navigation/zad_screens.dart';
import 'package:zad/shared/settings/application/settings_controller.dart';
import 'package:zad/shared/settings/domain/account_settings.dart';
import 'package:zad/shared/subscriptions/application/subscriptions_controller.dart';
import 'package:zad/shared/subscriptions/domain/subscription.dart';
import 'package:zad/shared/transactions/application/transactions_controller.dart';
import 'package:zad/shared/transactions/domain/transaction.dart';

import '../../support/fonts.dart';
import '../../support/quiet_household.dart';

Widget _app(Widget home, List<Override> overrides) => ProviderScope(
  overrides: <Override>[
    ...quietOrbOverrides,
    nowProvider.overrideWithValue(() => DateTime.utc(2026, 9, 25, 9)),
    accountTimeZoneProvider.overrideWithValue('Africa/Cairo'),
    ...overrides,
  ],
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ZadTheme.light(),
    locale: const Locale('ar'),
    supportedLocales: ZadL10n.supportedLocales,
    localizationsDelegates: ZadL10n.localizationsDelegates,
    home: home,
  ),
);

Future<void> _phone(WidgetTester tester) async {
  await loadZadFonts();
  tester.view
    ..physicalSize = const Size(1080, 2400)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  ZadScreens.worldScreen = (w) => (_) async {};
}

class _Txns extends TransactionsController {
  new(this.rows);
  final List<ZadTransaction> rows;
  @override
  TransactionsView build() => TransactionsView(rows: rows);
  @override
  Future<void> refresh({bool force = false}) async {}
}

ZadTransaction _tx(
  String id,
  String title,
  double amount, {
  String? category,
  bool income = false,
  String? source,
  String? bank,
  int hour = 8,
}) => ZadTransaction.fromJson(<String, dynamic>{
  'id': id,
  'user_id': 'u',
  'amount': amount,
  'title': title,
  'category': category,
  'created_at': DateTime.utc(2026, 9, 25, hour).toIso8601String(),
  'wallet': 'card',
  'txn_kind': income ? 'income' : 'expense',
  'is_expense': !income,
  'source_type': source,
  'bank_name': bank,
});

class _Budget extends BudgetController {
  @override
  BudgetView build() => BudgetView(
    snapshot: BudgetSnapshot(
      userId: 'u',
      currency: 'ر.س',
      timeZone: 'Africa/Cairo',
      spent: 4760,
      income: 12000,
      committed: 5430,
      daysLeft: 12,
      cycleLengthDays: 30,
      threat: BudgetThreat.watch,
      unverifiedCount: 0,
      computedAt: DateTime.utc(2026, 9, 25),
      available: 1240,
      remaining: 6670,
      openingBalance: 12000,
      limitConfirmed: true,
      cycleEnd: DateTime.utc(2026, 10, 25),
    ),
  );
}

class _Settings extends SettingsController {
  @override
  SettingsView build() =>
      const SettingsView(settings: AccountSettings(monthlyLimit: 12000));
}

class _Ceilings extends CategoryBudgetsController {
  @override
  Map<String, double> build() => const <String, double>{
    'المطاعم': 1500,
    'المواصلات': 900,
    'الفواتير': 1800,
    'الاشتراكات': 400,
  };
}

class _Obligations extends ObligationsController {
  @override
  ObligationsView build() => ObligationsView(
    today: DateTime.utc(2026, 9, 25),
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
  SubscriptionsView build() => SubscriptionsView(
    items: const <Subscription>[],
    today: DateTime.utc(2026, 9, 25),
  );
  @override
  Future<void> refresh({bool force = false}) async {}
}

void main() {
  late Directory dir;
  late ZadLocalStore store;
  setUpAll(() async {
    tz_data.initializeTimeZones();
    await initializeDateFormatting('ar');
  });
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('zad_money_worlds');
    Hive.init(dir.path);
    store = await ZadLocalStore.open();
  });
  tearDown(() async {
    ZadScreens.worldScreen = (_) => null;
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });
  final shoot = Platform.environment['ZAD_SCREENS'] == '1';

  testWidgets('screenshot: the transactions world', (tester) async {
    await _phone(tester);
    await tester.pumpWidget(
      _app(const TransactionsScreen(), [
        transactionsControllerProvider.overrideWith(
          () => _Txns(<ZadTransaction>[
            _tx(
              '1',
              'قهوة',
              50,
              category: 'المشروبات',
              source: 'bank_sms',
              bank: 'الراجحي',
            ),
            _tx(
              '2',
              'بنده',
              214,
              category: 'البقالة',
              source: 'receipt',
              hour: 7,
            ),
            _tx(
              '3',
              'بنزين',
              90,
              category: 'مواصلات',
              source: 'voice',
              hour: 6,
            ),
            _tx(
              '4',
              'النهدي',
              38,
              category: 'الرعاية الصحية',
              source: 'bank_notification',
              bank: 'الأهلي',
              hour: 5,
            ),
            _tx('5', 'مرتب', 12000, income: true, category: 'دخل', hour: 4),
          ]),
        ),
      ]),
    );
    await tester.pump(const Duration(milliseconds: 900));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../../build/screens/world_transactions.png'),
    );
    await tester.pumpWidget(const SizedBox());
  }, skip: !shoot);

  testWidgets('screenshot: the budget world', (tester) async {
    await _phone(tester);
    await tester.pumpWidget(
      _app(const Scaffold(body: BudgetWorld(showBack: false)), [
        budgetControllerProvider.overrideWith(_Budget.new),
        settingsControllerProvider.overrideWith(_Settings.new),
        categoryBudgetsProvider.overrideWith(_Ceilings.new),
        obligationsControllerProvider.overrideWith(_Obligations.new),
        subscriptionsControllerProvider.overrideWith(_Subs.new),
        modesControllerProvider.overrideWith(QuietModes.new),
        localStoreProvider.overrideWithValue(store),
        supabaseClientProvider.overrideWithValue(quietSupabase),
        transactionsControllerProvider.overrideWith(
          () => _Txns(<ZadTransaction>[
            _tx('1', 'غداء', 220, category: 'المطاعم'),
            _tx('2', 'عشاء', 480, category: 'المطاعم', hour: 7),
            _tx('3', 'أوبر', 600, category: 'المواصلات', hour: 6),
            _tx('4', 'كهرباء', 1700, category: 'الفواتير', hour: 5),
            _tx('5', 'نتفلكس', 56, category: 'الاشتراكات', hour: 4),
            _tx('6', 'مرتب', 12000, income: true, category: 'دخل', hour: 3),
          ]),
        ),
      ]),
    );
    await tester.pump(const Duration(milliseconds: 900));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../../build/screens/world_budget.png'),
    );
    await tester.pumpWidget(const SizedBox());
  }, skip: !shoot);
}
