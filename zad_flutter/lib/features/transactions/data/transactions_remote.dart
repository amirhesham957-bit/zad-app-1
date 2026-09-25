/// The server side of transactions, behind an interface so the repository
/// can be tested without a network.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads and writes `zad_transactions`.
abstract interface class TransactionsRemote {
  /// Rows in `[startsAt, endsAt)`, newest first.
  Future<List<Map<String, dynamic>>> fetchPeriod({
    required String userId,
    required DateTime startsAt,
    required DateTime endsAt,
  });

  /// Inserts [row] if its id is new, then returns whatever the server holds for
  /// that id.
  Future<Map<String, dynamic>?> upsertReturning(Map<String, dynamic> row);

  /// Applies [patch] to the row `patch['id']`, then returns what the server
  /// holds for it — null when the row is gone.
  Future<Map<String, dynamic>?> updateReturning(Map<String, dynamic> patch);

  /// Deletes [id].
  Future<void> delete(String id);

  /// Whether [id] still exists — the read-back after a delete.
  Future<bool> exists(String id);
}

/// The real implementation.
class SupabaseTransactionsRemote implements TransactionsRemote {
  /// Creates a remote over a Supabase client.
  const new(this._client);

  final SupabaseClient _client;

  static const String _table = 'zad_transactions';

  @override
  Future<List<Map<String, dynamic>>> fetchPeriod({
    required String userId,
    required DateTime startsAt,
    required DateTime endsAt,
  }) async {
    // A plain half-open range on the raw timestamptz column, which is what the
    // period's instants exist for. Never `(created_at at time zone tz)::date`:
    // that is computed per row and cannot use an index.
    final rows = await _client
        .from(_table)
        .select()
        .eq('user_id', userId)
        .gte('created_at', startsAt.toUtc().toIso8601String())
        .lt('created_at', endsAt.toUtc().toIso8601String())
        .order('created_at', ascending: false);

    return rows.cast<Map<String, dynamic>>();
  }

  @override
  Future<Map<String, dynamic>?> upsertReturning(
    Map<String, dynamic> row,
  ) async {
    // ignoreDuplicates makes the replay of an already-applied write a no-op
    // instead of a second row. That is what keeps a retry from firing the
    // AFTER INSERT triggers — the Telegram message and the parent alert —
    // twice.
    await _client
        .from(_table)
        .upsert(row, onConflict: 'id', ignoreDuplicates: true);

    // Read back rather than trusting what was sent: two BEFORE INSERT triggers
    // may have rewritten it. zad_enforce_txn_kind reconciles txn_kind against
    // is_expense, and zad_normalize_transaction_currency converts the amount
    // into the account's currency using rates this client does not have.
    return await _client
        .from(_table)
        .select()
        .eq('id', row['id'] as String)
        .maybeSingle();
  }

  @override
  Future<Map<String, dynamic>?> updateReturning(
    Map<String, dynamic> patch,
  ) async {
    final id = patch['id'] as String;
    await _client
        .from(_table)
        .update(<String, dynamic>{...patch}..remove('id'))
        .eq('id', id);
    return await _client.from(_table).select().eq('id', id).maybeSingle();
  }

  @override
  Future<void> delete(String id) => _client.from(_table).delete().eq('id', id);

  @override
  Future<bool> exists(String id) async =>
      await _client.from(_table).select('id').eq('id', id).maybeSingle() !=
      null;
}
