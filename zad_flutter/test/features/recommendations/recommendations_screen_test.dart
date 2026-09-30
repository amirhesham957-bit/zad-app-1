// «نصايح زاد»: the brain's brief, live — never «شغلت كل التوصيات! 🎉» over a
// table nothing writes (owner, 2026-10-01).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/features/recommendations/presentation/recommendations_screen.dart';
import 'package:zad/shared/alerts/application/local_reminders.dart';
import 'package:zad/shared/budget/application/budget_controller.dart';
import 'package:zad/shared/inventory/application/pantry_controller.dart';
import 'package:zad/shared/inventory/application/shopping_controller.dart';
import 'package:zad/shared/inventory/domain/inventory_item.dart';
import 'package:zad/shared/pharmacy/application/pharmacy_controller.dart';
import 'package:zad/shared/subscriptions/application/subscriptions_controller.dart';
import 'package:zad/shared/subscriptions/domain/subscription.dart';

import '../../support/quiet_household.dart';

class _Budget extends BudgetController {
  @override
  BudgetView build() => const BudgetView();
}

class _Subs extends SubscriptionsController {
  @override
  SubscriptionsView build() => SubscriptionsView(
    items: const <Subscription>[],
    today: DateTime.utc(2026, 10),
  );

  @override
  Future<void> refresh({bool force = false}) async {}
}

void main() {
  setUpAll(() => initializeDateFormatting('ar'));

  Future<void> pump(WidgetTester tester, List<InventoryItem> pantry) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pharmacyControllerProvider.overrideWith(QuietPharmacy.new),
          shoppingControllerProvider.overrideWith(QuietShopping.new),
          supabaseClientProvider.overrideWithValue(quietSupabase),
          localRemindersProvider.overrideWith(QuietReminders.new),
          pantryControllerProvider.overrideWith(
            () => QuietPantry(PantryView(items: pantry)),
          ),
          budgetControllerProvider.overrideWith(_Budget.new),
          subscriptionsControllerProvider.overrideWith(_Subs.new),
          nowProvider.overrideWithValue(() => DateTime.utc(2026, 10, 1, 9)),
        ],
        child: MaterialApp(
          theme: ZadTheme.light(),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: RecommendationsScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('what ran out is there, and no empty table dressed as done', (
    tester,
  ) async {
    await pump(tester, const <InventoryItem>[
      InventoryItem(
        id: '1',
        userId: 'u',
        itemName: 'لبن',
        quantity: 0,
        lowStockThreshold: 1,
      ),
    ]);
    expect(find.text('محتاجك دلوقتي'), findsOneWidget);
    expect(find.textContaining('ناقصك لبن'), findsOneWidget);
    expect(find.textContaining('شغلت كل التوصيات'), findsNothing);
    expect(find.textContaining('كل ساعة'), findsNothing);
    expect(find.text('إجمالي التوفير'), findsNothing);
  });

  testWidgets('nothing to do says so, and says how it gets better', (
    tester,
  ) async {
    await pump(tester, const <InventoryItem>[]);
    expect(find.text('مفيش حاجة محتاجاك دلوقتي'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
