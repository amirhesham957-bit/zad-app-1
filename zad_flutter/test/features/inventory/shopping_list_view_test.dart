// The shopping list: Kotlin's basket header, priority chips, share text and
// the tap-only smart fill.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/features/inventory/data/shopping_ai_remote.dart';
import 'package:zad/features/inventory/presentation/shopping_list_view.dart';
import 'package:zad/shared/budget/application/budget_controller.dart';
import 'package:zad/shared/inventory/application/pantry_controller.dart';
import 'package:zad/shared/inventory/application/shopping_controller.dart';
import 'package:zad/shared/inventory/domain/inventory_item.dart';
import 'package:zad/shared/inventory/domain/shopping_item.dart';

import '../../support/quiet_household.dart';

ShoppingItem _s(
  String id,
  String name, {
  double price = 0,
  ShoppingPriority priority = ShoppingPriority.medium,
  int qty = 1,
}) => ShoppingItem(
  id: id,
  userId: 'u',
  itemName: name,
  quantity: qty,
  estimatedPrice: price,
  priority: priority,
);

class _List extends QuietShopping {
  new(this.items);

  final List<ShoppingItem> items;

  @override
  ShoppingView build() => ShoppingView(items: items);
}

class _Budget extends BudgetController {
  @override
  BudgetView build() => const BudgetView();
}

class _Ai implements ShoppingAiRemote {
  int calls = 0;

  @override
  Future<List<GrocerySuggestion>> suggest({
    required String userId,
    required String inventory,
    int familySize = 4,
  }) async {
    calls++;
    return const <GrocerySuggestion>[
      (name: 'بيض', quantity: '30', reason: 'مفيش في المخزن'),
    ];
  }

  @override
  Future<double?> estimatePrice({
    required String userId,
    required String itemName,
    String location = '',
    String currency = '',
  }) async => null;
}

void main() {
  test('the basket is unknown until some line has a price', () {
    expect(basketTotal(<ShoppingItem>[_s('1', 'a')]), isNull);
    expect(
      basketTotal(<ShoppingItem>[
        _s('1', 'a', price: 10, qty: 3),
        _s('2', 'b'),
      ]),
      30,
    );
  });

  test('the share text lists the lines and the total', () {
    final text = shoppingShareText(<ShoppingItem>[
      _s('1', 'لبن', price: 20, qty: 2),
    ], 'ج.م');
    expect(text, contains('قائمة تسوق زاد:'));
    expect(text, contains('• لبن × 2'));
    expect(text, contains('الإجمالي: 40 ج.م'));
  });

  test('the share text gives a staple one bullet, with its brands', () {
    final text = shoppingShareText(<ShoppingItem>[
      _s('1', 'ماء إيلان'),
      _s('2', 'مياه داساني'),
      _s('3', 'لبن'),
    ], '');
    expect(text, contains('• مياه (إيلان / داساني)'));
    expect(text, contains('• لبن'));
    expect(text, isNot(contains('ماء إيلان')));
  });

  Future<_Ai> pump(
    WidgetTester tester, {
    List<ShoppingItem>? items,
    List<InventoryItem> pantry = const <InventoryItem>[],
  }) async {
    final ai = _Ai();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shoppingControllerProvider.overrideWith(
            () => _List(
              items ??
                  <ShoppingItem>[
                    _s('1', 'لبن', priority: ShoppingPriority.high),
                    _s('2', 'مناديل', priority: ShoppingPriority.low),
                  ],
            ),
          ),
          pantryControllerProvider.overrideWith(
            () => QuietPantry(PantryView(items: pantry)),
          ),
          budgetControllerProvider.overrideWith(_Budget.new),
          shoppingAiRemoteProvider.overrideWithValue(ai),
          signedInUserIdProvider.overrideWithValue(() => 'u'),
        ],
        child: MaterialApp(
          theme: ZadTheme.light(),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: ShoppingListView()),
          ),
        ),
      ),
    );
    return ai;
  }

  testWidgets('priority chips keep only their lines', (tester) async {
    await pump(tester);
    expect(find.text('لبن'), findsOneWidget);
    expect(find.text('مناديل'), findsOneWidget);

    await tester.tap(find.text('حرج').first);
    await tester.pump();
    expect(find.text('مناديل'), findsNothing);
  });

  testWidgets('no model call on open; the smart fill asks, on a tap', (
    tester,
  ) async {
    final ai = await pump(tester);
    await tester.pump();
    expect(ai.calls, 0);

    await tester.tap(find.text('تعبئة ذكية'));
    await tester.pumpAndSettle();
    expect(ai.calls, 1);
    expect(find.text('قد تحتاج أيضاً'), findsOneWidget);
    expect(find.text('بيض · 30'), findsOneWidget);
  });

  testWidgets('seven lines of water are one line, read against the pantry', (
    tester,
  ) async {
    await pump(
      tester,
      items: <ShoppingItem>[
        _s('1', 'ماء إيلان', qty: 4),
        _s('2', 'مياه داساني جالون', qty: 4),
        _s('3', 'عبوة مياه', qty: 5),
        _s('4', 'كرتونة ماية', qty: 4),
        _s('5', 'بيض', qty: 3),
      ],
      pantry: const <InventoryItem>[
        InventoryItem(
          id: 'p1',
          userId: 'u',
          itemName: 'مياه نستله',
          quantity: 6,
          unit: 'زجاجة',
        ),
      ],
    );
    expect(find.text('مياه · 4 أنواع'), findsOneWidget);
    expect(find.textContaining('في البيت 6 — مش ناقص'), findsOneWidget);
    expect(find.text('ماء إيلان × 4'), findsNothing);
    expect(find.text('بيض × 3'), findsOneWidget);

    // The brands are there, on a tap.
    await tester.tap(find.byTooltip('وريني الأنواع'));
    await tester.pump();
    expect(find.text('ماء إيلان × 4'), findsOneWidget);
    expect(find.text('كرتونة ماية × 4'), findsOneWidget);
  });
}
