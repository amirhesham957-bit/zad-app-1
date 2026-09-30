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
}

/// Reads and writes `zad_shopping_list`.
abstract interface class ShoppingListRemote {
  /// The account's lines.
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

  @override
  Future<List<Map<String, dynamic>>> fetchAll() async {
    final rows = await _client.from(_table).select().order('item_name');
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
        .select()
        .eq('id', row['id'] as String)
        .maybeSingle();
  }

  @override
  Future<void> remove(String id) => _client.from(_table).delete().eq('id', id);
}

/// The real shopping list.
class SupabaseShoppingListRemote implements ShoppingListRemote {
  /// Creates a remote over a Supabase client.
  const new(this._client);

  final SupabaseClient _client;

  static const String _table = 'zad_shopping_list';

  @override
  Future<List<Map<String, dynamic>>> fetchAll({required String userId}) async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('user_id', userId)
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
