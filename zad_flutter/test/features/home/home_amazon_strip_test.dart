// «تسوق من أمازون» on home: a card per shortage side by side, each ordered
// with a tap in the account's own Amazon store; «إضافة» and «اقتراح» when
// nothing is short.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/features/home/presentation/home_amazon_strip.dart';
import 'package:zad/shared/affiliate/domain/affiliate.dart';
import 'package:zad/shared/inventory/application/pantry_controller.dart';
import 'package:zad/shared/inventory/domain/inventory_item.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/navigation/zad_screens.dart';

import '../../support/quiet_household.dart';

void main() {
  test("«اقتراح» searches the account's own store", () {
    expect(
      amazonSuggestUrl('بيض', 'EG'),
      startsWith('https://www.amazon.eg/s?k='),
    );
    // Every country but Egypt shops amazon.sa until the other stores are
    // set up (owner, 2026-10-10).
    expect(
      amazonSuggestUrl('بيض', 'ae'),
      startsWith('https://www.amazon.sa/s?k='),
    );
    expect(
      amazonSuggestUrl('بيض', 'TR'),
      startsWith('https://www.amazon.sa/s?k='),
    );
    expect(
      amazonSuggestUrl('بيض', 'SA'),
      startsWith('https://www.amazon.sa/s?k='),
    );
    expect(
      amazonSuggestUrl('بيض', null),
      startsWith('https://www.amazon.sa/s?k='),
    );
    expect(
      amazonSuggestUrl('', 'EG'),
      startsWith('https://www.amazon.eg/deals?tag='),
    );
    expect(amazonSuggestUrl('بيض', 'EG'), contains('&tag='));
    // Each store with its own tag: one store's tag earns nothing on another.
    expect(amazonSuggestUrl('بيض', 'EG'), endsWith('&tag=zad04-21'));
    expect(amazonSuggestUrl('بيض', 'SA'), endsWith('&tag=zad0b-21'));
    expect(amazonSuggestUrl('بيض', 'AE'), endsWith('&tag=zad0b-21'));
  });

  Future<void> pump(
    WidgetTester tester, {
    List<InventoryItem> pantry = const <InventoryItem>[],
  }) => tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...quietHouseholdOverrides.skip(1),
        pantryControllerProvider.overrideWith(
          () => QuietPantry(PantryView(items: pantry)),
        ),
        accountCountryProvider.overrideWithValue('EG'),
      ],
      child: MaterialApp(
        theme: ZadTheme.light(),
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: HomeAmazonStrip()),
        ),
      ),
    ),
  );

  testWidgets('nothing short: two buttons and no card', (tester) async {
    var opened = 0;
    ZadScreens.showAddShoppingSheet = (_) async => opened++;
    await pump(tester);

    expect(find.text('🛍️ تسوق من أمازون'), findsOneWidget);
    expect(find.text('ضيف اللي ناقصك، أو شوف عروض النهارده'), findsOneWidget);
    expect(find.text('إضافة'), findsOneWidget);
    expect(find.text('اقتراح'), findsOneWidget);
    expect(find.text('🛒 اطلبه'), findsNothing);
    expect(find.byType(Image), findsNothing);

    await tester.tap(find.text('إضافة'));
    await tester.pump();
    expect(opened, 1);
  });

  testWidgets('one card per shortage, most urgent first, side by side', (
    tester,
  ) async {
    await pump(
      tester,
      pantry: const <InventoryItem>[
        InventoryItem(
          id: 'r',
          userId: 'u',
          itemName: 'رز',
          quantity: 1,
          lowStockThreshold: 2,
        ),
        InventoryItem(id: 's', userId: 'u', itemName: 'سكر', quantity: 5),
        InventoryItem(
          id: 'e',
          userId: 'u',
          itemName: 'بيض',
          quantity: 0,
          lowStockThreshold: 2,
        ),
      ],
    );
    expect(find.text('ناقصك 2 حاجات — اطلب كل واحدة بضغطة'), findsOneWidget);
    expect(find.text('🛒 اطلبه'), findsNWidgets(2));
    expect(find.text('سكر'), findsNothing);
    expect(find.text('خلص'), findsOneWidget);
    expect(find.text('قرب يخلص'), findsOneWidget);
    // Side by side, the run-out first (right of it in RTL).
    final egg = tester.getCenter(find.text('بيض'));
    final rice = tester.getCenter(find.text('رز'));
    expect(egg.dy, rice.dy);
    expect(egg.dx, greaterThan(rice.dx));
    expect(find.text('العروض'), findsOneWidget);
    expect(
      tester
          .getSize(find.widgetWithText(FilledButton, '🛒 اطلبه').first)
          .height,
      greaterThanOrEqualTo(44),
    );
  });

  testWidgets('one shortage is named', (tester) async {
    await pump(
      tester,
      pantry: const <InventoryItem>[
        InventoryItem(id: 'r', userId: 'u', itemName: 'رز', quantity: 5),
        InventoryItem(
          id: 'e',
          userId: 'u',
          itemName: 'بيض',
          quantity: 0,
          lowStockThreshold: 2,
        ),
      ],
    );
    expect(find.text('ناقصك بيض — اطلبه من أمازون'), findsOneWidget);
    expect(find.text('🛒 اطلبه'), findsOneWidget);
  });

  testWidgets('a two-line name at a raised text size fits its card', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pump(
      tester,
      pantry: const <InventoryItem>[
        InventoryItem(
          id: 'm',
          userId: 'u',
          itemName: 'حليب جهينة كامل الدسم لتر ونص',
          quantity: 0,
        ),
        InventoryItem(id: 'e', userId: 'u', itemName: 'بيض', quantity: 0),
      ],
    );
    expect(tester.takeException(), isNull);
    expect(find.text('🛒 اطلبه'), findsNWidgets(2));
  });
}
