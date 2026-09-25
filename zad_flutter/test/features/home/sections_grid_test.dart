// Home's sections grid: two rows first, the rest behind "كل الأقسام", badges
// from the controllers the sections already have.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/design/zad_theme.dart';
import 'package:zad/features/home/presentation/sections_grid.dart';
import 'package:zad/features/inventory/application/pantry_controller.dart';
import 'package:zad/features/inventory/application/shopping_controller.dart';
import 'package:zad/features/inventory/domain/inventory_item.dart';
import 'package:zad/features/inventory/domain/shortage.dart';
import 'package:zad/features/subscriptions/application/subscriptions_controller.dart';
import 'package:zad/features/subscriptions/domain/subscription.dart';

import '../../support/fonts.dart';
import '../../support/quiet_household.dart';

class _Subs extends SubscriptionsController {
  new(this.items);

  final List<Subscription> items;

  @override
  SubscriptionsView build() =>
      SubscriptionsView(items: items, today: DateTime.utc(2026, 9, 25));

  @override
  Future<void> refresh({bool force = false}) async {}
}

void main() {
  setUpAll(loadZadFonts);

  Future<void> pump(
    WidgetTester tester, {
    PantryView pantry = const PantryView(),
    List<Subscription> subs = const <Subscription>[],
  }) => tester.pumpWidget(
    ProviderScope(
      overrides: [
        pantryControllerProvider.overrideWith(() => QuietPantry(pantry)),
        shoppingControllerProvider.overrideWith(QuietShopping.new),
        subscriptionsControllerProvider.overrideWith(() => _Subs(subs)),
      ],
      child: MaterialApp(
        theme: ZadTheme.light(),
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: SingleChildScrollView(child: SectionsGrid())),
        ),
      ),
    ),
  );

  testWidgets('shows eight, and the rest on "كل الأقسام"', (tester) async {
    await pump(tester);

    expect(find.byType(SectionTile), findsNWidgets(kSectionsCollapsed));
    await tester.tap(find.text('كل الأقسام (${zadSections.length})'));
    await tester.pumpAndSettle();

    expect(find.byType(SectionTile), findsNWidgets(zadSections.length));
    expect(find.text('أقسام أقل'), findsOneWidget);
  });

  testWidgets('the pantry tile counts what needs buying', (tester) async {
    const milk = InventoryItem(
      id: '1',
      userId: 'u',
      itemName: 'لبن',
      quantity: 0,
    );
    await pump(
      tester,
      pantry: const PantryView(
        items: <InventoryItem>[milk],
        shortages: <Shortage>[
          Shortage(item: milk, reason: ShortageReason.outOfStock),
        ],
      ),
    );

    expect(find.bySemanticsLabel(RegExp('^المخزون، 1')), findsOneWidget);
  });

  test('a renewal within the week counts, one further out does not', () {
    final view = SubscriptionsView(
      items: const <Subscription>[
        Subscription(id: 'a', userId: 'u', title: 'a', amount: 1, dueDay: 28),
        Subscription(id: 'b', userId: 'u', title: 'b', amount: 1, dueDay: 20),
      ],
      today: DateTime.utc(2026, 9, 25),
    );
    expect(renewalsWithinAWeek(view), 1);
  });

  testWidgets('the grid, opened', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 420));
    await pump(tester);
    await tester.tap(find.text('كل الأقسام (${zadSections.length})'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/sections_grid.png'),
    );
  });
}
