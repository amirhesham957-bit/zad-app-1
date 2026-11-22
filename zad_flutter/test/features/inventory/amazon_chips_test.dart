// «من أمازون» on what is short: an unticked shopping line and a low or empty
// pantry item (owner, 2026-11-15). The chip opens a tagged search in the
// account's own store, records the click by screen, and a child never sees it.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:zad/core/data/local/boxes.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/features/inventory/presentation/pantry_view.dart' as ui;
import 'package:zad/features/inventory/presentation/shopping_list_view.dart';
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

import '../../support/quiet_household.dart';

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

ShoppingItem _s(String id, String name, {bool bought = false}) =>
    ShoppingItem(id: id, userId: 'u', itemName: name, isPurchased: bought);

InventoryItem _i(String id, String name, double qty) => InventoryItem(
  id: id,
  userId: 'u',
  itemName: name,
  quantity: qty,
  category: 'الألبان',
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

  final opened = <Uri>[];
  final logged = <String>[];

  Future<void> pump(
    WidgetTester tester,
    Widget body, {
    List<ShoppingItem> shopping = const <ShoppingItem>[],
    List<InventoryItem> pantry = const <InventoryItem>[],
    String country = 'EG',
    bool kids = false,
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
          adsAllowedProvider.overrideWithValue(false),
          nowProvider.overrideWithValue(() => DateTime.utc(2026, 9, 25, 9)),
          accountTimeZoneProvider.overrideWithValue('Africa/Cairo'),
          accountCountryProvider.overrideWithValue(country),
          kidsModeActiveProvider.overrideWithValue(kids),
          modesControllerProvider.overrideWith(QuietModes.new),
          shoppingControllerProvider.overrideWith(() => _List(shopping)),
          pantryControllerProvider.overrideWith(
            () => QuietPantry(PantryView(items: pantry)),
          ),
          budgetControllerProvider.overrideWith(_Budget.new),
          signedInUserIdProvider.overrideWithValue(() => 'u'),
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

  group('shopping list', () {
    testWidgets('an unticked line has the chip, a ticked one does not, and '
        'the disclosure shows once', (tester) async {
      await pump(
        tester,
        const ShoppingListView(),
        shopping: <ShoppingItem>[
          _s('1', 'لبن'),
          _s('2', 'مناديل'),
          _s('3', 'سكر', bought: true),
        ],
      );
      expect(find.byType(AmazonBuyChip), findsNWidgets(2));
      expect(find.text('روابط أمازون · زاد ممكن ياخد عمولة'), findsOneWidget);
    });

    testWidgets('a tap searches the item in amazon.eg with the Egypt tag and '
        'records shopping_row', (tester) async {
      await pump(
        tester,
        const ShoppingListView(),
        shopping: <ShoppingItem>[_s('1', 'لبن')],
      );
      await tester.tap(find.byType(AmazonBuyChip));
      await tester.pump();
      expect(opened, hasLength(1));
      expect(opened.single.host, 'www.amazon.eg');
      expect(opened.single.queryParameters['k'], 'لبن');
      expect(opened.single.queryParameters['tag'], 'zad04-21');
      expect(logged, <String>['shopping_row']);
    });

    testWidgets('a Saudi account is sent to amazon.sa with its own tag', (
      tester,
    ) async {
      await pump(
        tester,
        const ShoppingListView(),
        shopping: <ShoppingItem>[_s('1', 'لبن')],
        country: 'SA',
      );
      await tester.tap(find.byType(AmazonBuyChip));
      await tester.pump();
      expect(opened.single.host, endsWith('amazon.sa'));
      expect(opened.single.queryParameters['tag'], 'zad0b-21');
      expect(logged, <String>['shopping_row']);
    });

    testWidgets('a child sees no chip and no disclosure', (tester) async {
      await pump(
        tester,
        const ShoppingListView(),
        shopping: <ShoppingItem>[_s('1', 'لبن')],
        kids: true,
      );
      expect(find.byType(AmazonBuyChip), findsOneWidget);
      expect(find.text('من أمازون'), findsNothing);
      expect(find.text('روابط أمازون · زاد ممكن ياخد عمولة'), findsNothing);
    });
  });

  group('pantry', () {
    testWidgets('a low item has the chip and a full one does not', (
      tester,
    ) async {
      await pump(
        tester,
        const ui.PantryView(),
        pantry: <InventoryItem>[_i('1', 'لبن', 0), _i('2', 'أرز', 9)],
      );
      expect(find.text('من أمازون'), findsOneWidget);
      expect(find.text('روابط أمازون · زاد ممكن ياخد عمولة'), findsOneWidget);
      await tester.tap(find.byType(AmazonBuyChip));
      await tester.pump();
      expect(opened.single.queryParameters['k'], 'لبن');
      expect(logged, <String>['pantry_low']);
    });

    testWidgets('a pantry with nothing low has no chip and no disclosure', (
      tester,
    ) async {
      await pump(
        tester,
        const ui.PantryView(),
        pantry: <InventoryItem>[_i('2', 'أرز', 9)],
      );
      expect(find.text('من أمازون'), findsNothing);
      expect(find.text('روابط أمازون · زاد ممكن ياخد عمولة'), findsNothing);
    });

    testWidgets('a child sees none', (tester) async {
      await pump(
        tester,
        const ui.PantryView(),
        pantry: <InventoryItem>[_i('1', 'لبن', 0)],
        kids: true,
      );
      expect(find.text('من أمازون'), findsNothing);
    });
  });
}
