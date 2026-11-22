// The four places «من أمازون» sits, drawn at 390x844 with the real Cairo
// font. The pictures are only written with `--dart-define=ZAD_SCREENS=1`:
//
//   flutter test test/screens/amazon_screens_test.dart --dart-define=ZAD_SCREENS=1
//
// → `build/screens/amazon_<name>.png`. Without the define the test still
// renders every screen and checks the chips are there.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:zad/core/data/local/boxes.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/features/inventory/presentation/pantry_view.dart' as pv;
import 'package:zad/features/inventory/presentation/shopping_list_view.dart';
import 'package:zad/features/recipes/application/recipes_controller.dart';
import 'package:zad/features/recipes/domain/recipe.dart';
import 'package:zad/features/recipes/presentation/recipe_detail_screen.dart';
import 'package:zad/features/recipes/presentation/recipes_view.dart' as rv;
import 'package:zad/shared/ads/application/ads_policy.dart';
import 'package:zad/shared/affiliate/data/affiliate_repository.dart';
import 'package:zad/shared/affiliate/presentation/amazon_buy_chip.dart';
import 'package:zad/shared/budget/application/budget_controller.dart';
import 'package:zad/shared/inventory/application/pantry_controller.dart';
import 'package:zad/shared/inventory/application/shopping_controller.dart';
import 'package:zad/shared/inventory/domain/inventory_item.dart';
import 'package:zad/shared/inventory/domain/shopping_item.dart';
import 'package:zad/shared/kids/application/kids_mode_controller.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/modes/application/modes_controller.dart';

import '../support/fonts.dart';
import '../support/quiet_household.dart';

// `bool.fromEnvironment` only reads the word `true`, not `1`.
const String _screens = String.fromEnvironment('ZAD_SCREENS');
const bool _write = _screens == '1' || _screens == 'true';

class _Budget extends BudgetController {
  @override
  BudgetView build() => const BudgetView();
}

class _List extends QuietShopping {
  new(this.items);

  final List<ShoppingItem> items;

  @override
  ShoppingView build() => ShoppingView(items: items);
}

class _Recipes extends RecipesController {
  new(this.initial);

  final RecipesView initial;

  @override
  RecipesView build() => initial;

  @override
  List<String> toBuy(Recipe recipe) => recipe.missing;
}

ShoppingItem _s(String id, String name, ShoppingPriority p, int qty) =>
    ShoppingItem(
      id: id,
      userId: 'u',
      itemName: name,
      quantity: qty,
      priority: p,
    );

InventoryItem _i(String id, String name, double qty, String category) =>
    InventoryItem(
      id: id,
      userId: 'u',
      itemName: name,
      quantity: qty,
      category: category,
      lowStockThreshold: 2,
    );

const Recipe _pasta = Recipe(
  name: 'مكرونة بالصلصة والجبنة',
  prepMinutes: 25,
  costEstimate: 35,
  used: <String>['طماطم', 'بصل'],
  missing: <String>['مكرونة', 'جبنة رومي'],
  steps: <String>[
    'اسلق المكرونة في ماء مملح.',
    'شوّح البصل ثم أضف الطماطم.',
    'قلّب المكرونة مع الصلصة وقدّم بالجبنة.',
  ],
);

void main() {
  setUpAll(() async {
    tz_data.initializeTimeZones();
    await initializeDateFormatting('ar');
  });

  late Directory dir;
  late ZadLocalStore store;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('zad_amazon');
    Hive.init(dir.path);
    store = await ZadLocalStore.open();
  });
  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  final key = GlobalKey();

  Future<void> shoot(
    WidgetTester tester,
    String name,
    Widget body, {
    required int chips,
    List<Override> overrides = const <Override>[],
    Future<void> Function()? after,
  }) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.runAsync(loadZadFonts);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStoreProvider.overrideWithValue(store),
          adsAllowedProvider.overrideWithValue(false),
          nowProvider.overrideWithValue(() => DateTime.utc(2026, 9, 25, 9)),
          accountTimeZoneProvider.overrideWithValue('Africa/Cairo'),
          accountCountryProvider.overrideWithValue('EG'),
          kidsModeActiveProvider.overrideWithValue(false),
          modesControllerProvider.overrideWith(QuietModes.new),
          budgetControllerProvider.overrideWith(_Budget.new),
          signedInUserIdProvider.overrideWithValue(() => 'u'),
          amazonOpenerProvider.overrideWithValue((_) async {}),
          amazonClickLoggerProvider.overrideWithValue((_) async {}),
          ...overrides,
        ],
        child: RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ZadTheme.light(),
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(body: body),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    if (after != null) await after();
    expect(find.byType(AmazonBuyChip), findsNWidgets(chips));
    expect(find.text('من أمازون'), findsNWidgets(chips));
    if (!_write) return;
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = Directory('build/screens')..createSync(recursive: true);
      File('${dir.path}/amazon_$name.png')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  testWidgets('shopping list', (tester) async {
    await shoot(
      tester,
      'shopping',
      const ShoppingListView(),
      chips: 3,
      overrides: [
        shoppingControllerProvider.overrideWith(
          () => _List(<ShoppingItem>[
            _s('1', 'لبن كامل الدسم', ShoppingPriority.high, 2),
            _s('2', 'زيت عباد الشمس', ShoppingPriority.medium, 1),
            _s('3', 'أرز مصري', ShoppingPriority.low, 1),
          ]),
        ),
        pantryControllerProvider.overrideWith(QuietPantry.new),
      ],
    );
  });

  testWidgets('pantry', (tester) async {
    await shoot(
      tester,
      'pantry',
      const pv.PantryView(),
      chips: 2,
      after: () => tester.pump(const Duration(seconds: 1)),
      overrides: [
        shoppingControllerProvider.overrideWith(QuietShopping.new),
        pantryControllerProvider.overrideWith(
          () => QuietPantry(
            PantryView(
              items: <InventoryItem>[
                _i('1', 'لبن كامل الدسم', 0, 'الألبان'),
                _i('2', 'زيت عباد الشمس', 1, 'البقالة'),
                _i('3', 'أرز مصري', 9, 'البقالة'),
              ],
            ),
          ),
        ),
      ],
    );
  });

  final recipesOverrides = <Override>[
    recipesControllerProvider.overrideWith(
      () => _Recipes(
        RecipesView(
          suggestions: ChefSuggestions(
            text: 'عندك طماطم وبصل — جرّب المكرونة بالصلصة.',
            fetchedAt: DateTime.utc(2026, 9, 21),
            pantrySignature: pantrySignature(const <InventoryItem>[]),
            recipes: const <Recipe>[_pasta],
          ),
        ),
      ),
    ),
    pantryControllerProvider.overrideWith(QuietPantry.new),
    shoppingControllerProvider.overrideWith(QuietShopping.new),
  ];

  testWidgets('recipes', (tester) async {
    await shoot(
      tester,
      'recipes',
      const rv.RecipesView(),
      chips: 2,
      overrides: recipesOverrides,
      after: () async {
        await tester.tap(find.text('مكرونة بالصلصة والجبنة'));
        await tester.pump(const Duration(seconds: 1));
      },
    );
  });

  testWidgets('recipe detail', (tester) async {
    await shoot(
      tester,
      'recipe_detail',
      const RecipeDetailDialog(recipe: _pasta),
      chips: 2,
      overrides: recipesOverrides,
      after: () => tester.pump(const Duration(seconds: 1)),
    );
  });
}
