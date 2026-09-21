// شيف زاد on the phone. The rule this pins above all: opening the section is
// never a model call — CLAUDE.md forbids one on screen open, and every ask is
// tokens against the customer's daily cap. Asking is a tap; the answer is
// cached; a failed ask keeps the last answer; an opinion is queued once per
// dish; and "add what is missing" never writes a line twice.

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/data/sync/outbox.dart';
import 'package:zad/data/sync/outbox_entry.dart';
import 'package:zad/features/inventory/data/inventory_remote.dart';
import 'package:zad/features/inventory/data/inventory_repository.dart';
import 'package:zad/features/inventory/data/shopping_list_repository.dart';
import 'package:zad/features/recipes/application/recipes_controller.dart';
import 'package:zad/features/recipes/data/recipes_remote.dart';
import 'package:zad/features/recipes/data/recipes_repository.dart';
import 'package:zad/features/recipes/domain/recipe.dart';

class _Chef implements RecipesRemote {
  final List<String> asked = <String>[];
  Map<String, dynamic> answer = <String, dynamic>{
    'ok': true,
    'text': 'جاهزة.',
    'recipes': <Object?>[
      <String, dynamic>{
        'recipe_name': 'مكرونة بالصلصة',
        'available_ingredients_used': <String>['طماطم'],
        'missing_ingredients_to_buy': <String>['مكرونة', 'جبنة'],
        'from_inventory': false,
      },
    ],
  };
  Exception? failWith;
  bool rateStores = true;
  final List<(String, bool)> rated = <(String, bool)>[];

  @override
  Future<Map<String, dynamic>> suggest({
    required String userId,
    required String items,
  }) async {
    asked.add(items);
    if (failWith case final e?) throw e;
    return answer;
  }

  @override
  Future<bool> rate({
    required String userId,
    required String recipeName,
    required bool liked,
  }) async {
    rated.add((recipeName, liked));
    return rateStores;
  }
}

class _Accepting implements InventoryRemote, ShoppingListRemote {
  @override
  Future<List<Map<String, dynamic>>> fetchAll({String? userId}) async =>
      <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>?> upsertReturning(
    Map<String, dynamic> row,
  ) async => row;

  @override
  Future<void> remove(String id) async {}
}

