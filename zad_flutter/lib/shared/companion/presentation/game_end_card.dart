/// The card every game shows when a round ends: score, best, today's
/// challenge, the streak, the seeds the server gave, «ضاعف البذور», and the
/// way on. Ad buttons are there only when [GameEndCard.adsAllowed] (never in
/// kids mode, never on a paid plan — `adsAllowedProvider`).
library;

import 'package:flutter/material.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/shared/companion/application/game_round.dart';
import 'package:zad/shared/companion/domain/game_stats.dart';
import 'package:zad/shared/companion/presentation/game_art.dart';

/// The end-of-round card.
class GameEndCard extends StatelessWidget {
  /// Creates it.
  const new({
    required this.round,
    required this.stats,
    required this.today,
    required this.title,
    required this.newBest,
    required this.adsAllowed,
    required this.onAgain,
    required this.onLeave,
    this.onContinue,
    this.continueBusy = false,
    this.continueNoAd = false,
    super.key,
  });

  /// The round, for the seeds.
  final GameRound round;

  /// The game's stats after the round.
  final GameStats stats;

  /// The market day.
  final String today;

  /// «خبط!», «النجوم خلصت منك»…
  final String title;

  /// The best was beaten.
  final bool newBest;

  /// Ad buttons may show.
  final bool adsAllowed;

  /// Another round.
  final VoidCallback onAgain;

  /// Leave.
  final VoidCallback onLeave;

  /// «كمّل من مكانك», when the game offers it; null hides the button.
  final VoidCallback? onContinue;

  /// The continue ad is loading.
  final bool continueBusy;

  /// The continue ad did not play.
  final bool continueNoAd;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final target = round.game.dailyTarget(today);
    final progress = stats.challengeProgress(today);
    final done = stats.challengeDone(today, target);
    final streak = stats.streakOn(today);
    final canContinue = adsAllowed && onContinue != null;
    return Container(
      key: const ValueKey<String>('game-end-card'),
      padding: const EdgeInsets.all(ZadSpacing.xl),
      decoration: BoxDecoration(
        color: ZadColors.surface,
        borderRadius: BorderRadius.circular(ZadRadii.sheet),
      ),
      child: ListenableBuilder(
        listenable: round,
        builder: (context, _) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              title,
              textAlign: TextAlign.center,
              style: ZadType.titleMedium.copyWith(
                color: ZadColors.textTertiary,
              ),
            ),
            const SizedBox(height: ZadSpacing.xs),
            Text(
              l.gameEndScore(round.score),
              key: const ValueKey<String>('game-end-score'),
              textAlign: TextAlign.center,
              style: ZadType.headlineLarge.copyWith(
                fontWeight: FontWeight.w800,
                color: ZadColors.forestEmerald,
              ),
            ),
            Text(
              newBest ? l.gameNewBest : l.gameBest(stats.best),
              key: const ValueKey<String>('game-end-best'),
              textAlign: TextAlign.center,
              style: ZadType.bodyMedium.copyWith(
                color: newBest
                    ? ZadColors.mustardOchre
                    : ZadColors.textTertiary,
                fontWeight: newBest ? FontWeight.w700 : null,
              ),
            ),
            _Seeds(round: round),
            const SizedBox(height: ZadSpacing.lg),
            Text(l.gameChallenge(target), style: ZadType.titleSmall),
            const SizedBox(height: ZadSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(ZadRadii.pill),
              child: LinearProgressIndicator(
                key: const ValueKey<String>('game-end-challenge'),
                minHeight: 8,
                value: (progress / target).clamp(0, 1).toDouble(),
                color: ZadColors.forestEmerald,
                backgroundColor: ZadColors.mint100,
              ),
            ),
            const SizedBox(height: ZadSpacing.xs),
            Text(
              done
                  ? l.gameChallengeDone
                  : l.gameChallengeProgress(progress, target),
              key: const ValueKey<String>('game-end-challenge-text'),
              style: ZadType.bodySmall.copyWith(color: ZadColors.textTertiary),
            ),
            const SizedBox(height: ZadSpacing.md),
            Row(
              children: <Widget>[
                FlameIcon(lit: streak > 0),
                const SizedBox(width: ZadSpacing.sm),
                Text(
                  l.gamesHubStreak(streak),
                  key: const ValueKey<String>('game-end-streak'),
                  style: ZadType.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: ZadSpacing.lg),
            if (canContinue) ...<Widget>[
              FilledButton(
                key: const ValueKey<String>('game-continue'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: continueBusy ? null : onContinue,
                child: Text(l.gameContinue),
              ),
              const SizedBox(height: ZadSpacing.xs),
              Text(
                continueNoAd ? l.gameAdUnavailable : l.gameContinueHint,
                textAlign: TextAlign.center,
                style: ZadType.bodySmall.copyWith(
                  color: ZadColors.textTertiary,
                ),
              ),
              const SizedBox(height: ZadSpacing.md),
            ],
            if (adsAllowed &&
                round.grant != null &&
                round.grant!.granted > 0 &&
                !round.doubled) ...<Widget>[
              OutlinedButton(
                key: const ValueKey<String>('game-double'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: round.busy ? null : round.doubleSeeds,
                child: Text('${l.gameDouble} · ${l.gameDoubleHint}'),
              ),
              if (round.adUnavailable)
                Text(
                  l.gameAdUnavailable,
                  textAlign: TextAlign.center,
                  style: ZadType.bodySmall.copyWith(
                    color: ZadColors.textTertiary,
                  ),
                ),
              const SizedBox(height: ZadSpacing.md),
            ],
            Row(
              children: <Widget>[
                Expanded(
                  child: (canContinue ? OutlinedButton.new : FilledButton.new)(
                    key: const ValueKey<String>('game-again'),
                    style: ButtonStyle(
                      minimumSize: WidgetStateProperty.all(
                        const Size.fromHeight(52),
                      ),
                    ),
                    onPressed: onAgain,
                    child: Text(l.gameAgain),
                  ),
                ),
                const SizedBox(width: ZadSpacing.md),
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey<String>('game-leave'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed: onLeave,
                    child: Text(l.gameDone),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// «+N بذور» and what is left today; nothing offline.
class _Seeds extends StatelessWidget {
  const new({required this.round});

  final GameRound round;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final g = round.grant;
    if (g == null) return const SizedBox.shrink();
    final text = g.capped
        ? l.gameSeedsCapped
        : g.granted > 0
        ? '${l.gameSeedsGranted(g.granted)} · ${l.gameSeedsLeft(g.remaining)}'
        : l.gameSeedsLeft(g.remaining);
    return Padding(
      padding: const EdgeInsets.only(top: ZadSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const SeedIcon(),
          const SizedBox(width: ZadSpacing.xs),
          Flexible(
            child: Text(
              text,
              key: const ValueKey<String>('game-end-seeds'),
              textAlign: TextAlign.center,
              style: ZadType.titleSmall.copyWith(
                color: ZadColors.forestEmerald,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
