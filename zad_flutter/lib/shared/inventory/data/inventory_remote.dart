/// The server side of the pantry and the shopping list.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads and writes `zad_inventory`.
abstract interface class InventoryRemote {
  /// Every row the account can see.
  ///
  /// That is not the same as every row it owns: `zad_inventory` is shared
  /// with the household through `family_id`, and the read policy lets a member
  /// see the family's rows as well as their own. Filtering by `user_id` here
  /// would hide the shared pantry the household is supposed to keep together.
  Future<List<Map<String, dynamic>>> fetchAll();

  /// Inserts or updates [row], returning what the row holds afterwards.
  Future<Map<String, dynamic>?> upsertReturning(Map<String, dynamic> row);

  /// Removes a row.
  Future<void> remove(String id);

  /// Asks the door (`zad_commit_my_intent`) to apply one pantry intent and
  /// answers what it said: `{ok, reason?, duplicate?, ...}`. A refusal is data
  /// here, not an exception.
  Future<Map<String, dynamic>> commitMyIntent({
    required String kind,
    required String clientEventId,
    required Map<String, dynamic> payload,
    required DateTime occurredAt,
  });

  /// One row as the server holds it, or null if there is none.
  Future<Map<String, dynamic>?> fetchOne(String id);
}

/// Reads and writes `zad_shopping_list`.
abstract interface class ShoppingListRemote {
  /// Every line the account can see: its own and, in a family, the
  /// household's — the list is shared through `family_id` the way the pantry
  /// is (owner, 2026-10-11), and RLS decides. [userId] is the signed-in
  /// account; the server does not need it to filter.
  Future<List<Map<String, dynamic>>> fetchAll({required String userId});

  /// Inserts or updates [row], returning what the row holds afterwards.
  Future<Map<String, dynamic>?> upsertReturning(Map<String, dynamic> row);

  /// Removes a line.
  Future<void> remove(String id);
}

/// The real pantry.
class SupabaseInventoryRemote implements InventoryRemote {
  /// Creates a remote over a Supabase client.
  const new(this._client);

  final SupabaseClient _client;

  static const String _table = 'zad_inventory';

  /// Every column plus `restock_occasional`, the server's verdict from the
  /// purchase history (migration 20261020130000).
  static const String _columns = '*,restock_occasional';

  @override
  Future<List<Map<String, dynamic>>> fetchAll() async {
    final rows = await _client.from(_table).select(_columns).order('item_name');
    return rows.cast<Map<String, dynamic>>();
  }

  @override
  Future<Map<String, dynamic>?> upsertReturning(
    Map<String, dynamic> row,
  ) async {
    await _client.from(_table).upsert(row, onConflict: 'id');

    // Read back rather than trusting what was sent: a trigger decides
    // `family_id`, and the row the household sees is the one the server
    // holds, not the one this device posted.
    return await _client
        .from(_table)
        .select(_columns)
        .eq('id', row['id'] as String)
        .maybeSingle();
  }

  @override
  Future<void> remove(String id) => _client.from(_table).delete().eq('id', id);

  @override
  Future<Map<String, dynamic>> commitMyIntent({
    required String kind,
    required String clientEventId,
    required Map<String, dynamic> payload,
    required DateTime occurredAt,
  }) async {
    final answer = await _client.rpc<dynamic>(
      'zad_commit_my_intent',
      params: <String, dynamic>{
        'p_kind': kind,
        'p_client_event_id': clientEventId,
        'p_payload': payload,
        'p_occurred_at': occurredAt.toUtc().toIso8601String(),
      },
    );
    return Map<String, dynamic>.from(answer as Map);
  }

  @override
  Future<Map<String, dynamic>?> fetchOne(String id) =>
      _client.from(_table).select(_columns).eq('id', id).maybeSingle();
}

/// The real shopping list.
class SupabaseShoppingListRemote implements ShoppingListRemote {
  /// Creates a remote over a Supabase client.
  const new(this._client);

  final SupabaseClient _client;

  static const String _table = 'zad_shopping_list';

  @override
  Future<List<Map<String, dynamic>>> fetchAll({required String userId}) async {
    // No `user_id` filter: that would hide the household's lines.
    final rows = await _client
        .from(_table)
        .select()
        .order('created_at', ascending: false);
    return rows.cast<Map<String, dynamic>>();
  }

  @override
  Future<Map<String, dynamic>?> upsertReturning(
    Map<String, dynamic> row,
  ) async {
    await _client.from(_table).upsert(row, onConflict: 'id');
    return await _client
        .from(_table)
        .select()
        .eq('id', row['id'] as String)
        .maybeSingle();
  }

  @override
  Future<void> remove(String id) => _client.from(_table).delete().eq('id', id);
}
