/// شيف زاد's suggestions: what `zad-core-intelligence`'s `meal_suggestions`
/// answers, and the arithmetic over it that needs no network.
///
/// The server does the cooking — the model, the customer's past likes and
/// dislikes, family size, the budget left, broke mode, the season — and
/// answers with structured recipes, each flagged `from_inventory` when it
/// needs nothing bought. This file reads that answer, and decides what is
/// worth putting on the shopping list; nothing here asks a model anything.
///
/// Every field is optional on the way in. The answer comes from a model, and
/// one recipe missing a field must not cost the other five — the rule Kotlin's
/// `ZadAiRepository.suggestMeals` settled on after the strict version lost
/// whole answers.
library;

import 'package:zad/features/inventory/domain/inventory_item.dart';
import 'package:zad/features/inventory/domain/receipt_intake.dart';
import 'package:zad/features/inventory/domain/shopping_item.dart';

/// One recipe.
class Recipe {
  /// Creates a recipe.
  const new({
    required this.name,
    this.imageUrl,
    this.thumbUrl,
    this.prepMinutes = 0,
    this.costEstimate = 0,
    this.used = const <String>[],
    this.missing = const <String>[],
    this.steps = const <String>[],
    this.fromInventory = false,
  });

  /// Reads one recipe, or null when it has no name to show.
  static Recipe? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final name = (raw['recipe_name'] as Object?)?.toString().trim() ?? '';
    if (name.isEmpty) return null;

    final missing = _strings(raw['missing_ingredients_to_buy']);
    return Recipe(
      name: name,
      imageUrl: _url(raw['image_url']),
      thumbUrl: _url(raw['image_thumb_url']),
      prepMinutes: _number(raw['prep_time_minutes']).round(),
      costEstimate: _number(raw['cost_estimate']),
      used: _strings(raw['available_ingredients_used']),
      missing: missing,
      steps: _strings(raw['cooking_instructions']),
      // The server's flag when there is one; an older answer without it is
      // judged the same way the server judges it.
      fromInventory: switch (raw['from_inventory']) {
        final bool b => b,
        _ => missing.isEmpty,
      },
    );
  }

  /// The dish.
  final String name;

  /// A photograph, when the server found one.
  final String? imageUrl;

  /// A small one, for a list.
  final String? thumbUrl;

  /// Minutes to make it; 0 when not said.
  final int prepMinutes;

  /// What it costs, in the account's currency; 0 when not said.
  final double costEstimate;

  /// What it takes from the pantry.
  final List<String> used;

  /// What has to be bought — the list the "add to shopping" button works from.
  final List<String> missing;

  /// How to make it, in order.
  final List<String> steps;

  /// Whether it can be made from the pantry alone.
  final bool fromInventory;

  /// The recipe as the cache keeps it — the server's field names, so one
  /// reader serves both.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'recipe_name': name,
    'image_url': ?imageUrl,
    'image_thumb_url': ?thumbUrl,
    'prep_time_minutes': prepMinutes,
    'cost_estimate': costEstimate,
    'available_ingredients_used': used,
    'missing_ingredients_to_buy': missing,
    'cooking_instructions': steps,
    'from_inventory': fromInventory,
  };
}

/// One answer from شيف زاد, and the pantry it was asked about.
class ChefSuggestions {
  /// Creates an answer.
  const new({
    required this.recipes,
    required this.fetchedAt,
    required this.pantrySignature,
    this.text,
  });

  /// Reads the server's answer.
  ///
  /// `ok` is false when the model failed; `text` is then null and `recipes`
  /// empty, and there is nothing to show. That is the caller's to treat as a
  /// failure, not a reading — see [isUsable].
  factory fromResponse(
    Map<String, dynamic> json, {
    required DateTime fetchedAt,
    required String pantrySignature,
  }) => ChefSuggestions(
    text: _text(json['text']),
    recipes: <Recipe>[
      if (json['recipes'] case final List<Object?> list)
        for (final raw in list) ?Recipe.fromJson(raw),
    ],
    fetchedAt: fetchedAt,
    pantrySignature: pantrySignature,
  );

