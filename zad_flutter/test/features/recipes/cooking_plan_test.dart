import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/features/recipes/domain/cooking_plan.dart';
import 'package:zad/features/recipes/presentation/cooked_sheet.dart';
import 'package:zad/shared/inventory/application/pantry_controller.dart';
import 'package:zad/shared/inventory/domain/inventory_item.dart';

InventoryItem _item(String id, String name, double qty, [String? unit]) =>
    InventoryItem(
      id: id,
      userId: 'u',
      itemName: name,
      quantity: qty,
      unit: unit,
    );

class _Pantry extends PantryController {
  _Pantry(this.items);

  final List<InventoryItem> items;
  final List<(String, num)> adjusted = <(String, num)>[];

  @override
  PantryView build() => PantryView(items: items);

  @override
  Future<void> refresh({bool force = false}) async {}

  @override
  Future<void> adjust(String id, num delta) async => adjusted.add((id, delta));
}

void main() {
  final pantry = <InventoryItem>[
    _item('rice', 'الرز', 2, 'كيلو'),
    _item('eggs', 'بيض', 10, 'حبة'),
    _item('onion', 'بصل', 1),
    _item('gone', 'طماطم', 0),
    _item('milk', 'حليب', 500, 'مل'),
    _item('oil', 'زيت ذرة', 1, 'لتر'),
  ];

  group('which rows a recipe used', () {
    test('a row matches when every word of its name is in the line', () {
      expect(ingredientUses('٢ كوب رز مصري', 'الرز'), isTrue);
      expect(ingredientUses('ملعقة زيت', 'زيت ذرة'), isFalse);
      expect(ingredientUses('ربع كوب زيت الذرة', 'زيت ذرة'), isTrue);
      expect(ingredientUses('ملح', 'بصل'), isFalse);
      expect(ingredientUses('٣ بيضات', 'بيض'), isTrue);
      expect(ingredientUses('بصلة', 'بصل'), isTrue);
      expect(ingredientUses('رزمة بقدونس', 'رز'), isFalse);
    });

    test('each row once, in the recipe order, only what is in stock', () {
      final plan = cookingPlan(<String>[
        '٣ بيضات',
        'بيض للدهن',
        '٢ كوب رز',
        'طماطم مفرومة',
        'بصلة',
      ], pantry);
      expect(plan.map((l) => l.item.id), <String>['eggs', 'rice', 'onion']);
    });

    test('the amount follows the unit and never passes what is there', () {
      double portion(String id, String line) =>
          cookPortion(pantry.firstWhere((i) => i.id == id), line);
      expect(portion('rice', '٢ كوب رز'), 0.25);
      expect(portion('milk', 'كوب حليب'), 250);
      expect(portion('eggs', '٣ بيضات'), 3);
      expect(portion('eggs', 'بيض'), 1);
      expect(portion('onion', '٤ بصل'), 1, reason: 'only one onion at home');
    });
  });

  testWidgets('the sheet takes off what is ticked, at the amounts shown', (
    tester,
  ) async {
    final fake = _Pantry(pantry);
    var taken = -1;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pantryControllerProvider.overrideWith(() => fake)],
        child: MaterialApp(
          theme: ZadTheme.light(),
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: TextButton(
                onPressed: () async => taken = await showCookedSheet(
                  context,
                  ref,
                  <String>['٣ بيضات', '٢ كوب رز', 'بصل'],
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('بيض'), findsOneWidget);
    // One more egg, and the onion left out.
    await tester.tap(find.byTooltip('أكتر').first);
    await tester.tap(find.byType(Checkbox).at(2));
    await tester.pump();
    await tester.tap(find.text('اخصم 2'));
    await tester.pumpAndSettle();

    expect(fake.adjusted, <(String, num)>[('eggs', -4), ('rice', -0.25)]);
    expect(taken, 2);
  });

  testWidgets('nothing at home: it says so and offers no button', (
    tester,
  ) async {
    final fake = _Pantry(pantry);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pantryControllerProvider.overrideWith(() => fake)],
        child: MaterialApp(
          theme: ZadTheme.light(),
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    showCookedSheet(context, ref, <String>['كمون', 'ملح']),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('مالقيتش مكونات الوصفة دي في بيتك.'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });
}
