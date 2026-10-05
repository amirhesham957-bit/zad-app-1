// «تسوق من أمازون» is back on home in its empty shape: «إضافة» and «اقتراح»,
// no product cards, and «اقتراح» opens the account's own Amazon store.

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
    expect(
      amazonSuggestUrl('بيض', 'ae'),
      startsWith('https://www.amazon.ae/s?k='),
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

  testWidgets('two buttons and no product', (tester) async {
    var opened = 0;
    ZadScreens.showAddShoppingSheet = (_) async => opened++;
    await pump(tester);

    expect(find.text('🛍️ تسوق من أمازون'), findsOneWidget);
    expect(find.text('إضافة'), findsOneWidget);
    expect(find.text('اقتراح'), findsOneWidget);
    expect(find.textContaining('اشتري'), findsNothing);
    expect(find.byType(Image), findsNothing);

    await tester.tap(find.text('إضافة'));
    await tester.pump();
    expect(opened, 1);
  });

  testWidgets('it names the first real need', (tester) async {
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
    expect(find.text('ناقصك بيض — دوّر عليه في أمازون'), findsOneWidget);
  });
}
