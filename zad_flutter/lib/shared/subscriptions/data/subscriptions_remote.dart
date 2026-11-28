/// The server side of recurring charges.
library;

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/core/data/commit_my_intent.dart';
import 'package:zad/core/data/edge_client.dart';
import 'package:zad/core/data/sync/sync_failure.dart';

/// Reads `zad_subscriptions` and writes it through the one door (P1.6b).
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

  /// What `subscription.added` reads from a row; `id` travels as `item_id`.
  static const List<String> _addKeys = <String>[
    'title',
    'amount',
    'renewal_date',
    'due_day',
    'billing_cycle',
    'category',
    'type',
    'provider',
    'auto_deduct',
  ];

  /// What `subscription.updated` accepts in a patch.
  static const List<String> _patchKeys = <String>[..._addKeys, 'is_active'];

  @override
  Future<Map<String, dynamic>?> upsertReturning(
    Map<String, dynamic> row,
  ) async {
    final id = row['id'] as String;
    final exists =
        await _client.from(_table).select('id').eq('id', id).maybeSingle() !=
        null;
    if (!exists) {
      // A replay of the add is answered by the door without a second row.
      await commitMyIntent(
        _client,
        kind: 'subscription.added',
        clientEventId: 'subscription:$id',
        payload: <String, dynamic>{
          'item_id': id,
          for (final key in _addKeys)
            if (row[key] != null) key: row[key],
        },
      );
    }
    // The door adds a row active; an edit (or an add that was already stopped)
    // carries the rest, as an absolute write under a fresh event id.
    if (exists || row['is_active'] == false) {
      await commitMyIntent(
        _client,
        kind: 'subscription.updated',
        clientEventId: 'subscription_edit:$id:${newTraceId()}',
        payload: <String, dynamic>{
          'item_id': id,
          'patch': <String, dynamic>{
            for (final key in _patchKeys)
              if (row.containsKey(key)) key: row[key],
          },
        },
      );
    }
    return await _client.from(_table).select().eq('id', id).maybeSingle();
  }

  @override
  Future<void> remove(String id) async {
    try {
      await commitMyIntent(
        _client,
        kind: 'subscription.deleted',
        clientEventId: 'subscription_delete:$id',
        payload: <String, dynamic>{'item_id': id},
      );
    } on ServerRefusal catch (e) {
      // Already gone: the delete has nothing left to do.
      if (e.reason != 'item_not_found') rethrow;
    }
  }
}
