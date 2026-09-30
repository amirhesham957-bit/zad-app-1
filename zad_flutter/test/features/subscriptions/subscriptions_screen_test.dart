// Kotlin's SubscriptionsScreen: the banner, «النشطة»/«الكل», the renewal
// line, «تم الدفع ✓» on a running row only, and AddEditSubscriptionDialog.
//
// The controller is a recording fake: every write in this app ends in a Hive
// put, and one inside a widget test never completes under the fake clock.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:zad/core/design/zad_theme.dart';
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

  testWidgets("an empty list: Kotlin's banner, empty state and FAB", (
    tester,
  ) async {
    await pump(tester, <Subscription>[]);
    expect(find.text('إجمالي الاشتراكات الشهرية'), findsOneWidget);
    expect(find.text('لا توجد اشتراكات'), findsOneWidget);
    expect(find.byTooltip('إضافة'), findsOneWidget);
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
    await tester.tap(find.text('تم الدفع ✓'));
    await tester.pump();
    expect(subs.calls, <String>['paid:a']);
  });

  testWidgets('a stopped row is not offered «تم الدفع ✓»', (tester) async {
    await pump(tester, <Subscription>[
      _sub('b', 'Shahid', renewalDate: '2026-09-25', active: false),
    ]);
    await tester.tap(find.widgetWithText(FilterChip, 'الكل'));
    await tester.pumpAndSettle();
    expect(find.text('تم الدفع ✓'), findsNothing);
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

    expect(subs.calls, <String>['add:الكهربا:420.0:MONTHLY:utility']);
  });
}
