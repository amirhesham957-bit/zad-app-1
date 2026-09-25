/// The server side of the garden: `family_tasbiha`, the atomic
/// `increment_tasbiha_clicks` RPC, and the challenge tables. All family
/// scoped by RLS (`get_my_family_ids()`), the same reads and writes Kotlin's
/// `SupabaseRepo` makes.
library;

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/features/tasbiha/domain/tasbiha.dart';

/// Reads and writes the garden.
class TasbihaRemote {
  /// Creates the remote.
  const new(this._client);

  final SupabaseClient _client;

  /// Every tree in [familyId].
  Future<List<GardenTree>> familyTrees(String familyId) async {
    final rows = await _client
        .from('family_tasbiha')
        .select()
        .eq('family_id', familyId);
    return <GardenTree>[for (final r in rows) GardenTree.fromJson(r)];
  }

  /// A new tree — Kotlin's `createNewTree`: the garden takes the name, the
  /// tree starts as «شجرة جديدة».
  Future<GardenTree> createTree({
    required String familyId,
    required String userId,
    required String gardenName,
    String treeName = 'شجرة جديدة',
  }) async {
    final row = await _client
        .from('family_tasbiha')
        .insert(<String, dynamic>{
          'family_id': familyId,
          'user_id': userId,
          'garden_name': gardenName,
          'tree_name': treeName,
        })
        .select()
        .single();
    return GardenTree.fromJson(row);
  }

  /// Adds [delta] taps atomically and writes the stage fields.
  Future<GardenTree> increment(GardenTree latest, int delta) async {
    final row = await _client
        .rpc<Map<String, dynamic>>(
          'increment_tasbiha_clicks',
          params: <String, dynamic>{
            'p_tree_id': latest.id,
            'p_delta': delta,
            'p_level': latest.level,
            'p_tree_emoji': latest.stageEmoji(),
            'p_is_mature': latest.isMature,
            'p_matured_at': latest.maturedAt,
            'p_streak_days': latest.streakDays,
            'p_last_streak_date': latest.lastStreakDate,
            'p_last_tasbih_at': latest.lastTasbihAt,
          },
        )
        .single();
    return GardenTree.fromJson(row);
  }

  /// Renames a tree.
  Future<void> rename(String treeId, String name) => _client
      .from('family_tasbiha')
      .update(<String, dynamic>{'tree_name': name})
      .eq('id', treeId);

  /// Active challenges in [familyId].
  Future<List<TasbihaChallenge>> activeChallenges(String familyId) async {
    final rows = await _client
        .from('family_tasbiha_challenges')
        .select()
        .eq('family_id', familyId)
        .eq('is_active', true);
    return <TasbihaChallenge>[for (final r in rows) challengeFromJson(r)];
  }

  /// [userId]'s clicks per challenge id.
  Future<Map<String, int>> myProgress(
    List<String> challengeIds,
    String userId,
  ) async {
    if (challengeIds.isEmpty) return const <String, int>{};
    final rows = await _client
        .from('tasbiha_challenge_progress')
        .select('challenge_id, current_clicks')
        .inFilter('challenge_id', challengeIds)
        .eq('user_id', userId);
    return <String, int>{
      for (final r in rows)
        '${r['challenge_id']}': (r['current_clicks'] as num?)?.toInt() ?? 0,
    };
  }

  /// Creates a challenge.
  Future<void> createChallenge({
    required String familyId,
    required String title,
    required String? description,
    required String challengeType,
    required int targetClicks,
  }) => _client.from('family_tasbiha_challenges').insert(<String, dynamic>{
    'family_id': familyId,
    'title': title,
    'description': description,
    'challenge_type': challengeType,
    'target_clicks': targetClicks,
  });
}
