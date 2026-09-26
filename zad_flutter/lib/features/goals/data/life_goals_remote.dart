/// Kotlin's `SupabaseRepo.hasActiveLifeGoal` and `seedLifeGoal`.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/features/goals/domain/life_goal_seed.dart';

/// `zad_seed_life_goal`'s answer.
class SeedLifeGoalResult {
  /// Creates a result.
  const new({required this.ok, this.error});

  /// Whether the goal was recorded.
  final bool ok;

  /// The server's error code (`too_many_active_goals`, …), or
  /// `request_failed` when the request never got an answer.
  final String? error;
}

/// Reads and records life goals.
class LifeGoalsRemote {
  /// Creates the remote.
  const new(this._client);

  final SupabaseClient _client;

  /// Whether the signed-in user has an active goal. Null when unknown — not
  /// signed in, or the read failed — which the home card treats as "done" so
  /// the step does not flicker in and out on a bad network (Kotlin's rule).
  Future<bool?> hasActiveLifeGoal() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    try {
      final rows = await _client
          .from('agent_goals')
          .select('id')
          .eq('user_id', userId)
          .eq('status', 'active')
          .limit(1);
      return rows.isNotEmpty;
    } on Object catch (e) {
      debugPrint('hasActiveLifeGoal() FAILED: $e');
      return null;
    }
  }

  /// Records the goal and its weekly follow-up through `zad_seed_life_goal`.
  /// Deterministic — no model call — and scoped to `auth.uid()` server-side.
  Future<SeedLifeGoalResult> seedLifeGoal(LifeGoalSeed seed) async {
    try {
      final d = seed.deadline;
      final deadline =
          '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
      final res = await _client.rpc<dynamic>(
        'zad_seed_life_goal',
        params: <String, dynamic>{
          'p_title': seed.title,
          'p_metric': seed.metric,
          'p_target_value': seed.targetValue,
          'p_deadline': deadline,
        },
      );
      if (res is Map) {
        return SeedLifeGoalResult(
          ok: res['ok'] == true,
          error: res['error'] as String?,
        );
      }
      return const SeedLifeGoalResult(ok: false, error: 'request_failed');
    } on Object catch (e) {
      debugPrint('seedLifeGoal() FAILED: $e');
      return const SeedLifeGoalResult(ok: false, error: 'request_failed');
    }
  }
}

/// The remote.
final lifeGoalsRemoteProvider = Provider<LifeGoalsRemote>(
  (ref) => LifeGoalsRemote(ref.watch(supabaseClientProvider)),
);

/// Kotlin's `hasActiveGoal` on the home screen: read once when home opens, set
/// to true when the sheet saves one.
class HasActiveLifeGoal extends AsyncNotifier<bool?> {
  @override
  Future<bool?> build() =>
      ref.read(lifeGoalsRemoteProvider).hasActiveLifeGoal();

  /// The sheet saved one.
  void markSaved() => state = const AsyncData<bool?>(true);
}

/// Whether an active goal exists.
final hasActiveLifeGoalProvider =
    AsyncNotifierProvider<HasActiveLifeGoal, bool?>(HasActiveLifeGoal.new);
