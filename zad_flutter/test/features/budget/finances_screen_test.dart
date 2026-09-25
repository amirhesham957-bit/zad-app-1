// "الميزانية والالتزامات": the parts Kotlin's budget screen has, fed from the
// controllers the rest of the app already uses.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:zad/design/zad_theme.dart';
import 'package:zad/features/budget/application/budget_controller.dart';
import 'package:zad/features/budget/presentation/finances_screen.dart';
import 'package:zad/features/obligations/application/obligations_controller.dart';
import 'package:zad/features/obligations/domain/obligation.dart';
import 'package:zad/features/obligations/presentation/obligations_section.dart';
import 'package:zad/features/settings/application/settings_controller.dart';
import 'package:zad/features/settings/domain/account_settings.dart';
import 'package:zad/features/subscriptions/application/subscriptions_controller.dart';
import 'package:zad/features/subscriptions/domain/subscription.dart';
import 'package:zad/features/transactions/application/transactions_controller.dart';
import 'package:zad/features/transactions/domain/transaction.dart';

final DateTime _today = DateTime.utc(2026, 9, 25);

class _Budget extends BudgetController {
  @override
  BudgetView build() => const BudgetView();
}

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
  setUpAll(() => initializeDateFormatting('ar'));

  testWidgets('shows obligations, the summary and the category cards', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 2400));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          budgetControllerProvider.overrideWith(_Budget.new),
          settingsControllerProvider.overrideWith(_Settings.new),
          transactionsControllerProvider.overrideWith(_Txns.new),
          obligationsControllerProvider.overrideWith(_Obligations.new),
          subscriptionsControllerProvider.overrideWith(_Subs.new),
          categoryBudgetsProvider.overrideWith(_NoCeilings.new),
        ],
        child: MaterialApp(
          theme: ZadTheme.light(),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: FinancesScreen(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('الميزانية والالتزامات'), findsOneWidget);
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
    expect(find.text('البقالة'), findsOneWidget);
    expect(find.textContaining('بدون حد'), findsOneWidget);
  });
}

class _NoCeilings extends CategoryBudgetsController {
  @override
  Map<String, double> build() => const <String, double>{};
}
