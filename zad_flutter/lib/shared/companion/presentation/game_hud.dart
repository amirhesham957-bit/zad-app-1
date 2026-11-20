/// Score and best on top of a game; `extra` sits beside the best (seeds,
/// combo, lives). Repaints on `frame` without rebuilding the screen.
library;

import 'package:flutter/material.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';

/// The strip above the field.
class GameHud extends StatelessWidget {
  /// Creates it.
  const new({
    required this.score,
    required this.best,
    required this.frame,
    this.scoreKey = const ValueKey<String>('game-score'),
    this.extra,
    super.key,
  });

  /// The score now, read on every [frame].
  final int Function() score;

  /// The best score of the game.
  final int best;

  /// Ticks on every frame.
  final Listenable frame;

  /// Key of the score text.
  final Key scoreKey;

  /// Builds what sits beside the best score, on every frame.
  final Widget Function()? extra;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ListenableBuilder(
      listenable: frame,
      builder: (_, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: ZadSpacing.lg),
        child: Column(
          children: <Widget>[
            Semantics(
              label: l.gameScoreSemantics(score()),
              excludeSemantics: true,
              child: Text(
                '${score()}',
                key: scoreKey,
                style: ZadType.headlineMedium.copyWith(
                  fontWeight: FontWeight.w800,
                  color: ZadColors.forestEmerald,
                ),
              ),
            ),
            const SizedBox(height: ZadSpacing.xs),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: ZadSpacing.lg,
              children: <Widget>[
                if (extra != null) extra!(),
                Text(
                  l.gameBest(best),
                  style: ZadType.bodyMedium.copyWith(
                    color: ZadColors.textTertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: ZadSpacing.sm),
          ],
        ),
      ),
    );
  }
}