void main() {
  late Directory dir;
  late Box<String> documents;
  late Box<String> pantryBox;
  late Box<String> shoppingBox;
  late Box<String> outboxBox;
  late _Chef chef;
  late Outbox outbox;
  late RecipesRepository recipes;
  late InventoryRepository pantry;
  late ShoppingListRepository shopping;
  var ids = 0;
  var run = 0;
  final now = DateTime.utc(2026, 9, 21, 18);

  setUp(() async {
    run++;
    ids = 0;
    dir = await Directory.systemTemp.createTemp('zad_recipes_test');
    Hive.init(dir.path);
    documents = await Hive.openBox<String>('documents$run');
    pantryBox = await Hive.openBox<String>('pantry$run');
    shoppingBox = await Hive.openBox<String>('shopping$run');
    outboxBox = await Hive.openBox<String>('outbox$run');
    chef = _Chef();
    outbox = Outbox(
      box: outboxBox,
      send: (entry) async => switch (entry.kind) {
        OutboxKind.rateRecipe => await recipes.sendQueuedRating(entry),
        _ => null,
      },
      clock: () => now,
    );
    recipes = RecipesRepository(
      cache: documents,
      remote: chef,
      outbox: () => outbox,
      signedInUserId: () => 'user-1',
      now: () => now,
    );
    pantry = InventoryRepository(
      cache: pantryBox,
      remote: _Accepting(),
      outbox: () => outbox,
      newId: () => 'p${ids++}',
      signedInUserId: () => 'user-1',
    );
    shopping = ShoppingListRepository(
      cache: shoppingBox,
      remote: _Accepting(),
      outbox: () => outbox,
      newId: () => 's${ids++}',
      signedInUserId: () => 'user-1',
    );
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        nowProvider.overrideWithValue(() => now),
        outboxProvider.overrideWithValue(outbox),
        recipesRepositoryProvider.overrideWithValue(recipes),
        inventoryRepositoryProvider.overrideWithValue(pantry),
        shoppingListRepositoryProvider.overrideWithValue(shopping),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Recipe pasta() => recipes.cached()!.recipes.single;

  group('asking', () {
    test('opening the section asks nothing', () async {
      await pantry.add(itemName: 'طماطم', quantity: 3);
      container().read(recipesControllerProvider);
      await Future<void>.delayed(Duration.zero);

      expect(chef.asked, isEmpty);
    });

    test('a tap asks about the pantry, and the answer is kept', () async {
      await pantry.add(itemName: 'طماطم', quantity: 3);
      await pantry.add(itemName: 'لبن', quantity: 0);
      final c = container();

      await c.read(recipesControllerProvider.notifier).ask();

      // What has run out is not offered to the chef as an ingredient.
      expect(chef.asked, <String>['طماطم (3)']);
      expect(
        c.read(recipesControllerProvider).suggestions?.recipes.single.name,
        'مكرونة بالصلصة',
      );
      // And the next opening shows it without asking again.
      final reopened = container().read(recipesControllerProvider);
      expect(reopened.suggestions, isNotNull);
      expect(chef.asked, hasLength(1));
    });

    test('an empty pantry is not a question worth asking', () async {
      await pantry.add(itemName: 'لبن', quantity: 0);
      final c = container();

      await c.read(recipesControllerProvider.notifier).ask();

      expect(chef.asked, isEmpty);
    });

    test('a failed ask keeps the last answer, and says so', () async {
      await pantry.add(itemName: 'طماطم', quantity: 3);
      final c = container();
      final controller = c.read(recipesControllerProvider.notifier);
      await controller.ask();

      chef.failWith = const SocketException('offline');
      await controller.ask();

      final view = c.read(recipesControllerProvider);
      expect(view.suggestions?.recipes, hasLength(1));
      expect(view.error, isA<SocketException>());
      expect(view.isAsking, isFalse);
    });

    test('an answer with nothing in it is a failure, not a blank', () async {
      await pantry.add(itemName: 'طماطم', quantity: 3);
      chef.answer = <String, dynamic>{'ok': false, 'text': null};
      final c = container();

      await c.read(recipesControllerProvider.notifier).ask();

      expect(c.read(recipesControllerProvider).error, isA<ChefUnavailable>());
      expect(recipes.cached(), isNull);
    });
  });

  group('the shopping list', () {
    test('gets what is missing, once', () async {
      await pantry.add(itemName: 'طماطم', quantity: 3);
      final c = container();
      final controller = c.read(recipesControllerProvider.notifier);
      await controller.ask();

      expect(await controller.addMissingToList(pasta()), 2);
      // A second tap adds nothing: the list's unique index would refuse the
      // duplicate, and the refusal would be a dead letter.
      expect(await controller.addMissingToList(pasta()), 0);
      expect(
        shopping.outstanding().map((s) => s.itemName),
        unorderedEquals(<String>['مكرونة', 'جبنة']),
      );
    });

    test('skips what came home since the chef was asked', () async {
      await pantry.add(itemName: 'طماطم', quantity: 3);
      final c = container();
      final controller = c.read(recipesControllerProvider.notifier);
      await controller.ask();
      await pantry.add(itemName: 'جبنة رومي');

      expect(controller.toBuy(pasta()), <String>['مكرونة']);
    });
  });

  group('opinions', () {
    test('are on screen at once and queued once per dish', () async {
      await pantry.add(itemName: 'طماطم', quantity: 3);
      final c = container();
      final controller = c.read(recipesControllerProvider.notifier);
      await controller.ask();

      await controller.rate(pasta(), liked: true);
      await controller.rate(pasta(), liked: false);

      expect(c.read(recipesControllerProvider).ratings, <String, bool>{
        'مكرونة بالصلصة': false,
      });
      final queued = outbox
          .entries()
          .where((e) => e.kind == OutboxKind.rateRecipe)
          .toList();
      // The changed mind replaced the first opinion.
      expect(queued.single.payload['liked'], isFalse);
    });

    test('are keyed in ASCII, the same for the same dish', () {
      final id = RecipesRepository.ratingEntryId('كشري');
      expect(RegExp(r'^[\x20-\x7e]+$').hasMatch(id), isTrue);
      expect(RecipesRepository.ratingEntryId(' كشري '), id);
      expect(RecipesRepository.ratingEntryId('فتة'), isNot(id));
    });

    test('are sent, and one the server did not store stays queued', () async {
      await recipes.rate('كشري', liked: true);
      chef.rateStores = false;
      expect((await outbox.flush()).sent, 0);

      chef.rateStores = true;
      final entry = outbox.entries().single;
      await recipes.sendQueuedRating(entry);
      expect(chef.rated.last, ('كشري', true));
    });
  });
}
