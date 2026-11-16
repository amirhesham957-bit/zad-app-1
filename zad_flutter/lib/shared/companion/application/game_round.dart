/// One finished round of any game: records it locally (best, challenge,
/// streak), reports it to the server for seeds, and offers «ضاعف البذور».
/// Plain class, not a widget: a game's screen owns one per round.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:zad/shared/ads/data/rewarded_ads.dart';
import 'package:zad/shared/auth/application/session_controller.dart';
import 'package:zad/shared/companion/application/game_stats_controller.dart';
import 'package:zad/shared/companion/data/game_reward_remote.dart';
import 'package:zad/shared/companion/domain/zad_game.dart';

/// Reads a provider: `ref.read` of a widget's or a container's ref.
typedef ProviderReader = T Function<T>(ProviderListenable<T> provider);

/// A round's end.
class GameRound extends ChangeNotifier {
  /// For a round of [game].
  new(this._ref, this.game);

  final ProviderReader _ref;

  /// The game.
  final ZadGame game;

  /// The score reported.
  int score = 0;

  /// What the server gave for the round; null offline or before the call.
  GameGrant? grant;

  /// The reward call is in flight.
  bool busy = false;

  /// The doubling went through.
  bool doubled = false;

  /// The ad for doubling did not play.
  bool adUnavailable = false;

  /// The round was recorded.
  bool get ended => _ended;
  bool _ended = false;
  bool _claimed = false;
  bool _disposed = false;

  /// Best and challenge, locally, right at the hit. A round that goes on
  /// after «كمّل» records again with its higher score.
  void end(int finalScore) {
    score = finalScore;
    _ended = true;
    _ref(gameStatsProvider(game.id).notifier).record(finalScore);
  }

  /// Reports the round to the server, once.
  Future<void> claim() async {
    if (_claimed || !_ended) return;
    _claimed = true;
    busy = true;
    notifyListeners();
    GameGrant? g;
    try {
      g = await _ref(gameRewardRepositoryProvider).report(game.id, score);
    } on Object catch (e) {
      debugPrint('[games] no reward repository: $e');
    }
    if (_disposed) return;
    grant = g;
    busy = false;
    notifyListeners();
  }

  /// «ضاعف البذور»: a rewarded ad, then the call again with `doubled`.
  Future<void> doubleSeeds() async {
    final user = _ref(sessionControllerProvider);
    if (doubled || busy || user == null) return;
    await claim();
    busy = true;
    adUnavailable = false;
    notifyListeners();
    final outcome = await _ref(rewardedAdsProvider).watch(userId: user);
    if (_disposed) return;
    if (outcome != RewardedOutcome.earned) {
      busy = false;
      adUnavailable = outcome == RewardedOutcome.unavailable;
      notifyListeners();
      return;
    }
    GameGrant? g;
    try {
      g = await _ref(gameRewardRepositoryProvider)
          .report(game.id, score, doubled: true);
    } on Object catch (e) {
      debugPrint('[games] no reward repository: $e');
    }
    if (_disposed) return;
    doubled = g != null;
    grant = g ?? grant;
    busy = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
