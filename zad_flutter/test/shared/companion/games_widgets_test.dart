import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/features/companion/presentation/games_hub.dart';
import 'package:zad/shared/companion/application/game_stats_controller.dart';
import 'package:zad/shared/companion/domain/run_game.dart';
import 'package:zad/shared/companion/domain/zad_game.dart';
import 'package:zad/shared/companion/presentation/pet_run_game.dart';
import 'package:zad/shared/companion/presentation/star_catch_game.dart';
import 'package:zad/shared/companion/presentation/zado_sort_game.dart';
import 'package:zad/shared/orb/presentation/companion_orb.dart';

import '../../support/fonts.dart';
import 'games_kit.dart';

const Size _phone = Size(360, 640);
const ValueKey<String> _card = ValueKey<String>('game-end-card');

Future<void> _playStarsOut(WidgetTester tester) async {
  await tester.drag(
    find.byKey(const ValueKey<String>('star-field')),
    const Offset(-120, 0),
  );
  for (var i = 0; i < 6000 && find.byKey(_card).evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _tapSortOut(WidgetTester tester) async {
  const order = <String>['left', 'down', 'right', 'up'];
  for (var i = 0; i < 4000 && find.byKey(_card).evaluate().isEmpty; i++) {
    final b = find.byKey(ValueKey<String>('sort-${order[i % 4]}'));
    await tester.tap(b, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 10));
  }
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  group('star catch', () {
    testWidgets('a round ends with the card, the seeds and the stats', (
      tester,
    ) async {
      final w = GamesWorld();
      final c = await w.containerIn(tester);
      await pumpGame(
        tester,
        c,
        StarCatchGame(name: 'زادو', rng: math.Random(3)),
        size: _phone,
      );
      expect(
        tester.widget<CompanionOrb>(find.byType(CompanionOrb)).look,
        isNotNull,
      );
      await _playStarsOut(tester);
      expect(find.byKey(_card), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(c.read(gameStatsProvider(ZadGame.starCatch.id)).streak, 1);
      expect(w.client.calls.single['p_game'], 'star_catch');
      expect(
        find.byKey(const ValueKey<String>('game-end-seeds')),
        findsOneWidget,
      );
      // Not a kid: the doubling is offered, once the server granted seeds.
      expect(find.byKey(const ValueKey<String>('game-double')), findsOne);
      await tester.tap(find.byKey(const ValueKey<String>('game-double')));
      await tester.pump();
      await tester.pump();
      expect(w.ads.watched, 1);
      expect(w.client.calls.last['p_doubled'], isTrue);
    });

    testWidgets('no double button when the round paid nothing', (tester) async {
      final w = GamesWorld();
      w.client.answer = (_) => <String, Object?>{'granted': 0, 'remaining': 20};
      final c = await w.containerIn(tester);
      await pumpGame(
        tester,
        c,
        StarCatchGame(name: 'زادو', rng: math.Random(3)),
        size: _phone,
      );
      await _playStarsOut(tester);
      expect(find.byKey(_card), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('game-double')), findsNothing);
    });

    testWidgets('kids mode: no continue and no double button', (tester) async {
      final w = GamesWorld(kids: true);
      final c = await w.containerIn(tester);
      await pumpGame(
        tester,
        c,
        StarCatchGame(name: 'زادو', rng: math.Random(3)),
        size: _phone,
      );
      await _playStarsOut(tester);
      expect(find.byKey(_card), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('game-double')), findsNothing);
      expect(find.byKey(const ValueKey<String>('game-continue')), findsNothing);
      expect(w.ads.watched, 0);
      // The seeds are still reported: kids play for them too.
      expect(w.client.calls, hasLength(1));
    });

    testWidgets('the app leaving pauses the round until resumed', (
      tester,
    ) async {
      final c = await GamesWorld().containerIn(tester);
      await pumpGame(
        tester,
        c,
        StarCatchGame(name: 'زادو', rng: math.Random(3)),
        size: _phone,
      );
      await tester.drag(
        find.byKey(const ValueKey<String>('star-field')),
        const Offset(10, 0),
      );
      await tester.pump(const Duration(milliseconds: 100));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      // The app comes back; the round still waits for the tap.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.byKey(const ValueKey<String>('game-paused')), findsOneWidget);
      // Coming back: frames run again, the veil waits for a tap.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('game-resume')));
      await tester.pump();
      expect(find.byKey(const ValueKey<String>('game-paused')), findsNothing);
      await tester.pump(const Duration(milliseconds: 50));
    });
  });

  group('zado sorts', () {
    testWidgets('the first board of the day is the daily puzzle', (
      tester,
    ) async {
      final c = await GamesWorld().containerIn(tester);
      await pumpGame(tester, c, const ZadoSortGame(), size: _phone);
      expect(find.byKey(const ValueKey<String>('sort-daily')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey<String>('sort-left')));
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('a played-out board ends with the card and the seeds', (
      tester,
    ) async {
      final w = GamesWorld();
      final c = await w.containerIn(tester);
      await pumpGame(
        tester,
        c,
        ZadoSortGame(rng: math.Random(4)),
        size: _phone,
      );
      await _tapSortOut(tester);
      expect(find.byKey(_card), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(w.client.calls.single['p_game'], 'zado_sort');
      expect(
        c.read(gameStatsProvider(ZadGame.zadoSort.id)).best,
        greaterThan(0),
      );
    });
  });

  // For the owner's review only: ZAD_SCREENS=1 flutter test
  // --update-goldens test/shared/companion/games_widgets_test.dart writes
  // build/screens/games_hub.png and games_run.png.
  group('screenshots', () {
    testWidgets('the games hub', (tester) async {
      await loadZadFonts();
      final c = await GamesWorld().containerIn(tester);
      c.read(gameStatsProvider(ZadGame.zadoRun.id).notifier).record(180);
      await pumpGame(tester, c, const GamesHubScreen(), size: _phone);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../../../build/screens/games_hub.png'),
      );
    });

    testWidgets('the runner mid-game', (tester) async {
      await loadZadFonts();
      final c = await GamesWorld().containerIn(tester);
      final game = RunGame(rng: math.Random(5));
      for (var i = 0; i < 90; i++) {
        if (i == 30 || i == 70) game.jump();
        game.step(1 / 60);
      }
      await pumpGame(
        tester,
        c,
        PetRunGame(name: 'زادو', game: game, startedForTest: true),
        size: _phone,
      );
      await tester.pump(const Duration(milliseconds: 50));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../../../build/screens/games_run.png'),
      );
    });
  }, skip: Platform.environment['ZAD_SCREENS'] != '1');
}
