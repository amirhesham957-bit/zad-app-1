// «بيتي» tidied (ZAD_PLAN ١٠.١ slice 5): one add button on the right, no
// second camera button, «خلص» on the card, delete in the edit dialog, and a
// starter card on an empty pantry.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/features/inventory/domain/starter_essentials.dart';
import 'package:zad/features/inventory/presentation/pantry_view.dart';
import 'package:zad/shared/inventory/application/pantry_controller.dart'
    as pantry;
import 'package:zad/shared/inventory/application/shopping_controller.dart';
import 'package:zad/shared/inventory/domain/inventory_item.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';

import '../../support/quiet_household.dart';

final DateTime _now = DateTime.utc(2026, 11, 12, 9);

class _Recording extends pantry.PantryController {
  new(this.items);

  final List<InventoryItem> items;
  final List<String> added = <String>[];
  final List<(String, num)> adjusted = <(String, num)>[];
  final List<String> removed = <String>[];

  @override
  pantry.PantryView build() => pantry.PantryView(items: items);

  @override
  Future<void> refresh({bool force = false}) async {}

  @override
  Future<void> add({
    required String itemName,
    double quantity = 1,
    String? unit,
    String? category,
    double? lowStockThreshold,
    DateTime? expiryDate,
  }) async => added.add(itemName);

  @override
  Future<void> adjust(String id, num delta) async => adjusted.add((id, delta));

  @override
  Future<void> remove(String id) async => removed.add(id);
}

void main() {
  setUpAll(() async {
    tz_data.initializeTimeZones();
    await initializeDateFormatting('ar');
  });

  Future<_Recording> pump(
    WidgetTester tester,
    List<InventoryItem> items, {
    String country = 'EG',
  }) async {
    final controller = _Recording(items);
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nowProvider.overrideWithValue(() => _now),
          accountTimeZoneProvider.overrideWithValue('Africa/Cairo'),
          accountCountryProvider.overrideWithValue(country),
          pantry.pantryControllerProvider.overrideWith(() => controller),
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
    return controller;
  }

  const rice = InventoryItem(
    id: 'r',
    userId: 'u',
    itemName: 'رز',
    quantity: 2,
    unit: 'كيلو',
    category: 'البقالة',
    lowStockThreshold: 0.5,
  );

  testWidgets('one add button, on the right, and no second camera', (
    tester,
  ) async {
    await pump(tester, <InventoryItem>[rice]);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byIcon(Icons.document_scanner), findsNothing);
    final fab = tester.getCenter(find.byType(FloatingActionButton));
    expect(fab.dx, greaterThan(tester.view.physicalSize.width / 2.75 / 2));
  });

  testWidgets('«خلص» takes the row to zero as one use, and undoes', (
    tester,
  ) async {
    final c = await pump(tester, <InventoryItem>[rice]);
    await tester.tap(find.byKey(const ValueKey<String>('pantry-finish-r')));
    await tester.pumpAndSettle();
    expect(c.adjusted, <(String, num)>[('r', -2)]);
    expect(find.text('رز خلص'), findsOneWidget);
    await tester.tap(find.text('تراجع'));
    await tester.pump();
    expect(c.adjusted.last, ('r', 2));
  });

  testWidgets('the steppers are 44dp to tap', (tester) async {
    await pump(tester, <InventoryItem>[rice]);
    final minus = find.byTooltip('استهلاك واحدة');
    expect(tester.getSize(minus).height, greaterThanOrEqualTo(44));
    expect(tester.getSize(minus).width, greaterThanOrEqualTo(44));
  });

  testWidgets('a tap on the card edits it, and delete is there', (
    tester,
  ) async {
    final c = await pump(tester, <InventoryItem>[rice]);
    await tester.tap(find.text('رز'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('pantry-edit-delete')));
    await tester.pumpAndSettle();
    expect(c.removed, <String>['r']);
  });

  testWidgets('an empty pantry offers its basics, all ticked, in one tap', (
    tester,
  ) async {
    final c = await pump(tester, const <InventoryItem>[]);
    final basics = starterEssentials('EG');
    expect(find.text('ضيف ${basics.length}'), findsOneWidget);
    // Leave the cheese out.
    await tester.tap(find.byKey(const ValueKey<String>('starter-جبنة')));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('starter-add')),
    );
    await tester.tap(find.byKey(const ValueKey<String>('starter-add')));
    await tester.pumpAndSettle();
    expect(c.added, <String>[
      for (final b in basics)
        if (b.name != 'جبنة') b.name,
    ]);
  });

  testWidgets('a Saudi pantry starts from the Gulf basics', (tester) async {
    await pump(tester, const <InventoryItem>[], country: 'SA');
    expect(find.byKey(const ValueKey<String>('starter-حليب')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('starter-خبز')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('starter-لبن')), findsNothing);
  });
}
