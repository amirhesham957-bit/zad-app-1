/// «ألعاب زادو» as a world: the violet scene with the companion, the day
/// streak as the state line, today's challenge and the weekly box, then one
/// card per game with its drawing and best score. The hub only lists and
/// opens; each game reports its own rounds (`GameRound`) and the server
/// grants the seeds.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/companion/presentation/games_world_scene.dart';
import 'package:zad/shared/companion/application/companion_controller.dart';
import 'package:zad/shared/companion/application/game_stats_controller.dart';
import 'package:zad/shared/companion/domain/game_stats.dart';
import 'package:zad/shared/companion/domain/zad_game.dart';
import 'package:zad/shared/companion/presentation/game_art.dart';
import 'package:zad/shared/companion/presentation/pet_ball_game.dart';
import 'package:zad/shared/companion/presentation/pet_run_game.dart';
import 'package:zad/shared/companion/presentation/star_catch_game.dart';
import 'package:zad/shared/companion/presentation/zado_sort_game.dart';
import 'package:zad/shared/orb/domain/companion_state.dart';
import 'package:zad/shared/worlds/art/art.dart';
import 'package:zad/shared/worlds/world_card.dart';
import 'package:zad/shared/worlds/world_row.dart';
import 'package:zad/shared/worlds/world_scaffold.dart';
import 'package:zad/shared/worlds/zad_world.dart';

/// Opens the hub.
Future<void> showGamesHub(BuildContext context) => Navigator.of(
  context,
).push<void>(MaterialPageRoute<void>(builder: (_) => const GamesHubScreen()));

String _nameOf(ZadGame g, ZadL10n l) => switch (g) {
  ZadGame.ball => l.gameNameBall,
  ZadGame.zadoRun => l.gameNameRun,
  ZadGame.zadoSort => l.gameNameSort,
  ZadGame.starCatch => l.gameNameStar,
};

String _blurbOf(ZadGame g, ZadL10n l) => switch (g) {
  ZadGame.ball => l.gameBlurbBall,
  ZadGame.zadoRun => l.gameBlurbRun,
  ZadGame.zadoSort => l.gameBlurbSort,
  ZadGame.starCatch => l.gameBlurbStar,
};

/// The hub.
class GamesHubScreen extends ConsumerWidget {
  /// Creates it. [onOpen] replaces opening the game (tests).
  const new({this.onOpen, super.key});

  /// Called instead of opening the game; null opens it.
  final void Function(ZadGame game)? onOpen;

