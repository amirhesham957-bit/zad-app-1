// «العروض المتاحة لنواقصك» asks for one name per stock: brands of one
// staple are one shortage, and none while together they are above the
// threshold.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/features/debts/presentation/debts_tab.dart';
import 'package:zad/shared/inventory/application/pantry_controller.dart';
import 'package:zad/shared/inventory/domain/inventory_item.dart';

import '../../support/quiet_household.dart';

InventoryItem _item(String name, int qty) => InventoryItem(
  id: name,
  userId: 'u',
  itemName: name,
  quantity: qty,
  lowStockThreshold: 2,
);

void main() {
  // Built outside the tests: its auth client starts a timer the fake clock
  // would otherwise count as pending.
  Map<String, dynamic>? body;
  final client = SupabaseClient(
    'https://example.supabase.co',
    'anon',
    httpClient: MockClient((request) async {
      body = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        '{"deals":[],"ok":true}',
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    }),
  );

  Future<List<Object?>> itemsSent(
    WidgetTester tester,
    List<InventoryItem> pantry,
  ) async {
    body = null;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supabaseClientProvider.overrideWithValue(client),
          pantryControllerProvider.overrideWith(
            () => QuietPantry(PantryView(items: pantry)),
          ),
        ],
        child: MaterialApp(
          theme: ZadTheme.light(),
          home: const Scaffold(
            body: SingleChildScrollView(child: LiveDealsCard()),
          ),
        ),
      ),
    );
    await tester.tap(find.text('تحديث من النت 🔄'));
    // The functions client awaits real I/O-shaped futures.
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(body?['action'], 'fetch_live_deals');
    final payload = body!['payload'] as Map<String, dynamic>;
    return payload['items'] as List<Object?>;
  }

  testWidgets('five brands of water are one shortage', (tester) async {
    final items = await itemsSent(tester, <InventoryItem>[
      _item('مياه نوفا', 0),
      _item('مياه أكوافينا', 1),
      _item('ماء العين', 0),
      _item('رز', 5),
    ]);
    expect(items, <String>['مياه']);
    expect(find.text('لا توجد نتائج بحث محددة متوفرة حالياً'), findsOneWidget);
  });

  testWidgets('no shortage while the brands together are enough', (
    tester,
  ) async {
    final items = await itemsSent(tester, <InventoryItem>[
      _item('مياه نوفا', 0),
      _item('مياه أكوافينا', 10),
      _item('سكر', 1),
    ]);
    expect(items, <String>['سكر']);
  });
}
