/// The recipes section's state.
///
/// Opening it never asks the chef. It shows the last answer from the cache
/// and says whether the pantry has changed since; asking is a tap. Kotlin
/// fires `meal_suggestions` on every pantry change, which is the kind of
/// unrequested model call CLAUDE.md forbids — each one is tokens against a
/// daily cap the customer can hit.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/features/inventory/application/shopping_controller.dart';
import 'package:zad/features/inventory/domain/inventory_item.dart';
import 'package:zad/features/recipes/domain/recipe.dart';

/// What the recipes section draws.
class RecipesView {
  /// Creates a view.
  const new({
    this.suggestions,
    this.ratings = const <String, bool>{},
    this.isAsking = false,
    this.error,
  });

  /// The last answer, or null before the first ask.
  final ChefSuggestions? suggestions;

  /// The customer's opinions, by recipe name.
  final Map<String, bool> ratings;

  /// Whether an ask is in flight.
  final bool isAsking;

  /// Why the last ask failed.
  final Object? error;

  /// A copy with the given fields replaced.
  RecipesView copyWith({
    ChefSuggestions? suggestions,
    Map<String, bool>? ratings,
    bool? isAsking,
    Object? error,
    bool clearError = false,
  }) => RecipesView(
    suggestions: suggestions ?? this.suggestions,
    ratings: ratings ?? this.ratings,
    isAsking: isAsking ?? this.isAsking,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Holds شيف زاد.
class RecipesController extends Notifier<RecipesView> {
  @override
  RecipesView build() {
    final repository = ref.read(recipesRepositoryProvider);
    return RecipesView(
      suggestions: repository.cached(),
      ratings: repository.ratings(),
    );
  }

  /// Asks the chef about the pantry as it is now. A tap, never a build.
  Future<void> ask() async {
    if (!ref.mounted || state.isAsking) return;
    final pantry = _pantry();
    // Nothing to cook from is not a question worth a model call; the section
    // says so and points at the pantry instead.
    if (stockedPantry(pantry).isEmpty) return;

    state = state.copyWith(isAsking: true, clearError: true);
    try {
      final answer = await ref.read(recipesRepositoryProvider).suggest(pantry);
      if (!ref.mounted) return;
      state = state.copyWith(suggestions: answer, isAsking: false);
    } on Object catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(isAsking: false, error: error);
    }
  }

  /// Likes or dislikes [recipe]. The next suggestions hear about it.
  Future<void> rate(Recipe recipe, {required bool liked}) async {
    final repository = ref.read(recipesRepositoryProvider);
    await repository.rate(recipe.name, liked: liked);
    if (ref.mounted) state = state.copyWith(ratings: repository.ratings());
  }

  /// What adding [recipe]'s missing ingredients would put on the list now.
  List<String> toBuy(Recipe recipe) => missingToBuy(
    recipe,
    shopping: ref.read(shoppingListRepositoryProvider).cached(),
    pantry: _pantry(),
  );

  /// Puts [recipe]'s missing ingredients on the shopping list — the ones not
  /// already there and not in the pantry. Returns how many went on.
  Future<int> addMissingToList(Recipe recipe) async {
    final names = toBuy(recipe);
    final shopping = ref.read(shoppingListRepositoryProvider);
    final now = ref.read(nowProvider)();
    for (final name in names) {
      await shopping.add(itemName: name, at: now);
    }
    if (names.isNotEmpty && ref.mounted) {
      ref.invalidate(shoppingControllerProvider);
    }
    return names.length;
  }

  List<InventoryItem> _pantry() =>
      ref.read(inventoryRepositoryProvider).cached();
}

/// شيف زاد.
final recipesControllerProvider =
    NotifierProvider<RecipesController, RecipesView>(RecipesController.new);
