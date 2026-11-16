/// «ألعاب زادو»: the companion's games corner. Four games that have nothing
/// to do with prices, a challenge for today, the day-streak flame and the
/// weekly box (owner, 2026-11-15). The hub only lists and opens; each game
/// reports its own rounds (`GameRound`) and the server grants the seeds.
///
/// `ZadGamesHubBody` is the page's content on its own, so it can sit inside
/// the shared world scaffold later; [GamesHubScreen] wraps it in a plain
/// `Scaffold` with a back button for now.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/shared/companion/application/companion_controller.dart';
import 'package:zad/shared/companion/application/game_stats_controller.dart';
import 'package:zad/shared/companion/domain/game_stats.dart';
import 'package:zad/shared/companion/domain/zad_game.dart';
import 'package:zad/shared/companion/presentation/game_art.dart';
import 'package:zad/shared/companion/presentation/pet_ball_game.dart';
import 'package:zad/shared/companion/presentation/pet_run_game.dart';
import 'package:zad/shared/companion/presentation/star_catch_game.dart';
import 'package:zad/shared/companion/presentation/zado_sort_game.dart';

/// Opens the hub.
Future<void> showGamesHub(BuildContext context) => Navigator.of(
  context,
).push<void>(MaterialPageRoute<void>(builder: (_) => const GamesHubScreen()));

/// The hub on its own page.
class GamesHubScreen extends StatelessWidget {
  /// Creates it.
  const new({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ZadColors.surface,
    appBar: AppBar(
      leading: BackButton(
        key: const ValueKey<String>('games-back'),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: Text(context.l10n.gamesHubTitle),
    ),
    body: const SafeArea(child: ZadGamesHubBody()),
  );
}

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

/// The hub's content: header with today's challenge, then the game cards.
class ZadGamesHubBody extends ConsumerWidget {
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
    final week = streak > weeklyBoxDays ? weeklyBoxDays : streak;
    return ListView(
      padding: const EdgeInsets.all(ZadSpacing.lg),
      children: <Widget>[
        Container(
          key: const ValueKey<String>('games-hero'),
          padding: const EdgeInsets.all(ZadSpacing.lg),
          decoration: BoxDecoration(
            color: ZadColors.forestEmerald,
            borderRadius: BorderRadius.circular(ZadRadii.cardLarge),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      l.gamesHubIntro,
                      style: ZadType.titleMedium.copyWith(
                        color: ZadColors.surface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  FlameIcon(
                    key: const ValueKey<String>('games-flame'),
                    lit: streak > 0,
                    size: 32,
                  ),
                ],
              ),
              const SizedBox(height: ZadSpacing.xs),
              Text(
                l.gamesHubStreak(streak),
                key: const ValueKey<String>('games-streak'),
                style: ZadType.bodyMedium.copyWith(color: ZadColors.mint100),
              ),
              const SizedBox(height: ZadSpacing.md),
              _Bar(
                key: const ValueKey<String>('games-today'),
                label: stats[featured]!.challengeDone(today, fTarget)
                    ? l.gamesHubChallengeDone
                    : l.gamesHubToday(fTarget, _nameOf(featured, l)),
                value: fProgress / fTarget,
              ),
              const SizedBox(height: ZadSpacing.sm),
              _Bar(
                key: const ValueKey<String>('games-weekly'),
                label: l.gamesHubWeekly(week, weeklyBoxDays),
                value: week / weeklyBoxDays,
              ),
            ],
          ),
        ),
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
    );
  }
}

class _Bar extends StatelessWidget {
  const new({required this.label, required this.value, super.key});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(label, style: ZadType.bodySmall.copyWith(color: ZadColors.surface)),
      const SizedBox(height: ZadSpacing.xs),
      ClipRRect(
        borderRadius: BorderRadius.circular(ZadRadii.pill),
        child: LinearProgressIndicator(
          minHeight: 8,
          value: value.clamp(0, 1).toDouble(),
          color: ZadColors.mustardOchre,
          backgroundColor: const Color(0x33FFFFFF),
        ),
      ),
    ],
  );
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
    final done = stats.challengeDone(today, game.dailyTarget(today));
    return Semantics(
      button: true,
      label: _nameOf(game, l),
      excludeSemantics: true,
      onTap: onPlay,
      child: Material(
        color: ZadColors.mint100,
        borderRadius: BorderRadius.circular(ZadRadii.card),
        child: InkWell(
          key: ValueKey<String>('game-card-${game.id}'),
          borderRadius: BorderRadius.circular(ZadRadii.card),
          onTap: onPlay,
          child: Padding(
            padding: const EdgeInsets.all(ZadSpacing.md),
            child: Row(
              children: <Widget>[
                GameEmblem(game: game),
                const SizedBox(width: ZadSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _nameOf(game, l),
                        style: ZadType.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: ZadSpacing.xs),
                      Text(
                        _blurbOf(game, l),
                        style: ZadType.bodySmall.copyWith(
                          color: ZadColors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: ZadSpacing.sm),
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              stats.best > 0
                                  ? l.gamesHubBest(stats.best)
                                  : l.gamesHubNotPlayed,
                              key: ValueKey<String>('game-best-${game.id}'),
                              style: ZadType.labelMedium,
                            ),
                          ),
                          if (done) ...<Widget>[
                            const SizedBox(width: ZadSpacing.sm),
                            Icon(
                              Icons.check_circle,
                              size: 16,
                              color: ZadColors.forestEmerald,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: ZadSpacing.sm),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 64,
                    minHeight: 48,
                  ),
                  child: FilledButton(
                    onPressed: onPlay,
                    child: Text(l.gamesHubPlay),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
