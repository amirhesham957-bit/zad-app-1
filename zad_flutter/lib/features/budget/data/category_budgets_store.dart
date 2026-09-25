/// Where category budgets live: one document in the documents box, per
/// device — Kotlin keeps them in `SharedPreferences`, never on the server.
///
/// The smart analysis behind each card is `zad-core-intelligence`'s
/// `behavior_analysis`, one model call, asked only when the customer taps.
library;

import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads and writes the ceilings.
class CategoryBudgetsStore {
  /// Creates a store over the documents box.
  const new(this._cache);

  final Box<String> _cache;

  static const String _key = 'category_budgets';

  /// Every ceiling, by category.
  Map<String, double> read() {
    final raw = _cache.get(_key);
    if (raw == null) return const <String, double>{};
    try {
      return <String, double>{
        for (final e in (jsonDecode(raw) as Map<String, dynamic>).entries)
          e.key: (e.value as num).toDouble(),
      };
    } on Object {
      return const <String, double>{};
    }
  }

  /// Sets [category]'s ceiling; zero removes it.
  Future<Map<String, double>> write(String category, double amount) async {
    final next = <String, double>{...read()};
    if (amount <= 0) {
      next.remove(category);
    } else {
      next[category] = amount;
    }
    await _cache.put(_key, jsonEncode(next));
    return next;
  }
}

/// What the model said about one category.
class BehaviorAnalysis {
  /// Creates an analysis.
  const new({
    required this.insight,
    required this.trend,
    required this.tip,
    required this.predictedNext,
  });

  /// Reads the action's answer.
  factory fromJson(Map<String, dynamic> json) => BehaviorAnalysis(
    insight: (json['insight'] as String? ?? '').trim(),
    trend: json['trend'] as String? ?? 'stable',
    tip: (json['tip'] as String? ?? '').trim(),
    predictedNext: (json['predicted_next'] as num?)?.toDouble() ?? 0,
  );

  /// The finding.
  final String insight;

  /// `increasing`, `decreasing` or `stable`.
  final String trend;

  /// A tip.
  final String tip;

  /// Next month's expected spend in the category.
  final double predictedNext;

  /// The trend in words.
  String get trendLabel => switch (trend) {
    'increasing' => 'في ازدياد',
    'decreasing' => 'في انخفاض',
    _ => 'مستقر',
  };
}

/// Asks for a category's analysis.
abstract interface class BehaviorAnalysisRemote {
  /// Calls `behavior_analysis`.
  Future<BehaviorAnalysis> analyze({
    required String userId,
    required String category,
    required String transactions,
  });
}

/// The real call.
class SupabaseBehaviorAnalysisRemote implements BehaviorAnalysisRemote {
  /// Creates a remote over a Supabase client.
  const new(this._client);

  final SupabaseClient _client;

  @override
  Future<BehaviorAnalysis> analyze({
    required String userId,
    required String category,
    required String transactions,
  }) async {
    final response = await _client.functions.invoke(
      'zad-core-intelligence',
      body: <String, dynamic>{
        'action': 'behavior_analysis',
        'user_id': userId,
        'payload': <String, dynamic>{
          'category': category,
          'transactions': transactions,
          'current_patterns': '',
        },
      },
    );
    final data = response.data;
    if (data is! Map) {
      throw StateError('behavior_analysis answered ${data.runtimeType}');
    }
    return BehaviorAnalysis.fromJson(Map<String, dynamic>.from(data));
  }
}
