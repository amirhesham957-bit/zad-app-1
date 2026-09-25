// The pantry screen: Kotlin's category rules, tabs, search, the expiring
// section and the edit sheet.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/design/zad_theme.dart';
import 'package:zad/features/inventory/application/pantry_controller.dart'
    as pantry;
import 'package:zad/features/inventory/application/shopping_controller.dart';
import 'package:zad/features/inventory/domain/inventory_item.dart';
import 'package:zad/features/inventory/domain/pantry_categories.dart';
import 'package:zad/features/inventory/domain/shortage.dart';
import 'package:zad/features/inventory/presentation/pantry_view.dart';

import '../../support/quiet_household.dart';

final DateTime _now = DateTime.utc(2026, 9, 25, 9);

InventoryItem _i(
  String id,
  String name, {
  int qty = 5,
  String? category,
  DateTime? expiry,
}) => InventoryItem(
  id: id,
  userId: 'u',
  itemName: name,
  quantity: qty,
  category: category,
  expiryDate: expiry,
);

void main() {
  setUpAll(() => initializeDateFormatting('ar'));

  group('categories', () {
    test('a stored category is read through the word rules', () {
      expect(pantryCategoryOf('خضروات', 'x'), 'الخضار');
      expect(pantryCategoryOf('الألبان', 'x'), 'الألبان');
    });

    test('with no useful category, the name decides', () {
      expect(pantryCategoryOf(null, 'كرتونة مياه'), 'المشروبات');
      expect(pantryCategoryOf('عام', 'صابون'), 'العناية');
      expect(pantryCategoryOf(null, 'حاجة'), 'أخرى');
    });

    test("a known name has its own picture, else its category's", () {
      expect(pantryEmojiOf('بيض بلدي', null), '🥚');
      expect(pantryEmojiOf('خيار', null), '🥦');
    });
  });

  group('the screen', () {
    final milk = _i('1', 'لبن', qty: 0, category: 'الألبان');
    final rice = _i('2', 'أرز', category: 'البقالة');
    final yogurt = _i(
      '3',
      'زبادي',
      category: 'الألبان',
      expiry: DateTime.utc(2026, 9, 27),
    );

    Future<void> pump(WidgetTester tester, {QuietShopping? shopping}) =>
        tester.pumpWidget(
          ProviderScope(
            overrides: [
              nowProvider.overrideWithValue(() => _now),
              pantry.pantryControllerProvider.overrideWith(
                () => QuietPantry(
                  pantry.PantryView(
                    items: <InventoryItem>[milk, rice, yogurt],
                    shortages: <Shortage>[
                      Shortage(item: milk, reason: ShortageReason.outOfStock),
                    ],
                  ),
                ),
              ),
              shoppingControllerProvider.overrideWith(
                () => shopping ?? QuietShopping(),
              ),
            ],
            child: MaterialApp(
              theme: ZadTheme.light(),
              home: const Directionality(
                textDirection: TextDirection.rtl,
                child: Scaffold(body: PantryView()),
              ),
            ),
          ),
        );

    testWidgets('a category chip keeps only its rows', (tester) async {
      await pump(tester);
      expect(find.text('أرز'), findsOneWidget);

      await tester.tap(find.text('الألبان'));
      await tester.pump();
      expect(find.text('أرز'), findsNothing);
      expect(find.text('لبن'), findsOneWidget);
    });

    testWidgets('search narrows the list, and says so when empty', (
      tester,
    ) async {
      await pump(tester);
      await tester.enterText(find.byType(TextField), 'أرز');
      await tester.pump();
      expect(find.text('لبن'), findsNothing);

      await tester.enterText(find.byType(TextField), 'قهوة');
      await tester.pump();
      expect(find.text('لا توجد نتائج'), findsOneWidget);
    });

    testWidgets('what expires soon is gathered, with a recipe ask', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('ينتهي قريباً'), findsOneWidget);
      expect(find.text('زبادي · باقي 2 يوم'), findsOneWidget);
      expect(find.text('اقتراح وصفة'), findsOneWidget);
    });

    testWidgets('the shortages tab puts a row on the list', (tester) async {
      final shopping = QuietShopping();
      await pump(tester, shopping: shopping);
      await tester.tap(find.text('النواقص (1)'));
      await tester.pump();

      await tester.tap(find.text('نزّلها في التسوق'));
      await tester.pump();
      expect(shopping.added, <String>['لبن']);
    });

    testWidgets('a tap opens the edit sheet on that row', (tester) async {
      await pump(tester);
      await tester.tap(find.text('أرز'));
      await tester.pumpAndSettle();
      expect(find.text('تعديل الصنف'), findsOneWidget);
      expect(find.text('حذف'), findsOneWidget);
    });
  });
}
