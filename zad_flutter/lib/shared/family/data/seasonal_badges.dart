/// The seasonal badges a member has earned: a seasonal family challenge
/// (`family_financial_challenges.badge`, migration 20261005110000) they
/// completed. Completion is written by `zad_contribute_to_challenge` only, so
/// a badge here was earned.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/providers.dart';

/// One earned badge.
typedef SeasonalBadge = ({String badge, String title, DateTime? earnedAt});

/// Reads `financial_challenge_progress` rows with their challenge embedded:
/// only completed ones whose challenge carries a badge, newest first.
List<SeasonalBadge> seasonalBadgesFrom(List<Map<String, dynamic>> rows) {
  final out = <SeasonalBadge>[];
  for (final r in rows) {
    final c = r['family_financial_challenges'];
    if (r['is_completed'] != true || c is! Map) continue;
    final badge = (c['badge'] as String?)?.trim() ?? '';
    if (badge.isEmpty) continue;
    out.add((
      badge: badge,
      title: (c['title'] as String?)?.trim() ?? '',
      earnedAt: DateTime.tryParse('${r['completed_at']}')?.toUtc(),
    ));
  }
  out.sort((a, b) {
    final x = a.earnedAt;
    final y = b.earnedAt;
    if (x == null || y == null) return x == null ? 1 : -1;
    return y.compareTo(x);
  });
  return out;
}

/// The signed-in member's badges. Empty when the read fails: a missing badge
/// row must never break the screen it sits on.
final mySeasonalBadgesProvider = FutureProvider<List<SeasonalBadge>>((
  ref,
) async {
  final client = ref.watch(supabaseClientProvider);
  final uid = client.auth.currentUser?.id;
  if (uid == null) return const <SeasonalBadge>[];
  try {
    final rows = await client
        .from('financial_challenge_progress')
        .select(
          'is_completed,completed_at,'
          'family_financial_challenges(title,badge,season_key)',
        )
        .eq('user_id', uid)
        .eq('is_completed', true);
    return seasonalBadgesFrom(rows);
  } on Object catch (e) {
    debugPrint('[badges] not read: $e');
    return const <SeasonalBadge>[];
  }
});
