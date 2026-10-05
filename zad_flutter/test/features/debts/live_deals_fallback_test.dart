// A failed live search keeps the last deals found on the card, marked as such,
// instead of replacing them with «تعذّر البحث» (2026-10-05: the grounded search
// was out of quota and the card had nothing else to show).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/features/debts/presentation/debts_tab.dart';
import 'package:zad/shared/budget/application/budget_controller.dart';
import 'package:zad/shared/inventory/application/pantry_controller.dart';
import 'package:zad/shared/inventory/domain/inventory_item.dart';

import '../../support/quiet_household.dart';

class _Budget extends BudgetController {
  @override
  BudgetView build() => const BudgetView();
}

void main() {
  final answers = <String>[];
  final client = SupabaseClient(
    'https://example.supabase.co',
    'anon',
    httpClient: MockClient(
      (request) async => http.Response(
        answers.removeAt(0),
        200,
        headers: <String, String>{'content-type': 'application/json'},
      ),
    ),
  );

  Future<void> search(WidgetTester tester) async {
    await tester.tap(find.text('تحديث من النت 🔄'));
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
  }

  Future<void> open(WidgetTester tester) => tester.pumpWidget(
    ProviderScope(
      overrides: [
        supabaseClientProvider.overrideWithValue(client),
        budgetControllerProvider.overrideWith(_Budget.new),
        pantryControllerProvider.overrideWith(
          () => QuietPantry(
            const PantryView(
              items: <InventoryItem>[
                InventoryItem(
                  id: 'e',
                  userId: 'u',
                  itemName: 'بيض',
                  quantity: 0,
                  lowStockThreshold: 2,
                ),
              ],
            ),
          ),
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

  testWidgets('a failed search keeps the deals already found', (tester) async {
    answers
      ..clear()
      ..addAll(<String>[
        '{"ok":true,"deals":[{"item":"بيض","store":"كارفور","price":150}]}',
        '{"ok":false,"deals":[]}',
      ]);
    await open(tester);
    await search(tester);
    expect(find.textContaining('كارفور'), findsOneWidget);

    await search(tester);
    expect(find.textContaining('كارفور'), findsOneWidget);
    expect(find.textContaining('البحث مشغول دلوقتي'), findsOneWidget);
    expect(
      find.text('تعذّر البحث الآن — جرّب تحدّث تاني بعد شوية'),
      findsNothing,
    );
  });

  testWidgets('with nothing found before, the failure says so', (tester) async {
    answers
      ..clear()
      ..add('{"ok":false,"deals":[]}');
    await open(tester);
    await search(tester);
    expect(
      find.text('تعذّر البحث الآن — جرّب تحدّث تاني بعد شوية'),
      findsOneWidget,
    );
    expect(find.textContaining('ما ردّش في الوقت'), findsNothing);
  });
}
