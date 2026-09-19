/// The budget, cached.
///
/// The read is synchronous and that is the whole point: the first frame calls
/// `cached` and draws a figure, instead of a spinner that resolves into the
/// same figure a second later.
library;

import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/features/budget/domain/budget_snapshot.dart';

/// The server side of the budget, behind an interface so the repository can be
/// tested without a network.
abstract interface class BudgetRemote {
  /// Calls `zad_budget_state()`.
  Future<Map<String, dynamic>> fetch({
    required String userId,
    required String timeZone,
  });
}

/// The real implementation.
class SupabaseBudgetRemote implements BudgetRemote {
  /// Creates a remote over a Supabase client.
  const new(this._client);

  final SupabaseClient _client;

  @override
  Future<Map<String, dynamic>> fetch({
    required String userId,
    required String timeZone,
  }) async {
    // Not security definer, so this reads through the caller's own RLS: it can
    // only ever answer for an account the caller can already see.
    final result = await _client.rpc<dynamic>(
      'zad_budget_state',
      params: <String, dynamic>{'p_user': userId, 'p_tz': timeZone},
    );
    return Map<String, dynamic>.from(result as Map);
  }
}

/// Reads the budget.
class BudgetRepository {
  /// Creates a repository.
  const new({
    required Box<String> cache,
    required BudgetRemote remote,
    required String? Function() signedInUserId,
  }) : _cache = cache,
       _remote = remote,
       _signedInUserId = signedInUserId;

  final Box<String> _cache;
  final BudgetRemote _remote;
  final String? Function() _signedInUserId;

  static const String _key = 'budget_state';

  /// The last answer the server gave, or null if it has never answered.
  ///
  /// Synchronous. Call it from `build`.
  BudgetSnapshot? cached() {
    final raw = _cache.get(_key);
    if (raw == null) return null;

    final snapshot = BudgetSnapshot.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );

    // A cached answer belongs to the account that asked for it. After a
    // sign-out and a different sign-in the box still has the previous user's
    // figures, and showing those to somebody else is the worst bug this screen
    // could have.
    final userId = _signedInUserId();
    if (userId == null || snapshot.userId != userId) return null;

    return snapshot;
  }

  /// Asks the server, and caches the answer.
  Future<BudgetSnapshot> refresh({required String timeZone}) async {
    final userId = _signedInUserId();
    if (userId == null || userId.isEmpty) {
      throw StateError('no signed-in user to read a budget for');
    }

    final json = await _remote.fetch(userId: userId, timeZone: timeZone);
    final snapshot = BudgetSnapshot.fromJson(json);
    await _cache.put(_key, jsonEncode(snapshot.toJson()));
    return snapshot;
  }

  /// Forgets the cached answer. Called on sign-out.
  Future<void> clear() => _cache.delete(_key);
}
