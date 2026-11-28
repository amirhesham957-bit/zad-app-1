/// The server side of transactions, behind an interface so the repository
/// can be tested without a network.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/core/data/commit_my_intent.dart';
import 'package:zad/core/data/edge_client.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/data/sync/sync_failure.dart';

/// Reads `zad_transactions` and writes it through the one door (P1.6b).
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

  /// What `money.logged` reads from a row; `id` travels as `item_id`.
  static const List<String> _insertKeys = <String>[
    'amount',
    'title',
    'category',
    'txn_kind',
    'wallet',
    'transfer_to',
    'source_type',
    'merchant_name',
    'for_person',
    'counts_toward_budget',
    'currency',
    'created_at',
  ];

  /// What `money.updated` accepts in a patch.
  static const List<String> _patchKeys = <String>[
    'title',
    'amount',
    'category',
    'txn_kind',
    'for_person',
  ];

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
    final id = row['id'] as String;
    // The door answers a replay (same event id, or the same row id under a new
    // one) without writing, which is what keeps a retry from firing the AFTER
    // INSERT triggers (the Telegram message and the parent alert) twice.
    await commitMyIntent(
      _client,
      kind: 'money.logged',
      clientEventId: 'txn:$id',
      payload: <String, dynamic>{
        'item_id': id,
        for (final key in _insertKeys)
          if (row[key] != null) key: row[key],
      },
    );

    // Read back rather than trusting what was sent: two BEFORE INSERT triggers
    // may have rewritten it. zad_enforce_txn_kind reconciles txn_kind against
    // is_expense, and zad_normalize_transaction_currency converts the amount
    // into the account's currency using rates this client does not have.
    return await _client.from(_table).select().eq('id', id).maybeSingle();
  }

  @override
  Future<Map<String, dynamic>?> updateReturning(
    Map<String, dynamic> patch,
  ) async {
    final id = patch['id'] as String;
    try {
      await commitMyIntent(
        _client,
        kind: 'money.updated',
        // An edit is an absolute write, so a fresh id per attempt is safe: the
        // same edit twice leaves the same row. A derived id would instead make
        // the third of A, B, A, B look like a replay of the first.
        clientEventId: 'txn_edit:$id:${newTraceId()}',
        payload: <String, dynamic>{
          'item_id': id,
          'patch': <String, dynamic>{
            for (final key in _patchKeys)
              if (patch.containsKey(key) &&
                  // The door cannot change a row into or out of a transfer, so
                  // a transfer's kind is not part of its edit.
                  !(key == 'txn_kind' && patch[key] == 'transfer'))
                key: patch[key],
          },
        },
      );
    } on ServerRefusal catch (e) {
      // Deleted elsewhere since: nothing left to edit.
      if (e.reason == 'item_not_found') return null;
      rethrow;
    }
    return await _client.from(_table).select().eq('id', id).maybeSingle();
  }

  @override
  Future<void> delete(String id) async {
    try {
      await commitMyIntent(
        _client,
        kind: 'money.deleted',
        clientEventId: 'txn_delete:$id',
        payload: <String, dynamic>{'item_id': id},
      );
    } on ServerRefusal catch (e) {
      // Already gone: the delete has nothing left to do.
      if (e.reason != 'item_not_found') rethrow;
    }
  }

  @override
  Future<bool> exists(String id) async =>
      await _client.from(_table).select('id').eq('id', id).maybeSingle() !=
      null;
}

/// The server side of transactions.
final transactionsRemoteProvider = Provider<TransactionsRemote>(
  (ref) => SupabaseTransactionsRemote(ref.watch(supabaseClientProvider)),
);