  /// Reads one back out of the cache.
  factory fromCache(Map<String, dynamic> json) => ChefSuggestions.fromResponse(
    json,
    fetchedAt: DateTime.parse(json['fetched_at'] as String).toUtc(),
    pantrySignature: json['pantry_signature'] as String? ?? '',
  );

  /// A line or two from the chef — or why the pantry is not enough.
  final String? text;

  /// The recipes, "from your pantry" first as the server sorts them.
  final List<Recipe> recipes;

  /// When it was asked.
  final DateTime fetchedAt;

  /// [pantrySignature] of the pantry it was asked about.
  final String pantrySignature;

  /// Whether there is anything to show. An answer with a line and no recipes
  /// is still one — "your pantry is not enough on its own" is an answer.
  bool get isUsable => recipes.isNotEmpty || (text?.isNotEmpty ?? false);

  /// Recipes that need nothing bought.
  List<Recipe> get fromPantry => recipes.where((r) => r.fromInventory).toList();

  /// Recipes that need a few things.
  List<Recipe> get needShopping =>
      recipes.where((r) => !r.fromInventory).toList();

  /// The answer as the cache keeps it.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'text': text,
    'recipes': <Map<String, dynamic>>[for (final r in recipes) r.toJson()],
    'fetched_at': fetchedAt.toUtc().toIso8601String(),
    'pantry_signature': pantrySignature,
  };
}

/// What is actually in the kitchen: rows with something left, by name.
List<InventoryItem> stockedPantry(List<InventoryItem> pantry) =>
    pantry.where((i) => i.quantity > 0).toList()
      ..sort((a, b) => a.itemName.compareTo(b.itemName));

/// The pantry as the chef is told it: `name (qty)`, comma-separated — the
/// shape Kotlin sends. Sorted, so an unchanged pantry is the same text and
/// the server's cache answers it.
String pantryForChef(List<InventoryItem> pantry) => stockedPantry(
  pantry,
).map((i) => '${i.itemName} (${i.quantity})').join(', ');

/// A fingerprint of the pantry, to tell whether suggestions were asked about
/// the kitchen as it is now.
String pantrySignature(List<InventoryItem> pantry) => stockedPantry(
  pantry,
).map((i) => '${normalizeItemName(i.itemName)}:${i.quantity}').join('|');

/// The missing ingredients worth adding to the list: not already on it, and
/// not in the pantry since the chef was asked.
///
/// The list's partial unique index refuses a second open line of the same
/// name, and the outbox dead-letters the refusal, so a duplicate here is not
/// harmless — it is a write the customer is told went in and then did not.
List<String> missingToBuy(
  Recipe recipe, {
  required List<ShoppingItem> shopping,
  required List<InventoryItem> pantry,
}) {
  final open = shopping.where((s) => s.isOutstanding).map((s) => s.itemName);
  final stocked = stockedPantry(pantry).map((i) => i.itemName);
  final out = <String>[];
  for (final raw in recipe.missing) {
    final name = raw.trim();
    if (name.isEmpty) continue;
    if (open.any((s) => itemNamesMatch(s, name))) continue;
    if (stocked.any((p) => itemNamesMatch(p, name))) continue;
    if (out.any((o) => itemNamesMatch(o, name))) continue;
    out.add(name);
  }
  return out;
}

List<String> _strings(Object? raw) => <String>[
  if (raw is List)
    for (final v in raw)
      if (v != null && v.toString().trim().isNotEmpty) v.toString().trim(),
];

double _number(Object? raw) => switch (raw) {
  final num n when n.isFinite && n > 0 => n.toDouble(),
  final String s => double.tryParse(s) ?? 0,
  _ => 0,
};

String? _url(Object? raw) => switch (raw) {
  final String s when s.startsWith('https://') => s,
  _ => null,
};

String? _text(Object? raw) => switch (raw) {
  final String s when s.trim().isNotEmpty => s.trim(),
  _ => null,
};
