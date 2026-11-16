import 'package:flutter_test/flutter_test.dart';
import 'package:zad/shared/ads/data/rewarded_ads.dart';
import 'package:zad/shared/companion/application/game_round.dart';
import 'package:zad/shared/companion/data/game_reward_remote.dart';
import 'package:zad/shared/companion/domain/zad_game.dart';

import 'games_kit.dart';

void main() {
  group('GameRewardRepository', () {
    test('granted: what the server gave and what is left', () async {
      final client = FakeRewardClient();
      final g = await GameRewardRepository(client).report('ball', 14);
      expect(g!.granted, 5);
      expect(g.remaining, 20);
      expect(g.capped, isFalse);
      expect(client.calls.single, <String, Object?>{
        'p_game': 'ball',
        'p_score': 14,
        'p_doubled': false,
      });
    });

    test('capped: nothing granted, nothing left today', () async {
      final client = FakeRewardClient()
        ..answer = (_) => <String, Object?>{'granted': 0, 'remaining': 0};
      final g = await GameRewardRepository(client).report('zado_run', 90);
      expect(g!.capped, isTrue);
    });

    test('doubled is sent through', () async {
      final client = FakeRewardClient();
      await GameRewardRepository(client)
          .report('star_catch', 70, doubled: true);
      expect(client.calls.single['p_doubled'], isTrue);
    });

    test(
      'offline or unreadable: null, nothing thrown, nothing queued',
      () async {
        final client = FakeRewardClient()..answer = null;
        expect(await GameRewardRepository(client).report('ball', 1), isNull);
        client.answer = (_) => 'nope';
        expect(await GameRewardRepository(client).report('ball', 1), isNull);
      },
    );
  });

  group('GameRound', () {
    test('records locally, reports once, shows the grant', () async {
      final w = GamesWorld();
      final c = await w.container();
      final round = GameRound(c.read, ZadGame.zadoSort)..end(120);
      await round.claim();
      await round.claim();
      expect(w.client.calls, hasLength(1));
      expect(round.grant!.granted, 5);
      expect(round.score, 120);
    });

    test('doubling: an ad, then the call again with doubled', () async {
      final w = GamesWorld();
      final c = await w.container();
      final round = GameRound(c.read, ZadGame.ball)..end(10);
      w.client.answer = (p) => <String, Object?>{
        'granted': p['p_doubled'] == true ? 10 : 5,
        'remaining': 15,
      };
      await round.doubleSeeds();
      expect(w.ads.watched, 1);
      expect(w.client.calls.map((e) => e['p_doubled']), <bool>[false, true]);
      expect(round.doubled, isTrue);
      expect(round.grant!.granted, 10);
      // Only once.
      await round.doubleSeeds();
      expect(w.ads.watched, 1);
    });

    test('doubling without the reward changes nothing', () async {
      final w = GamesWorld(ads: FakeRewarded(RewardedOutcome.dismissed));
      final c = await w.container();
      final round = GameRound(c.read, ZadGame.ball)..end(10);
      await round.doubleSeeds();
      expect(round.doubled, isFalse);
      expect(w.client.calls, hasLength(1));
    });

    test('offline: the round still ends, no grant, nothing queued', () async {
      final w = GamesWorld();
      w.client.answer = null;
      final c = await w.container();
      final round = GameRound(c.read, ZadGame.ball)..end(10);
      await round.claim();
      expect(round.grant, isNull);
      expect(round.busy, isFalse);
    });
  });
}
