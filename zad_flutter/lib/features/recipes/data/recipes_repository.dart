/// شيف زاد's last answer and the customer's opinions, kept on the phone.
///
/// The answer is cached so the section opens on the last suggestions instead
/// of asking again: every ask is a model call, and CLAUDE.md forbids one on
/// screen open. The customer asks; the phone remembers.
///
/// Opinions are writes and go through the outbox like any other, one entry per
/// recipe so a changed mind replaces the queued one. The server upserts on
/// `(user_id, recipe_name)`, so a replay is harmless.
library;

import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:zad/data/sync/outbox.dart';
import 'package:zad/data/sync/outbox_entry.dart';
import 'package:zad/features/inventory/domain/inventory_item.dart';
import 'package:zad/features/recipes/data/recipes_remote.dart';
import 'package:zad/features/recipes/domain/recipe.dart';

/// The chef answered, but with nothing — the model failed upstream.
class ChefUnavailable implements Exception {
  /// Creates the failure.
  const new();

  @override
  String toString() => 'meal_suggestions answered ok:false with nothing';
}

/// Holds the chef's answers and the customer's opinions.
class RecipesRepository {
  /// Creates a repository.
  const new({
    required Box<String> cache,
    required RecipesRemote remote,
    required Outbox Function() outbox,
    required String? Function() signedInUserId,
    required DateTime Function() now,
  }) : _cache = cache,
       _remote = remote,
       _outbox = outbox,
       _signedInUserId = signedInUserId,
       _now = now;

  final Box<String> _cache;
  final RecipesRemote _remote;
  final Outbox Function() _outbox;
  final String? Function() _signedInUserId;
  final DateTime Function() _now;

  static const String _suggestionsKey = 'chef_suggestions';
  static const String _ratingsKey = 'recipe_ratings';

  /// The last answer, or null.
  ChefSuggestions? cached() {
    final raw = _cache.get(_suggestionsKey);
    if (raw == null) return null;
    try {
      return ChefSuggestions.fromCache(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } on Object {
      return null;
    }
  }

  /// Asks the chef about [pantry], and keeps the answer.
  ///
  /// Throws on transport failure, and [ChefUnavailable] when the server
  /// answered with nothing. Neither replaces the cached answer: yesterday's
  /// suggestions are more use than an error where they were.
  Future<ChefSuggestions> suggest(List<InventoryItem> pantry) async {
    final response = await _remote.suggest(
      userId: _requireUserId(),
      items: pantryForChef(pantry),
    );
    final answer = ChefSuggestions.fromResponse(
      response,
      fetchedAt: _now().toUtc(),
      pantrySignature: pantrySignature(pantry),
    );
    if (!answer.isUsable) throw const ChefUnavailable();

    await _cache.put(_suggestionsKey, jsonEncode(answer.toJson()));
    return answer;
  }

  /// What the customer thought of each recipe they rated, by name.
  Map<String, bool> ratings() {
    final raw = _cache.get(_ratingsKey);
    if (raw == null) return <String, bool>{};
    try {
      return Map<String, bool>.from(jsonDecode(raw) as Map);
    } on Object {
      return <String, bool>{};
    }
  }

  /// Likes or dislikes a recipe: on the phone at once, on the server through
  /// the outbox. The server feeds it to the next suggestions.
  Future<void> rate(String recipeName, {required bool liked}) async {
    final name = recipeName.trim();
    if (name.isEmpty) return;

    await _outbox().enqueue(
      id: ratingEntryId(name),
      kind: OutboxKind.rateRecipe,
      payload: <String, dynamic>{
        'user_id': _requireUserId(),
        'recipe_name': name,
        'liked': liked,
      },
    );
    await _cache.put(
      _ratingsKey,
      jsonEncode(<String, bool>{...ratings(), name: liked}),
    );
  }

  /// Sends one queued opinion.
  Future<void> sendQueuedRating(OutboxEntry entry) async {
    final stored = await _remote.rate(
      userId: entry.payload['user_id'] as String,
      recipeName: entry.payload['recipe_name'] as String,
      liked: entry.payload['liked'] as bool,
    );
    if (!stored) throw StateError('rate_recipe did not store the opinion');
  }

  /// The outbox id for [recipeName]'s opinion: the same for the same dish, so
  /// a changed mind replaces the queued write.
  ///
  /// A name-based UUID rather than the name: box keys must be ASCII, and a
  /// dish is called "كشري".
  static String ratingEntryId(String recipeName) {
    final key = const Uuid().v5(Namespace.url.value, recipeName.trim());
    return 'recipe_rating:$key';
  }

  String _requireUserId() {
    final id = _signedInUserId();
    if (id == null || id.isEmpty) {
      throw StateError('no signed-in user to ask the chef for');
    }
    return id;
  }
}
