import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'package:zad/core/data/local/boxes.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/shared/ads/application/ads_policy.dart';
import 'package:zad/shared/ads/data/rewarded_ads.dart';
import 'package:zad/shared/auth/application/session_controller.dart';
import 'package:zad/shared/companion/application/game_stats_controller.dart';
import 'package:zad/shared/companion/application/pet_care_controller.dart';
import 'package:zad/shared/companion/data/companion_remote.dart';
import 'package:zad/shared/companion/data/game_reward_remote.dart';
import 'package:zad/shared/companion/domain/zad_game.dart';
import 'package:zad/shared/companion/presentation/companion_pet.dart';
import 'package:zad/shared/companion/presentation/pet_run_game.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/navigation/zad_screens.dart';
import 'package:zad/shared/orb/application/orb_accessory_controller.dart';
import 'package:zad/shared/orb/domain/orb_accessory.dart';
import 'package:zad/shared/orb/presentation/companion_orb.dart';

import 'companion_fakes.dart';

class _NoAccessory extends OrbAccessoryController {
  @override
  OrbAccessory build() => OrbAccessory.none;
}

class _FakeAds implements RewardedAds {
  new(this.outcome);

  RewardedOutcome outcome;
  int watched = 0;

  @override
  Future<RewardedOutcome> watch({required String userId}) async {
    watched++;
    return outcome;
  }
}

class _FakeClient implements GameRewardClient {
  @override
  Future<Object?> rpc(String fn, Map<String, Object?> params) async =>
      <String, Object?>{'granted': 5, 'remaining': 20};
}

