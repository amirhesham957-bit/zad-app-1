/// The server side of recurring charges.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads and writes `zad_subscriptions`.
///
/// RLS is `user_own_subscriptions` — `auth.uid() = user_id`, for every
/// command — so every read here is the caller's own rows and nothing else.
abstract interface class SubscriptionsRemote {
  /// Every row the account owns.
  Future<List<Map<String, dynamic>>> fetchAll({required String userId});

  /// Writes [row] and returns what it holds afterwards, or null when there is
  /// nothing to read back.
  Future<Map<String, dynamic>?> upsertReturning(Map<String, dynamic> row);

  /// Removes a row.
  Future<void> remove(String id);
}

/// The real table.
class SupabaseSubscriptionsRemote implements SubscriptionsRemote {
  /// Creates a remote over a Supabase client.
  const new(this._client);

  final SupabaseClient _client;

  static const String _table = 'zad_subscriptions';

  @override
  Future<List<Map<String, dynamic>>> fetchAll({required String userId}) async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('user_id', userId)
        .order('created_at');
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
