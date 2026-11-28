/// `zad_category_budgets` on the server.
library;

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/core/data/commit_my_intent.dart';
import 'package:zad/core/data/edge_client.dart';
import 'package:zad/core/data/sync/sync_failure.dart';

/// Reads and writes the account's ceilings.
abstract interface class CategoryBudgetsRemote {
  /// Every ceiling on the account, by category.
  Future<Map<String, double>> fetchAll({required String userId});

  /// Sets one ceiling.
  Future<void> upsert({
    required String userId,
    required String category,
    required double amount,
  });

  /// Removes one ceiling.
  Future<void> remove({required String userId, required String category});
}

/// The real table.
class SupabaseCategoryBudgetsRemote implements CategoryBudgetsRemote {
  /// Creates a remote over a Supabase client.
  const new(this._client);

  final SupabaseClient _client;

  static const String _table = 'zad_category_budgets';

  @override
  Future<Map<String, double>> fetchAll({required String userId}) async {
    final rows = await _client
        .from(_table)
        .select('category,amount')
        .eq('user_id', userId);
    return <String, double>{
      for (final row in rows)
        row['category'] as String: (row['amount'] as num).toDouble(),
    };
  }

  @override
  Future<void> upsert({
    required String userId,
    required String category,
    required double amount,
  }) => _set(category, amount);

  @override
  Future<void> remove({
    required String userId,
    required String category,
  }) async {
    try {
      await _set(category, 0);
    } on ServerRefusal catch (e) {
      // Already gone: removing it has nothing left to do.
      if (e.reason != 'no_category_budget') rethrow;
    }
  }

  /// `money.category_budget_set`: the ceiling is an absolute figure and zero
  /// removes it, so a fresh event id per attempt is safe (the same write twice
  /// leaves the same row) and a derived one would make a later return to an
  /// earlier amount look like a replay. The door takes the user from the JWT.
  Future<void> _set(String category, double amount) => commitMyIntent(
    _client,
    kind: 'money.category_budget_set',
    clientEventId: 'cb:${newTraceId()}',
    payload: <String, dynamic>{'category': category, 'amount': amount},
  );
}