void main() {
  late Directory dir;
  late Box<String> device;
  var run = 0;
  var now = DateTime.utc(2026, 11, 15, 12);

  setUpAll(tzdata.initializeTimeZones);

  setUp(() async {
    run++;
    now = DateTime.utc(2026, 11, 15, 12);
    dir = await Directory.systemTemp.createTemp('zad_run');
    Hive.init(dir.path);
    device = await Hive.openBox<String>('run_device$run');
  });

  tearDownAll(() => dir.delete(recursive: true).ignore());

  ProviderContainer containerFor({
    bool ads = true,
    _FakeAds? fake,
    String zone = 'Africa/Cairo',
  }) {
    final c = ProviderContainer(
      overrides: [
        localStoreProvider.overrideWithValue(
          ZadLocalStore(
            outbox: device,
            transactions: device,
            documents: device,
            chat: device,
            inventory: device,
            shopping: device,
            pharmacy: device,
            subscriptions: device,
            device: device,
          ),
        ),
        sessionControllerProvider.overrideWith(SignedIn.new),
        companionRemoteProvider.overrideWithValue(
          FakeCompanionRemote(statusJson()),
        ),
        orbAccessoryProvider.overrideWith(_NoAccessory.new),
        petClockProvider.overrideWithValue(() => now),
        accountTimeZoneProvider.overrideWithValue(zone),
        adsAllowedProvider.overrideWithValue(ads),
        rewardedAdsProvider.overrideWithValue(
          fake ?? _FakeAds(RewardedOutcome.earned),
        ),
        gameRewardRepositoryProvider.overrideWithValue(
          GameRewardRepository(_FakeClient()),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> pumpApp(
    WidgetTester tester,
    ProviderContainer c,
    Widget child,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: child),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// Frames without a jump until Zado hits a crate.
  Future<void> runUntilHit(WidgetTester tester) async {
    final card = find.byKey(const ValueKey<String>('game-end-card'));
    for (var i = 0; i < 900 && card.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(card, findsOneWidget);
  }

  const field = ValueKey<String>('run-field');
  const hint = ValueKey<String>('run-hint');
  const cont = ValueKey<String>('game-continue');

  testWidgets('the care sheet has the games button and it opens the hub', (
    tester,
  ) async {
    final c = containerFor();
    var opened = 0;
    ZadScreens.showGamesHub = (_) async => opened++;
    await pumpApp(tester, c, const CompanionCareSheet());
    final button = find.byKey(const ValueKey<String>('pet-games'));
    await tester.ensureVisible(button);
    expect(
      find.descendant(of: button, matching: find.text('ألعاب زادو')),
      findsOne,
    );
    await tester.tap(button);
    await tester.pump();
    expect(opened, 1);
  });

  testWidgets("the user's own companion runs", (tester) async {
    final c = containerFor();
    await pumpApp(tester, c, PetRunGame(name: 'زادو', rng: math.Random(1)));
    expect(
      tester.widget<CompanionOrb>(find.byType(CompanionOrb)).look,
      isNotNull,
    );
  });

  testWidgets('a tap starts the run and lifts Zado off the ground', (
    tester,
  ) async {
    final c = containerFor();
    await pumpApp(tester, c, PetRunGame(name: 'زادو', rng: math.Random(1)));
    final ground = tester.getTopLeft(find.byType(CompanionOrb)).dy;
    await tester.tap(find.byKey(field));
    await tester.pump();
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.byKey(hint), findsNothing);
    expect(tester.getTopLeft(find.byType(CompanionOrb)).dy, lessThan(ground));
    // And back down within a second.
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.getTopLeft(find.byType(CompanionOrb)).dy, closeTo(ground, 1));
    await runUntilHit(tester);
  });

  testWidgets('a hit shows the end card: score, best, challenge, streak', (
    tester,
  ) async {
    final c = containerFor();
    await pumpApp(tester, c, PetRunGame(name: 'زادو', rng: math.Random(1)));
    await tester.tap(find.byKey(field));
    await runUntilHit(tester);
    final score = int.parse(
      tester
          .widget<Text>(find.byKey(const ValueKey<String>('game-end-score')))
          .data!
          .split(' ')
          .first,
    );
    expect(score, greaterThan(0));
    expect(find.byKey(const ValueKey<String>('game-end-best')), findsOne);
    expect(find.byKey(const ValueKey<String>('game-end-challenge')), findsOne);
    expect(find.byKey(const ValueKey<String>('game-end-streak')), findsOne);
    expect(c.read(gameStatsProvider(ZadGame.zadoRun.id)).best, score);
    expect(
      c.read(gameStatsProvider(ZadGame.zadoRun.id)).streakOn('2026-11-15'),
      1,
    );
    expect(find.byKey(cont), findsOneWidget);
  });

  testWidgets('continue resumes the same round once, and only when earned', (
    tester,
  ) async {
    final fake = _FakeAds(RewardedOutcome.dismissed);
    final c = containerFor(fake: fake);
    await pumpApp(tester, c, PetRunGame(name: 'زادو', rng: math.Random(1)));
    await tester.tap(find.byKey(field));
    await runUntilHit(tester);
    final scoreAtHit = c.read(gameStatsProvider(ZadGame.zadoRun.id)).best;

    // Closed before the reward: nothing resumes.
    await tester.tap(find.byKey(cont));
    await tester.pump();
    expect(fake.watched, 1);
    expect(find.byKey(const ValueKey<String>('game-end-card')), findsOne);
    expect(find.byKey(cont), findsOneWidget);

    // Earned: the card goes, the round runs on from the same score.
    fake.outcome = RewardedOutcome.earned;
    await tester.tap(find.byKey(cont));
    await tester.pump();
    expect(fake.watched, 2);
    expect(find.byKey(const ValueKey<String>('game-end-card')), findsNothing);
    final shown = int.parse(
      tester
          .widget<Text>(find.byKey(const ValueKey<String>('run-score')))
          .data!,
    );
    expect(shown, greaterThanOrEqualTo(scoreAtHit));
    expect(shown, lessThan(scoreAtHit + 5));

    // The second hit offers no second continue.
    await runUntilHit(tester);
    expect(find.byKey(cont), findsNothing);
    expect(fake.watched, 2);
    expect(
      c.read(gameStatsProvider(ZadGame.zadoRun.id)).best,
      greaterThan(scoreAtHit),
    );
  });

  testWidgets('no continue when ads are not allowed, and no ad is asked for', (
    tester,
  ) async {
    final fake = _FakeAds(RewardedOutcome.earned);
    final c = containerFor(ads: false, fake: fake);
    await pumpApp(tester, c, PetRunGame(name: 'زادو', rng: math.Random(1)));
    await tester.tap(find.byKey(field));
    await runUntilHit(tester);
    expect(find.byKey(cont), findsNothing);
    expect(find.byKey(const ValueKey<String>('game-again')), findsOneWidget);
    expect(fake.watched, 0);
  });

  testWidgets('no ad is shown while playing', (tester) async {
    final fake = _FakeAds(RewardedOutcome.earned);
    final c = containerFor(fake: fake);
    await pumpApp(tester, c, PetRunGame(name: 'زادو', rng: math.Random(1)));
    await tester.tap(find.byKey(field));
    await runUntilHit(tester);
    expect(fake.watched, 0);
  });

  group('the market day', () {
    test('challenge and streak roll over at the market midnight', () {
      // 22:30 UTC is 00:30 the next day in Cairo (UTC+2).
      now = DateTime.utc(2026, 11, 15, 21, 30);
      final c = containerFor();
      c
          .read(gameStatsProvider(ZadGame.zadoRun.id).notifier)
          .record(ZadGame.zadoRun.dailyTarget('2026-11-15'));
      final cairoToday = c
          .read(gameStatsProvider(ZadGame.zadoRun.id).notifier)
          .today();
      expect(cairoToday, '2026-11-15');
      expect(
        c
            .read(gameStatsProvider(ZadGame.zadoRun.id))
            .challengeDone(cairoToday, ZadGame.zadoRun.dailyTarget(cairoToday)),
        isTrue,
      );

      now = DateTime.utc(2026, 11, 15, 22, 30);
      final next = c
          .read(gameStatsProvider(ZadGame.zadoRun.id).notifier)
          .today();
      expect(next, '2026-11-16');
      expect(
        c.read(gameStatsProvider(ZadGame.zadoRun.id)).challengeProgress(next),
        0,
      );
      expect(c.read(gameStatsProvider(ZadGame.zadoRun.id)).streakOn(next), 1);
      c.read(gameStatsProvider(ZadGame.zadoRun.id).notifier).record(40);
      expect(c.read(gameStatsProvider(ZadGame.zadoRun.id)).streakOn(next), 2);
      expect(
        c.read(gameStatsProvider(ZadGame.zadoRun.id)).best,
        ZadGame.zadoRun.dailyTarget('2026-11-15'),
      );
    });

    test('the zone, not the device, decides the day', () {
      now = DateTime.utc(2026, 11, 15, 22, 30);
      final cairo = containerFor();
      final la = containerFor(zone: 'America/Los_Angeles');
      expect(
        cairo.read(gameStatsProvider(ZadGame.zadoRun.id).notifier).today(),
        '2026-11-16',
      );
      expect(
        la.read(gameStatsProvider(ZadGame.zadoRun.id).notifier).today(),
        '2026-11-15',
      );
    });

    test('the stats come back from the device box, per account', () {
      final c = containerFor();
      c.read(gameStatsProvider(ZadGame.zadoRun.id).notifier).record(150);
      final again = containerFor();
      expect(again.read(gameStatsProvider(ZadGame.zadoRun.id)).best, 150);
    });
  });
}
