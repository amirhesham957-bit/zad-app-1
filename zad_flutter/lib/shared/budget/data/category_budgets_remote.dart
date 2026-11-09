/// `zad_category_budgets` on the server.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

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
  }) => _client
      .from(_table)
      .upsert(<String, dynamic>{
        'user_id': userId,
        'category': category,
        'amount': amount,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,category')
      .select('id')
      .single();

  @override
  Future<void> remove({required String userId, required String category}) =>
      _client
          .from(_table)
          .delete()
          .eq('user_id', userId)
          .eq('category', category);
}
