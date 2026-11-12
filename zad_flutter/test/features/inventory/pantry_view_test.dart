// The pantry screen: Kotlin's category rules, tabs, search, the expiring
// section and the edit sheet.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/features/inventory/domain/pantry_categories.dart';
import 'package:zad/features/inventory/presentation/pantry_view.dart';
import 'package:zad/shared/inventory/application/pantry_controller.dart'
    as pantry;
import 'package:zad/shared/inventory/application/shopping_controller.dart';
import 'package:zad/shared/inventory/domain/inventory_item.dart';
import 'package:zad/shared/inventory/domain/shortage.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/navigation/destinations.dart';

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
  quantity: qty.toDouble(),
  category: category,
  expiryDate: expiry,
);

void main() {
  setUpAll(() async {
    tz_data.initializeTimeZones();
    await initializeDateFormatting('ar');
  });

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

  testWidgets('brands of water are one card with the house total; a tap '
      'opens them', (tester) async {
    final items = <InventoryItem>[
      _i('w1', 'ماء إيلان', qty: 1, category: 'المشروبات'),
      _i('w2', 'ماء صافي', qty: 3, category: 'المشروبات'),
      _i('w3', 'مياه نستله', qty: 2, category: 'المشروبات'),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nowProvider.overrideWithValue(() => _now),
          accountTimeZoneProvider.overrideWithValue('Africa/Cairo'),
          pantry.pantryControllerProvider.overrideWith(
            () => QuietPantry(pantry.PantryView(items: items)),
          ),
          shoppingControllerProvider.overrideWith(QuietShopping.new),
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
    await tester.pump();
    expect(find.text('مياه'), findsOneWidget);
    expect(find.text('6'), findsOneWidget, reason: 'the house total');
    expect(find.text('ماء صافي'), findsNothing, reason: 'closed by default');
    await tester.tap(find.text('مياه'));
    await tester.pump();
    expect(find.text('ماء صافي'), findsOneWidget);
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

    Future<void> pump(
      WidgetTester tester, {
      QuietShopping? shopping,
      List<HouseholdSection>? opened,
    }) => tester.pumpWidget(
      ProviderScope(
        overrides: [
          nowProvider.overrideWithValue(() => _now),
          accountTimeZoneProvider.overrideWithValue('Africa/Cairo'),
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
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: NotificationListener<OpenHouseholdSection>(
              onNotification: (n) {
                opened?.add(n.section);
                return true;
              },
              child: const Scaffold(body: PantryView()),
            ),
          ),
        ),
      ),
    );

    testWidgets('a category chip keeps only its rows', (tester) async {
      await pump(tester);
      expect(find.text('أرز'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilterChip, 'الألبان'));
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

    testWidgets("Kotlin's banners: shortages and «ينتهي قريباً»", (
      tester,
    ) async {
      await pump(tester);
      // One line of two spans since the strip stopped overflowing.
      expect(
        find.textContaining('نواقص المخزون (1)', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('ينتهي قريباً'), findsOneWidget);
      expect(find.text('باقي 2 يوم'), findsOneWidget);
      expect(find.text('اقتراح وصفة'), findsOneWidget);
    });

    testWidgets('the shortages are on the shopping list: the banner puts '
        'them there and opens «نواقص وتسوق» (the owner, 2026-11-04)', (
      tester,
    ) async {
      final shopping = QuietShopping();
      final opened = <HouseholdSection>[];
      await pump(tester, shopping: shopping, opened: opened);
      expect(find.text('النواقص (2)'), findsNothing, reason: 'no second tab');
      await tester.tap(find.text('نزّلها في التسوق'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(shopping.added, <String>['لبن']);
      expect(opened, <HouseholdSection>[HouseholdSection.shopping]);
    });

    testWidgets('the pencil opens «تعديل الصنف» on that row', (tester) async {
      await pump(tester);
      await tester.tap(find.byTooltip('تعديل الصنف').first);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('تعديل الصنف'), findsWidgets);
      expect(find.widgetWithText(FilledButton, 'حفظ'), findsOneWidget);
    });
  });

  group('an occasional item (ZAD_PLAN ٣.١٠)', () {
    final milk = _i('1', 'لبن', qty: 0, category: 'الألبان');
    const herring = InventoryItem(
      id: '2',
      userId: 'u',
      itemName: 'رنجة',
      quantity: 0,
      category: 'اللحوم',
      occasionalByHistory: true,
    );

    Future<_EditingPantry> pump(WidgetTester tester) async {
      final pantryCtl = _EditingPantry(
        pantry.PantryView(
          items: <InventoryItem>[milk, herring],
          // The controller's own rule: an occasional item at zero is not short.
          shortages: shortagesIn(<InventoryItem>[
            milk,
            herring,
          ], today: DateTime.utc(_now.year, _now.month, _now.day)),
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nowProvider.overrideWithValue(() => _now),
            accountTimeZoneProvider.overrideWithValue('Africa/Cairo'),
            pantry.pantryControllerProvider.overrideWith(() => pantryCtl),
            shoppingControllerProvider.overrideWith(QuietShopping.new),
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
      await tester.pump();
      return pantryCtl;
    }

    testWidgets('at zero it is not one of the shortages', (tester) async {
      await pump(tester);
      expect(
        find.textContaining('نواقص المخزون (1)', findRichText: true),
        findsOneWidget,
        reason: 'the milk only',
      );
      expect(find.text('منخفض'), findsOneWidget, reason: 'on the milk only');
    });

    testWidgets('the edit dialog says so, and only a change is written', (
      tester,
    ) async {
      final pantryCtl = await pump(tester);

      // The milk: a staple until the customer flips it.
      await tester.tap(find.byTooltip('تعديل الصنف').first);
      await tester.pump(const Duration(milliseconds: 500));
      final toggle = find.widgetWithText(SwitchListTile, 'بشتريها على فترات');
      expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
      await tester.tap(toggle);
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'حفظ'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(pantryCtl.modes, <String?>[restockOccasional]);

      // The herring: already occasional by its history; saving untouched
      // writes no word, so the history keeps deciding.
      await tester.tap(find.byTooltip('تعديل الصنف').last);
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        tester
            .widget<SwitchListTile>(
              find.widgetWithText(SwitchListTile, 'بشتريها على فترات'),
            )
            .value,
        isTrue,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'حفظ'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(pantryCtl.modes, <String?>[restockOccasional, null]);
    });
  });

  testWidgets('an edit saves half a kilo as half (ZAD_PLAN ٣.٨)', (
    tester,
  ) async {
    const rice = InventoryItem(
      id: 'r',
      userId: 'u',
      itemName: 'رز',
      quantity: 0.5,
      category: 'البقالة',
    );
    final pantryCtl = _EditingPantry(
      const pantry.PantryView(items: <InventoryItem>[rice]),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nowProvider.overrideWithValue(() => _now),
          accountTimeZoneProvider.overrideWithValue('Africa/Cairo'),
          pantry.pantryControllerProvider.overrideWith(() => pantryCtl),
          shoppingControllerProvider.overrideWith(QuietShopping.new),
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
    await tester.pump();
    await tester.tap(find.byTooltip('تعديل الصنف').first);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.widgetWithText(FilledButton, 'حفظ'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(pantryCtl.quantities, <double>[0.5]);
  });

  group('the expiry field (2026-11-12: 0 of 40 rows had a date)', () {
    // 21:30 UTC is already the 13th in Riyadh, still the 12th on a UTC
    // device: the chips must count from the account's day.
    final late = DateTime.utc(2026, 11, 12, 21, 30);

    Future<_AddingPantry> openAdd(WidgetTester tester) async {
      final pantryCtl = _AddingPantry();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nowProvider.overrideWithValue(() => late),
            accountTimeZoneProvider.overrideWithValue('Asia/Riyadh'),
            pantry.pantryControllerProvider.overrideWith(() => pantryCtl),
            shoppingControllerProvider.overrideWith(QuietShopping.new),
          ],
          child: MaterialApp(
            theme: ZadTheme.light(),
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showAddPantrySheet(context),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return pantryCtl;
    }

    Future<void> tapVisible(WidgetTester tester, Finder f) async {
      await tester.ensureVisible(f);
      await tester.pumpAndSettle();
      await tester.tap(f);
      await tester.pumpAndSettle();
    }

    testWidgets('«أسبوع» stores today + 7 in the account zone', (tester) async {
      final pantryCtl = await openAdd(tester);
      expect(find.text('2025-12-31'), findsNothing, reason: 'the stale hint');
      await tester.enterText(find.byType(TextField).first, 'صابون');
      await tapVisible(tester, find.widgetWithText(ChoiceChip, 'أسبوع'));
      await tapVisible(tester, find.widgetWithText(FilledButton, 'حفظ'));
      expect(pantryCtl.added.single.expiry, DateTime.utc(2026, 11, 20));
    });

    testWidgets('left empty, the guess is shown as an estimate and saved', (
      tester,
    ) async {
      final pantryCtl = await openAdd(tester);
      await tester.enterText(find.byType(TextField).first, 'لبن');
      await tester.pump();
      expect(find.textContaining('تقديري:'), findsOneWidget);
      await tapVisible(tester, find.widgetWithText(FilledButton, 'حفظ'));
      expect(
        pantryCtl.added.single.expiry,
        DateTime.utc(2026, 11, 20),
        reason: 'dairy keeps about a week',
      );
    });

    testWidgets('× clears a pick; cleaning things get no guess', (
      tester,
    ) async {
      final pantryCtl = await openAdd(tester);
      await tester.enterText(find.byType(TextField).first, 'صابون');
      await tester.pump();
      expect(find.textContaining('تقديري:'), findsNothing);
      await tapVisible(tester, find.widgetWithText(ChoiceChip, 'شهر'));
      expect(find.byTooltip('امسح التاريخ'), findsOneWidget);
      await tapVisible(tester, find.byTooltip('امسح التاريخ'));
      expect(find.byTooltip('امسح التاريخ'), findsNothing);
      await tapVisible(tester, find.widgetWithText(FilledButton, 'حفظ'));
      expect(pantryCtl.added.single.expiry, isNull);
    });

    testWidgets('the edit dialog writes a new date, a clear, or nothing', (
      tester,
    ) async {
      final yogurt = _i(
        'y',
        'زبادي',
        category: 'الألبان',
        expiry: DateTime.utc(2026, 11, 15),
      );
      final rice = _i('r', 'أرز', category: 'البقالة');
      final written = <Object?>[];
      Future<void> edit(InventoryItem item) async {
        final pantryCtl = _EditingPantry(
          pantry.PantryView(items: <InventoryItem>[item]),
          written,
        );
        await tester.pumpWidget(
          ProviderScope(
            key: UniqueKey(),
            overrides: [
              nowProvider.overrideWithValue(() => late),
              accountTimeZoneProvider.overrideWithValue('Asia/Riyadh'),
              pantry.pantryControllerProvider.overrideWith(() => pantryCtl),
              shoppingControllerProvider.overrideWith(QuietShopping.new),
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
        await tester.pump();
        await tester.tap(find.byTooltip('تعديل الصنف').first);
        await tester.pumpAndSettle();
      }

      // The rice: «شهر» → the account's today + 30.
      await edit(rice);
      await tapVisible(tester, find.widgetWithText(ChoiceChip, 'شهر'));
      await tapVisible(tester, find.widgetWithText(FilledButton, 'حفظ'));
      // The yoghurt: × clears its date.
      await edit(yogurt);
      await tapVisible(tester, find.byTooltip('امسح التاريخ'));
      await tapVisible(tester, find.widgetWithText(FilledButton, 'حفظ'));
      // Untouched: nothing is written.
      await edit(yogurt);
      await tapVisible(tester, find.widgetWithText(FilledButton, 'حفظ'));
      expect(written, <Object?>[DateTime.utc(2026, 12, 13), 'cleared', null]);
    });
  });
}

/// A pantry that records the word each [edit] carried.
class _EditingPantry extends QuietPantry {
  new(super.view, [List<Object?>? expiries])
    : expiries = expiries ?? <Object?>[];

  final List<String?> modes = <String?>[];
  final List<double> quantities = <double>[];

  /// The expiry each edit wrote: a date, null (untouched) or 'cleared'.
  final List<Object?> expiries;

  @override
  Future<void> edit(
    InventoryItem item, {
    required String itemName,
    required double quantity,
    String? unit,
    String? restockMode,
    DateTime? expiryDate,
    bool clearExpiry = false,
  }) async {
    modes.add(restockMode);
    quantities.add(quantity);
    expiries.add(clearExpiry ? 'cleared' : expiryDate);
  }
}

/// A pantry that records what each [add] carried.
class _AddingPantry extends QuietPantry {
  new();

  final List<({String name, String? category, DateTime? expiry})> added =
      <({String name, String? category, DateTime? expiry})>[];

  @override
  Future<void> add({
    required String itemName,
    double quantity = 1,
    String? unit,
    String? category,
    double? lowStockThreshold,
    DateTime? expiryDate,
  }) async =>
      added.add((name: itemName, category: category, expiry: expiryDate));
}
