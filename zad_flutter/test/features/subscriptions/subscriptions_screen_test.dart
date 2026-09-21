// What the customer sees: the charge that comes next, the one they stopped,
// the date "paid" pays, and an empty list that says what to do.
//
// The controller is a recording fake: every write in this app ends in a Hive
// put, and one inside a widget test never completes under the fake clock.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:zad/design/zad_theme.dart';
import 'package:zad/features/budget/application/budget_controller.dart';
import 'package:zad/features/subscriptions/application/subscriptions_controller.dart';
import 'package:zad/features/subscriptions/data/subscriptions_repository.dart';
import 'package:zad/features/subscriptions/domain/renewal.dart';
import 'package:zad/features/subscriptions/domain/subscription.dart';
import 'package:zad/features/subscriptions/presentation/subscriptions_screen.dart';

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

  // Arabic month names, as `bootstrap` loads them. DateFormat throws without.
  setUpAll(() => initializeDateFormatting('ar'));

  Future<void> pump(WidgetTester tester, List<Subscription> items) async {
    subs = _Subs(items);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          subscriptionsControllerProvider.overrideWith(() => subs),
          budgetControllerProvider.overrideWith(_Budget.new),
        ],
        child: MaterialApp(
          theme: ZadTheme.light(),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: SubscriptionsScreen(),
          ),
        ),
      ),
    );
  }

  testWidgets('an empty list says what to do, and offers to do it', (
    tester,
  ) async {
    await pump(tester, <Subscription>[]);

    expect(find.text('مفيش اشتراكات ولا فواتير لسه'), findsOneWidget);
    expect(find.text('ضيف أول واحد'), findsOneWidget);
    // One way to add, not two: no floating button over the empty state.
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('rows say when they renew, and a stopped one says so', (
    tester,
  ) async {
    await pump(tester, <Subscription>[
      _sub('a', 'Netflix', renewalDate: '2026-09-22'),
      _sub('b', 'الكهربا', renewalDate: '2026-10-05', amount: 400),
      _sub('c', 'Shahid', active: false),
      _sub('d', 'جمعية'),
    ]);

    expect(find.text('بكرة'), findsOneWidget);
    expect(find.text('متوقف'), findsOneWidget);
    expect(find.text('ميعاده مش محدد'), findsOneWidget);
    // Running rows only: 150 + 400 + 150, the stopped Shahid excluded.
    expect(find.text('700'), findsOneWidget);
  });

  testWidgets('"paid" names the renewal it pays, and pays that row', (
    tester,
  ) async {
    await pump(tester, <Subscription>[
      _sub('a', 'Netflix', renewalDate: '2026-09-25'),
    ]);

    await tester.tap(find.text('Netflix'));
    await tester.pumpAndSettle();
    expect(find.textContaining('دفعت — 25 سبتمبر'), findsOneWidget);

    await tester.tap(find.textContaining('دفعت — '));
    await tester.pumpAndSettle();
    expect(subs.calls, <String>['paid:a']);
  });

  testWidgets('a stopped row is not offered "paid"', (tester) async {
    await pump(tester, <Subscription>[_sub('c', 'Shahid', active: false)]);

    await tester.tap(find.text('Shahid'));
    await tester.pumpAndSettle();

    expect(find.textContaining('دفعت'), findsNothing);
    await tester.tap(find.text('شغّله تاني'));
    await tester.pumpAndSettle();
    expect(subs.calls, <String>['active:c:true']);
  });

  testWidgets('the sheet saves only with a name and an amount', (tester) async {
    await pump(tester, <Subscription>[]);
    await tester.tap(find.text('ضيف أول واحد'));
    // Not pumpAndSettle: the name field autofocuses and its cursor blinks
    // forever.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    FilledButton save() =>
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'احفظ'));
    expect(save().onPressed, isNull);

    await tester.enterText(find.byType(TextField).at(0), 'الكهربا');
    await tester.pump();
    expect(save().onPressed, isNull, reason: 'no amount yet');

    await tester.tap(find.text('فاتورة'));
    await tester.enterText(find.byType(TextField).at(1), '420');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'احفظ'));
    await tester.pump();

    expect(subs.calls, <String>['add:الكهربا:420.0:MONTHLY:utility']);
  });
}
