/// Where category budgets live: one document in the documents box, queued to
/// `zad_category_budgets` so they follow the account and the agent can set
/// them (owner, 2026-11-09). They used to stay on the device.
///
/// The smart analysis behind each card is `zad-core-intelligence`'s
/// `behavior_analysis`, one model call, asked only when the customer taps.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/data/sync/outbox.dart';
import 'package:zad/core/data/sync/outbox_entry.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/shared/budget/data/category_budgets_remote.dart';

/// Reads and writes the ceilings.
class CategoryBudgetsStore {
  /// Creates a store over the documents box.
  const new({
    required Box<String> cache,
    required CategoryBudgetsRemote Function() remote,
    required Outbox Function() outbox,
    required String? Function() userId,
  }) : _cache = cache,
       _remote = remote,
       _outbox = outbox,
       _userId = userId;

  final Box<String> _cache;
  final CategoryBudgetsRemote Function() _remote;
  final Outbox Function() _outbox;
  final String? Function() _userId;

  static const String _key = 'category_budgets';

  /// Set once this device's old ceilings have gone up to the account.
  static const String _uploadedKey = 'category_budgets_uploaded';

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
    await _enqueue(category, amount);
    final next = <String, double>{...read()};
    if (amount <= 0) {
      next.remove(category);
    } else {
      next[category] = amount;
    }
    await _cache.put(_key, jsonEncode(next));
    return next;
  }

  /// One entry per category, so a second change replaces an unsent first.
  Future<void> _enqueue(String category, double amount) => _outbox().enqueue(
    id: 'category_budget:$category',
    kind: OutboxKind.setCategoryBudget,
    payload: <String, dynamic>{'category': category, 'amount': amount},
  );

  /// Reads the account's ceilings. The server wins, except for a change still
  /// queued. The first time, ceilings that lived only here go up to it.
  Future<Map<String, double>> pull() async {
    final userId = _userId();
    if (userId == null) return read();
    final server = await _remote().fetchAll(userId: userId);
    final queued = <String, double>{
      for (final e in _outbox().entries(includeDead: false))
        if (e.kind == OutboxKind.setCategoryBudget)
          e.payload['category'] as String: (e.payload['amount'] as num)
              .toDouble(),
    };
    if (_cache.get(_uploadedKey) == null) {
      for (final MapEntry(key: category, value: amount) in read().entries) {
        if (server.containsKey(category) || queued.containsKey(category)) {
          continue;
        }
        await _enqueue(category, amount);
        queued[category] = amount;
      }
      await _cache.put(_uploadedKey, '1');
    }
    final merged = <String, double>{...server};
    for (final MapEntry(key: category, value: amount) in queued.entries) {
      if (amount <= 0) {
        merged.remove(category);
      } else {
        merged[category] = amount;
      }
    }
    await _cache.put(_key, jsonEncode(merged));
    return merged;
  }

  /// Sends one queued change.
  Future<void> sendQueued(OutboxEntry entry) async {
    final userId = _userId();
    if (userId == null) throw StateError('No signed-in user');
    final category = entry.payload['category'] as String;
    final amount = (entry.payload['amount'] as num).toDouble();
    if (amount <= 0) {
      await _remote().remove(userId: userId, category: category);
    } else {
      await _remote().upsert(
        userId: userId,
        category: category,
        amount: amount,
      );
    }
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
  String trendLabel(ZadL10n l) => switch (trend) {
    'increasing' => l.trendUp,
    'decreasing' => l.trendDown,
    _ => l.trendFlat,
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

/// Category ceilings: this device's copy, and the way to the account.
final Provider<CategoryBudgetsStore> categoryBudgetsStoreProvider =
    Provider<CategoryBudgetsStore>(
      (ref) => CategoryBudgetsStore(
        cache: ref.watch(localStoreProvider).documents,
        remote: () =>
            SupabaseCategoryBudgetsRemote(ref.read(supabaseClientProvider)),
        outbox: () => ref.read(outboxProvider),
        userId: () => ref.read(signedInUserIdProvider)(),
      ),
    );

/// The per-category analysis, asked on a tap.
final Provider<BehaviorAnalysisRemote> behaviorAnalysisRemoteProvider =
    Provider<BehaviorAnalysisRemote>(
      (ref) =>
          SupabaseBehaviorAnalysisRemote(ref.watch(supabaseClientProvider)),
    );
