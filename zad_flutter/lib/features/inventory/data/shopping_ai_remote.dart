/// The two model calls Kotlin's shopping list makes — `grocery_suggestions`
/// ("قد تحتاج أيضاً") and `estimate_price` — asked here only on the
/// customer's tap ("تعبئة ذكية"), never on open.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

/// One suggestion.
typedef GrocerySuggestion = ({String name, String quantity, String reason});

/// Asks.
abstract interface class ShoppingAiRemote {
  /// What the house may need, from the pantry as text.
  Future<List<GrocerySuggestion>> suggest({
    required String userId,
    required String inventory,
    int familySize = 4,
  });

  /// A typical price for [itemName], or null.
  Future<double?> estimatePrice({
    required String userId,
    required String itemName,
  });
}

/// The real calls.
class SupabaseShoppingAiRemote implements ShoppingAiRemote {
  /// Creates a remote over a Supabase client.
  const new(this._client);

  final SupabaseClient _client;

  Future<Map<String, dynamic>> _call(
    String action,
    String userId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _client.functions.invoke(
      'zad-core-intelligence',
      body: <String, dynamic>{
        'action': action,
        'user_id': userId,
        'payload': payload,
      },
    );
    final data = response.data;
    if (data is! Map) throw StateError('$action answered ${data.runtimeType}');
    return Map<String, dynamic>.from(data);
  }

  @override
  Future<List<GrocerySuggestion>> suggest({
    required String userId,
    required String inventory,
    int familySize = 4,
  }) async {
    final data = await _call('grocery_suggestions', userId, <String, dynamic>{
      'inventory': inventory,
      'family_size': familySize,
    });
    return <GrocerySuggestion>[
      for (final raw in (data['suggestions'] as List<dynamic>? ?? <dynamic>[]))
        if (raw is Map && (raw['name'] as String? ?? '').trim().isNotEmpty)
          (
            name: (raw['name'] as String).trim(),
            quantity: '${raw['quantity'] ?? ''}',
            reason: '${raw['reason'] ?? ''}',
          ),
    ];
  }

  @override
  Future<double?> estimatePrice({
    required String userId,
    required String itemName,
  }) async {
    final data = await _call('estimate_price', userId, <String, dynamic>{
      'item_name': itemName,
      'store': '',
    });
    final avg = (data['avg_price'] as num?)?.toDouble();
    return avg != null && avg > 0 ? avg : null;
  }
}
