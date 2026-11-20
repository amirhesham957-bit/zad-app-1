import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/features/companion/presentation/games_hub.dart';
import 'package:zad/shared/companion/application/game_stats_controller.dart';
import 'package:zad/shared/companion/domain/zad_game.dart';

import '../../shared/companion/games_kit.dart';

void main() {
  const phone = Size(360, 640);

  testWidgets('the hub lists the four games at 360x640 with no overflow', (
    tester,
  ) async {
    final c = await GamesWorld().containerIn(tester);
    await pumpGame(
      tester,
      c,
      const Scaffold(body: ZadGamesHubBody()),
      size: phone,
    );
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey<String>('games-hero')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('games-flame')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('games-weekly')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('games-today')), findsOneWidget);
    for (final g in ZadGame.values) {
      final card = find.byKey(ValueKey<String>('game-card-${g.id}'));
      await tester.scrollUntilVisible(card, 120);
      await tester.ensureVisible(card);
      expect(card, findsOneWidget);
      // Tap target at least 44dp.
      expect(tester.getSize(card).height, greaterThanOrEqualTo(44));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('a game with a score shows its best; a new one says so', (
    tester,
  ) async {
    final c = await GamesWorld().containerIn(tester);
    c.read(gameStatsProvider(ZadGame.zadoRun.id).notifier).record(222);
    await pumpGame(
      tester,
      c,
      const Scaffold(body: ZadGamesHubBody()),
      size: phone,
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey<String>('game-best-zado_run')),
          )
          .data,
      contains('222'),
    );
    final other = find.byKey(const ValueKey<String>('game-best-ball'));
    await tester.scrollUntilVisible(other, 120);
    expect(tester.widget<Text>(other).data, 'لسه ما لعبتش');
    // One day played: the streak says one day.
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey<String>('games-streak')))
          .data,
      'يوم واحد',
    );
  });

  testWidgets('tapping a card opens that game', (tester) async {
    final c = await GamesWorld().containerIn(tester);
    ZadGame? opened;
    await pumpGame(
      tester,
      c,
      Scaffold(body: ZadGamesHubBody(onOpen: (g) => opened = g)),
      size: phone,
    );
    final card = find.byKey(const ValueKey<String>('game-card-zado_sort'));
    await tester.scrollUntilVisible(card, 120);
    await tester.ensureVisible(card);
    await tester.pump();
    await tester.tap(card);
    expect(opened, ZadGame.zadoSort);
  });

  testWidgets('the screen has a visible back button', (tester) async {
    final c = await GamesWorld().containerIn(tester);
    await pumpGame(tester, c, const GamesHubScreen(), size: phone);
    expect(find.byKey(const ValueKey<String>('games-back')), findsOneWidget);
    expect(find.text('ألعاب زادو'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
