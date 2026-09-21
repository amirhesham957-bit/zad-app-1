// What the recipes section says: before the first ask, whether there is
// anything to cook from; after it, the chef's line and the two groups, and a
// note when the pantry has changed since. The sheet shows one recipe and
// offers to put what is missing on the list.
//
// Controllers are recording fakes: a Hive write inside a widget test never
// completes under the fake clock.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/design/zad_theme.dart';
import 'package:zad/features/budget/application/budget_controller.dart';
import 'package:zad/features/inventory/application/pantry_controller.dart';
import 'package:zad/features/inventory/application/shopping_controller.dart';
import 'package:zad/features/inventory/domain/inventory_item.dart';
import 'package:zad/features/recipes/application/recipes_controller.dart';
import 'package:zad/features/recipes/domain/recipe.dart';
import 'package:zad/features/recipes/presentation/recipes_view.dart' as ui;

class _Recipes extends RecipesController {
  new(this.initial);

  final RecipesView initial;
  final List<String> calls = <String>[];

  @override
  RecipesView build() => initial;

  @override
  Future<void> ask() async => calls.add('ask');

  @override
  Future<void> rate(Recipe recipe, {required bool liked}) async =>
      calls.add('rate:${recipe.name}:$liked');

  @override
  List<String> toBuy(Recipe recipe) => recipe.missing;

  @override
  Future<int> addMissingToList(Recipe recipe) async {
    calls.add('add:${recipe.name}');
    return recipe.missing.length;
  }
}

class _Pantry extends PantryController {
  new(this.items);

  final List<InventoryItem> items;

  @override
  PantryView build() => PantryView(items: items);

  @override
  Future<void> refresh({bool force = false}) async {}
}

class _Shopping extends ShoppingController {
  @override
  ShoppingView build() => const ShoppingView();

  @override
  Future<void> refresh() async {}
}

class _Budget extends BudgetController {
  @override
  BudgetView build() => const BudgetView();
}

InventoryItem _stock(String name, int qty) =>
    InventoryItem(id: name, userId: 'u', itemName: name, quantity: qty);

final List<InventoryItem> _kitchen = <InventoryItem>[
  _stock('بيض', 6),
  _stock('طماطم', 3),
];

ChefSuggestions _answer({String? signature}) => ChefSuggestions(
  text: 'عندك بيض وطماطم — ابدأ بالشكشوكة.',
  fetchedAt: DateTime.utc(2026, 9, 21),
  pantrySignature: signature ?? pantrySignature(_kitchen),
  recipes: const <Recipe>[
    Recipe(
      name: 'شكشوكة',
      prepMinutes: 15,
      costEstimate: 20,
      used: <String>['بيض', 'طماطم'],
      steps: <String>['قطّع الطماطم', 'شوّحها', 'ضيف البيض', 'قدّم'],
      fromInventory: true,
    ),
    Recipe(
      name: 'مكرونة بالصلصة',
      missing: <String>['مكرونة', 'جبنة'],
      steps: <String>['اسلق', 'اعمل الصلصة', 'قلّب', 'قدّم'],
    ),
  ],
);

void main() {
  late _Recipes recipes;

  Future<void> pump(
    WidgetTester tester, {
    required List<InventoryItem> pantry,
    ChefSuggestions? suggestions,
  }) async {
    recipes = _Recipes(RecipesView(suggestions: suggestions));
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recipesControllerProvider.overrideWith(() => recipes),
          pantryControllerProvider.overrideWith(() => _Pantry(pantry)),
          shoppingControllerProvider.overrideWith(_Shopping.new),
          budgetControllerProvider.overrideWith(_Budget.new),
        ],
        child: MaterialApp(
          theme: ZadTheme.light(),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: ui.RecipesView()),
          ),
        ),
      ),
    );
  }

  FilledButton askButton(WidgetTester tester) => tester.widget<FilledButton>(
    find.ancestor(
      of: find.byIcon(ZadIcons.chef),
      matching: find.byWidgetPredicate((w) => w is FilledButton),
    ),
  );

  testWidgets('before the first ask, the chef waits for a tap', (
    tester,
  ) async {
    await pump(tester, pantry: _kitchen);

    expect(find.text('شيف زاد جاهزة'), findsOneWidget);
    expect(recipes.calls, isEmpty);

    await tester.tap(find.text('وصفات من مخزني'));
    await tester.pump();
    expect(recipes.calls, <String>['ask']);
  });

  testWidgets('an empty pantry says so, and there is nothing to ask', (
    tester,
  ) async {
    await pump(tester, pantry: <InventoryItem>[_stock('لبن', 0)]);

    expect(find.text('المخزن فاضي'), findsOneWidget);
    expect(askButton(tester).onPressed, isNull);
  });

  testWidgets('an answer is shown in its two groups, with the chef line', (
    tester,
  ) async {
    await pump(tester, pantry: _kitchen, suggestions: _answer());

    expect(find.text('عندك بيض وطماطم — ابدأ بالشكشوكة.'), findsOneWidget);
    expect(find.text('من مخزونك'), findsOneWidget);
    expect(find.text('وجبات تانية'), findsOneWidget);
    expect(find.text('مكتملة'), findsOneWidget);
    expect(find.text('ناقصك 2'), findsOneWidget);
    expect(find.text('15 دقيقة · ~20'), findsOneWidget);
    expect(find.text('اقتراحات جديدة'), findsOneWidget);
    // Current: no note that the pantry has moved on.
    expect(find.textContaining('مخزنك اتغيّر'), findsNothing);
  });

  testWidgets('an answer about a different pantry says the pantry changed', (
    tester,
  ) async {
    await pump(
      tester,
      pantry: _kitchen,
      suggestions: _answer(signature: 'بيض:2'),
    );

    expect(find.textContaining('مخزنك اتغيّر'), findsOneWidget);
  });

  testWidgets('a recipe opens with its steps, and offers the missing', (
    tester,
  ) async {
    await pump(tester, pantry: _kitchen, suggestions: _answer());

    await tester.tap(find.text('مكرونة بالصلصة'));
    await tester.pumpAndSettle();

    expect(find.text('الطريقة'), findsOneWidget);
    expect(find.text('اعمل الصلصة'), findsOneWidget);
    await tester.tap(find.text('ضيف الناقص لقايمة التسوق (2)'));
    await tester.pumpAndSettle();
    expect(recipes.calls, contains('add:مكرونة بالصلصة'));
    expect(find.text('ضفت 2 أصناف لقايمة التسوق.'), findsOneWidget);

    await tester.tap(find.byTooltip('مش لذوقي'));
    await tester.pump();
    expect(recipes.calls.last, 'rate:مكرونة بالصلصة:false');
  });

  testWidgets('a complete recipe has nothing to add', (tester) async {
    await pump(tester, pantry: _kitchen, suggestions: _answer());

    await tester.tap(find.text('شكشوكة'));
    await tester.pumpAndSettle();

    expect(find.textContaining('ضيف الناقص'), findsNothing);
    expect(find.text('من عندك'), findsOneWidget);
  });
}
