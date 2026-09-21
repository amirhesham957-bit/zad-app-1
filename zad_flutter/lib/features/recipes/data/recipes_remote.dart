/// The server side of شيف زاد.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

/// Asks for recipes and records opinions on them.
abstract interface class RecipesRemote {
  /// Calls `meal_suggestions` with the pantry as text. Throws on transport
  /// failure; returns the answer, `ok: false` included, otherwise.
  Future<Map<String, dynamic>> suggest({
    required String userId,
    required String items,
  });

  /// Calls `rate_recipe`. True when the server stored the opinion.
  Future<bool> rate({
    required String userId,
    required String recipeName,
    required bool liked,
  });
}

/// The real one.
class SupabaseRecipesRemote implements RecipesRemote {
  /// Creates a remote over a Supabase client.
  const new(this._client);

  final SupabaseClient _client;

  /// Where both actions live. Not `zad-brain`: the chef is one model call, not
  /// an agent turn.
  static const String function = 'zad-core-intelligence';

  @override
  Future<Map<String, dynamic>> suggest({
    required String userId,
    required String items,
  }) async {
    final response = await _client.functions.invoke(
      function,
      body: <String, dynamic>{
        'action': 'meal_suggestions',
        'user_id': userId,
        'payload': <String, dynamic>{'items': items},
      },
    );
    final data = response.data;
    if (data is! Map) {
      throw StateError('meal_suggestions answered ${data.runtimeType}');
    }
    return Map<String, dynamic>.from(data);
  }

  @override
  Future<bool> rate({
    required String userId,
    required String recipeName,
    required bool liked,
  }) async {
    // The action checks the bearer token against user_id itself; the
    // client's session token rides along with invoke.
    final response = await _client.functions.invoke(
      function,
      body: <String, dynamic>{
        'action': 'rate_recipe',
        'user_id': userId,
        'payload': <String, dynamic>{'recipe_name': recipeName, 'liked': liked},
      },
    );
    final data = response.data;
    return data is Map && data['ok'] == true;
  }
}
