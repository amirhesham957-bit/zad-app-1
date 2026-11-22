// «من أمازون» on each missing ingredient of a recipe — the sheet's «ناقصك»
// list and the full recipe's footer — and only on the missing ones (owner,
// 2026-11-15). A child sees none.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/core/data/local/boxes.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/features/recipes/application/recipes_controller.dart';
import 'package:zad/features/recipes/domain/recipe.dart';
import 'package:zad/features/recipes/presentation/recipe_detail_screen.dart';
import 'package:zad/features/recipes/presentation/recipes_view.dart' as ui;
import 'package:zad/shared/ads/application/ads_policy.dart';
import 'package:zad/shared/affiliate/data/affiliate_repository.dart';
import 'package:zad/shared/affiliate/presentation/amazon_buy_chip.dart';
import 'package:zad/shared/budget/application/budget_controller.dart';
import 'package:zad/shared/inventory/application/pantry_controller.dart';
import 'package:zad/shared/inventory/application/shopping_controller.dart';
import 'package:zad/shared/kids/application/kids_mode_controller.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/modes/application/modes_controller.dart';

import '../../support/quiet_household.dart';

class _Recipes extends RecipesController {
  new(this.initial);

  final RecipesView initial;

  @override
  RecipesView build() => initial;

  @override
  List<String> toBuy(Recipe recipe) => recipe.missing;
}

class _Budget extends BudgetController {
  @override
  BudgetView build() => const BudgetView();
}

const Recipe _pasta = Recipe(
  name: 'مكرونة بالصلصة',
  used: <String>['طماطم'],
  missing: <String>['مكرونة', 'جبنة'],
  steps: <String>['اسلق', 'اعمل الصلصة', 'قدّم'],
);

void main() {
  late Directory dir;
  late ZadLocalStore store;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('zad_amazon_recipes');
    Hive.init(dir.path);
    store = await ZadLocalStore.open();
  });
  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  final opened = <Uri>[];
  final logged = <String>[];

  Future<void> pump(
    WidgetTester tester,
    Widget body, {
    bool kids = false,
    String country = 'EG',
  }) async {
    opened.clear();
    logged.clear();
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStoreProvider.overrideWithValue(store),
          recipesControllerProvider.overrideWith(
            () => _Recipes(
              RecipesView(
                suggestions: ChefSuggestions(
                  text: 'جرّب المكرونة.',
                  fetchedAt: DateTime.utc(2026, 9, 21),
                  pantrySignature: pantrySignature(const []),
                  recipes: const <Recipe>[_pasta],
                ),
              ),
            ),
          ),
          pantryControllerProvider.overrideWith(QuietPantry.new),
          shoppingControllerProvider.overrideWith(QuietShopping.new),
          budgetControllerProvider.overrideWith(_Budget.new),
          modesControllerProvider.overrideWith(QuietModes.new),
          adsAllowedProvider.overrideWithValue(false),
          accountCountryProvider.overrideWithValue(country),
          kidsModeActiveProvider.overrideWithValue(kids),
          amazonOpenerProvider.overrideWithValue(
            (uri) async => opened.add(uri),
          ),
          amazonClickLoggerProvider.overrideWithValue(
            (screen) async => logged.add(screen),
          ),
        ],
        child: MaterialApp(
          theme: ZadTheme.light(),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: body),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('the recipe sheet has a chip per missing ingredient, none for '
      'what the customer has', (tester) async {
    await pump(tester, const ui.RecipesView());
    await tester.tap(find.text('مكرونة بالصلصة'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(AmazonBuyChip), findsNWidgets(2));
    expect(find.text('روابط أمازون · زاد ممكن ياخد عمولة'), findsOneWidget);

    await tester.ensureVisible(find.byType(AmazonBuyChip).last);
    await tester.pump();
    await tester.tap(find.byType(AmazonBuyChip).last);
    await tester.pump();
    expect(opened.single.queryParameters['k'], 'جبنة');
    expect(opened.single.queryParameters['tag'], 'zad04-21');
    expect(logged, <String>['chef_missing']);
  });

  testWidgets('the full recipe footer has one chip per missing ingredient', (
    tester,
  ) async {
    await pump(tester, const RecipeDetailDialog(recipe: _pasta), country: 'SA');
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(AmazonBuyChip), findsNWidgets(2));
    await tester.tap(find.byType(AmazonBuyChip).first);
    await tester.pump();
    expect(opened.single.host, endsWith('amazon.sa'));
    expect(opened.single.queryParameters['k'], 'مكرونة');
    expect(opened.single.queryParameters['tag'], 'zad0b-21');
    expect(logged, <String>['chef_missing']);
  });

  testWidgets('a child sees no chip on the sheet or the full recipe', (
    tester,
  ) async {
    await pump(tester, const RecipeDetailDialog(recipe: _pasta), kids: true);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('من أمازون'), findsNothing);
    expect(find.text('روابط أمازون · زاد ممكن ياخد عمولة'), findsNothing);
  });
}
