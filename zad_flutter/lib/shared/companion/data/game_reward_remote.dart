/// The games' one server call: `zad_game_reward(p_game, p_score, p_doubled)`.
/// The server owns the seed ledger and the daily allowance; the phone only
/// reports a finished round and shows what came back. Offline, or on any
/// failure, nothing is queued: the round's score is shown and that is all.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/core/data/providers.dart';

/// What the server answered for a round.
@immutable
class GameGrant {
  /// Creates one.
  const new({
    required this.granted,
    required this.remaining,
    this.doubled = false,
  });

  /// Reads the RPC's json; null when it is not what was promised.
  static GameGrant? fromJson(Object? json) {
    if (json is! Map) return null;
    final g = json['granted'] ?? json['seeds'];
    final r = json['remaining_today'] ?? json['remaining'];
    if (g is! num) return null;
    return GameGrant(
      granted: g.toInt() < 0 ? 0 : g.toInt(),
      remaining: r is num ? (r.toInt() < 0 ? 0 : r.toInt()) : 0,
      doubled: json['doubled'] == true,
    );
  }

  /// Seeds credited for this call.
  final int granted;

  /// Seeds still allowed today.
  final int remaining;

  /// The server doubled the round on this call.
  final bool doubled;

  /// Nothing was granted and nothing is left today.
  bool get capped => granted == 0 && remaining == 0;
}

/// The transport, so tests can fake the wire.
abstract interface class GameRewardClient {
  /// Calls the RPC [fn] with [params]; returns its json.
  Future<Object?> rpc(String fn, Map<String, Object?> params);
}

/// Supabase.
class SupabaseGameRewardClient implements GameRewardClient {
  /// Over a Supabase client.
  const new(this._client);

  final SupabaseClient _client;

  @override
  Future<Object?> rpc(String fn, Map<String, Object?> params) =>
      _client.rpc<dynamic>(fn, params: Map<String, dynamic>.of(params));
}

/// Reports rounds.
class GameRewardRepository {
  /// Over a `client`.
  const new(this._client);

  final GameRewardClient _client;

  /// A finished round of [game] (`ZadGame.id`) with [score]. [doubled] after
  /// a rewarded ad. Null when the server could not be reached or answered
  /// something unreadable.
  Future<GameGrant?> report(
    String game,
    int score, {
    bool doubled = false,
  }) async {
    try {
      return GameGrant.fromJson(
        await _client.rpc('zad_game_reward', <String, Object?>{
          'p_game': game,
          'p_score': score,
          'p_doubled': doubled,
        }),
      );
    } on Object catch (e) {
      debugPrint('[games] reward call failed: $e');
      return null;
    }
  }
}

/// The repository in use.
final gameRewardRepositoryProvider = Provider<GameRewardRepository>(
  (ref) => GameRewardRepository(
    SupabaseGameRewardClient(ref.watch(supabaseClientProvider)),
  ),
);
