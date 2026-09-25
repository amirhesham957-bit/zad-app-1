// Reading شيف زاد's answer, and the arithmetic over it that needs no network:
// a recipe missing a field does not cost the others, the pantry is told the
// same way every time so the server's cache can answer, and the "add what is
// missing" button never puts on the list what is already there or at home.

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/features/inventory/domain/inventory_item.dart';
import 'package:zad/features/inventory/domain/shopping_item.dart';
import 'package:zad/features/recipes/domain/recipe.dart';

InventoryItem _stock(String name, int qty) =>
    InventoryItem(id: name, userId: 'u', itemName: name, quantity: qty);

ShoppingItem _line(String name, {bool bought = false}) =>
    ShoppingItem(id: name, userId: 'u', itemName: name, isPurchased: bought);

Map<String, dynamic> _answer() => <String, dynamic>{
  'ok': true,
  'text': 'عندك بيض وطماطم — شكشوكة في ربع ساعة.',
  'recipes': <Object?>[
    <String, dynamic>{
      'recipe_name': 'شكشوكة',
      'prep_time_minutes': 15,
      'cost_estimate': 20,
      'available_ingredients_used': <String>['بيض', 'طماطم'],
      'missing_ingredients_to_buy': <String>[],
      'cooking_instructions': <String>['قطّع', 'شوّح', 'ضيف البيض', 'قدّم'],
      'from_inventory': true,
      'image_thumb_url': 'https://images.example/s.jpg',
    },
    <String, dynamic>{
      'recipe_name': 'مكرونة بالصلصة',
      'missing_ingredients_to_buy': <String>['مكرونة', 'صلصة'],
      'from_inventory': false,
    },
    // No name: nothing to show, dropped without costing the others.
    <String, dynamic>{'recipe_name': '  ', 'cooking_instructions': <String>[]},
    'not a recipe',
  ],
};

void main() {
  final at = DateTime.utc(2026, 9, 21, 18);

  group('reading the answer', () {
    test('the server shape, and a broken entry costs only itself', () {
      final answer = ChefSuggestions.fromResponse(
        _answer(),
        fetchedAt: at,
        pantrySignature: 'sig',
      );

      expect(answer.recipes.map((r) => r.name), <String>[
        'شكشوكة',
        'مكرونة بالصلصة',
      ]);
      final first = answer.recipes.first;
      expect((first.prepMinutes, first.costEstimate), (15, 20.0));
      expect(first.steps, hasLength(4));
      expect(first.thumbUrl, 'https://images.example/s.jpg');
      expect(answer.fromPantry.single.name, 'شكشوكة');
      expect(answer.needShopping.single.missing, <String>['مكرونة', 'صلصة']);
    });

    test('without the flag, a recipe is complete when nothing is missing', () {
      final recipe = Recipe.fromJson(<String, dynamic>{
        'recipe_name': 'سلطة',
        'missing_ingredients_to_buy': <String>[],
      })!;
      expect(recipe.fromInventory, isTrue);
    });

    test('a line and no recipes is still an answer; nothing at all is not', () {
      // "Your pantry is not enough on its own" is the chef answering.
      final lineOnly = ChefSuggestions.fromResponse(
        <String, dynamic>{'ok': true, 'text': 'المخزن لوحده مش كفاية.'},
        fetchedAt: at,
        pantrySignature: '',
      );
      final failed = ChefSuggestions.fromResponse(
        <String, dynamic>{'ok': false, 'text': null, 'recipes': <Object?>[]},
        fetchedAt: at,
        pantrySignature: '',
      );
      expect((lineOnly.isUsable, failed.isUsable), (true, false));
    });

    test('only https images are shown', () {
      final recipe = Recipe.fromJson(<String, dynamic>{
        'recipe_name': 'x',
        'image_url': 'http://insecure.example/a.jpg',
      })!;
      expect(recipe.imageUrl, isNull);
    });

    test('survives the cache unchanged', () {
      final answer = ChefSuggestions.fromResponse(
        _answer(),
        fetchedAt: at,
        pantrySignature: 'sig',
      );
      final back = ChefSuggestions.fromCache(answer.toJson());

      expect(back.toJson(), answer.toJson());
      expect(back.fetchedAt, at);
    });
  });

  group('telling the chef about the pantry', () {
    test('what is actually there, the same way every time', () {
      final pantry = <InventoryItem>[
        _stock('طماطم', 3),
        _stock('بيض', 6),
        _stock('لبن', 0),
      ];
      // Sorted, and without what has run out: an unchanged pantry is the same
      // text, which is what the server's cache is keyed on.
      expect(pantryForChef(pantry), 'بيض (6), طماطم (3)');
      expect(pantryForChef(pantry.reversed.toList()), pantryForChef(pantry));
    });

    test('the signature moves with a count, not with an order', () {
      final a = <InventoryItem>[_stock('بيض', 6), _stock('طماطم', 3)];
      final b = <InventoryItem>[_stock('طماطم', 3), _stock('بيض', 6)];
      final c = <InventoryItem>[_stock('بيض', 5), _stock('طماطم', 3)];

      expect(pantrySignature(a), pantrySignature(b));
      expect(pantrySignature(a), isNot(pantrySignature(c)));
    });
  });

  group('what goes on the list', () {
    final recipe = Recipe.fromJson(<String, dynamic>{
      'recipe_name': 'مكرونة بالصلصة',
      'missing_ingredients_to_buy': <String>[
        'مكرونة',
        'صلصة طماطم',
        'جبنة',
        'المكرونة',
        ' ',
      ],
    })!;

    test('not what is already open on it, nor what is at home', () {
      final toBuy = missingToBuy(
        recipe,
        shopping: <ShoppingItem>[_line('صلصة طماطم')],
        pantry: <InventoryItem>[_stock('جبنة', 1)],
      );
      // "المكرونة" is the same thing twice; the blank line is nothing.
      expect(toBuy, <String>['مكرونة']);
    });

    test('a line already bought is not on the list any more', () {
      final toBuy = missingToBuy(
        recipe,
        shopping: <ShoppingItem>[_line('صلصة طماطم', bought: true)],
        pantry: const <InventoryItem>[],
      );
      expect(toBuy, <String>['مكرونة', 'صلصة طماطم', 'جبنة']);
    });

    test('something that ran out at home still has to be bought', () {
      final toBuy = missingToBuy(
        recipe,
        shopping: const <ShoppingItem>[],
        pantry: <InventoryItem>[_stock('جبنة', 0)],
      );
      expect(toBuy, contains('جبنة'));
    });
  });
}