  void _open(BuildContext context, WidgetRef ref, ZadGame game) {
    if (onOpen != null) return onOpen!(game);
    final name =
        ref.read(companionProvider).value?.persona.name ?? 'زادو'; // l10n: data
    switch (game) {
      case ZadGame.ball:
        unawaited(showPetBallGame(context, name: name));
      case ZadGame.zadoRun:
        unawaited(showPetRunGame(context, name: name));
      case ZadGame.zadoSort:
        unawaited(showZadoSortGame(context));
      case ZadGame.starCatch:
        unawaited(showStarCatchGame(context, name: name));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final stats = <ZadGame, GameStats>{
      for (final g in ZadGame.values) g: ref.watch(gameStatsProvider(g.id)),
    };
    final today = ref
        .read(gameStatsProvider(ZadGame.zadoRun.id).notifier)
        .today();
    final streak = stats.values.fold<int>(
      0,
      (a, s) => s.streakOn(today) > a ? s.streakOn(today) : a,
    );
    // One game is today's featured challenge; the rest still count.
    final featured =
        ZadGame.values[today.codeUnits.fold<int>(0, (a, c) => a + c) %
            ZadGame.values.length];
    final fTarget = featured.dailyTarget(today);
    final fProgress = stats[featured]!.challengeProgress(today);
    final fDone = stats[featured]!.challengeDone(today, fTarget);
    final week = streak > weeklyBoxDays ? weeklyBoxDays : streak;
    final neverPlayed = stats.values.every((s) => s.best == 0);
    final color = ZadWorld.games.color;
    return Scaffold(
      backgroundColor: ZadColors.canvasMid,
      body: SafeArea(
        bottom: false,
        child: ZadWorldScaffold(
          world: ZadWorld.games,
          showBack: true,
          eyebrow: l.gamesHubIntro,
          title: l.worldLabelGames,
          stateLine: l.gamesHubStreak(streak),
          scene: (loop) => GamesWorldScene(loop, streak: streak),
          zado: ZadWorldZado(
            left: 60,
            state: fDone ? CompanionState.celebrating : CompanionState.happy,
          ),
          slivers: <Widget>[
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: ZadSpacing.gutter,
              ),
              sliver: SliverList.list(
                children: <Widget>[
                  ZadWorldCard(
                    key: const ValueKey<String>('games-today'),
                    child: ZadWorldRow(
                      leading: ZadWorldTile(
                        color: color,
                        child: ZadArt.icon(ZadIconArt.star, size: 28),
                      ),
                      title: fDone
                          ? l.gamesHubChallengeDone
                          : l.gamesHubToday(fTarget, _nameOf(featured, l)),
                      stateColor: color,
                      progress: fProgress / fTarget,
                    ),
                  ),
                  const SizedBox(height: ZadSpacing.md),
                  ZadWorldCard(
                    key: const ValueKey<String>('games-weekly'),
                    child: ZadWorldRow(
                      leading: ZadWorldTile(
                        color: color,
                        child: FlameIcon(
                          key: const ValueKey<String>('games-flame'),
                          lit: streak > 0,
                          size: 28,
                        ),
                      ),
                      title: l.gamesHubWeekly(week, weeklyBoxDays),
                      stateColor: color,
                      progress: week / weeklyBoxDays,
                    ),
                  ),
                  if (neverPlayed) ...<Widget>[
                    const SizedBox(height: ZadSpacing.md),
                    ZadWorldCard(
                      key: const ValueKey<String>('games-empty'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(l.gamesWorldEmpty, style: ZadType.titleSmall),
                          const SizedBox(height: ZadSpacing.xs),
                          Text(
                            l.gamesWorldEmptyHint,
                            style: ZadType.bodySmall.copyWith(
                              color: ZadColors.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: ZadSpacing.lg),
                  for (final g in ZadGame.values) ...<Widget>[
                    _GameCard(
                      game: g,
                      stats: stats[g]!,
                      today: today,
                      onPlay: () => _open(context, ref, g),
                    ),
                    const SizedBox(height: ZadSpacing.md),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const new({
    required this.game,
    required this.stats,
    required this.today,
    required this.onPlay,
  });

  final ZadGame game;
  final GameStats stats;
  final String today;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final color = ZadWorld.games.color;
    final done = stats.challengeDone(today, game.dailyTarget(today));
    return Semantics(
      button: true,
      label: _nameOf(game, l),
      excludeSemantics: true,
      onTap: onPlay,
      child: ZadWorldCard(
        key: ValueKey<String>('game-card-${game.id}'),
        onTap: onPlay,
        child: Row(
          children: <Widget>[
            GameEmblem(game: game),
            const SizedBox(width: ZadSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(_nameOf(game, l), style: ZadType.titleSmall),
                  Text(
                    _blurbOf(game, l),
                    style: ZadType.labelSmall.copyWith(
                      color: ZadColors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: ZadSpacing.xs),
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          stats.best > 0
                              ? l.gamesHubBest(stats.best)
                              : l.gamesHubNotPlayed,
                          key: ValueKey<String>('game-best-${game.id}'),
                          style: ZadType.labelMedium.copyWith(
                            color: color,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (done) ...<Widget>[
                        const SizedBox(width: ZadSpacing.xs),
                        Icon(
                          Icons.check_circle_rounded,
                          size: 16,
                          color: color,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: ZadSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 64, minHeight: 48),
              child: FilledButton(
                onPressed: onPlay,
                style: FilledButton.styleFrom(
                  backgroundColor: color,
                  minimumSize: const Size(64, 48),
                ),
                child: Text(l.gamesHubPlay),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
