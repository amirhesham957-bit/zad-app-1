/// «نطّة زادو»'s field: the painted scene, the user's own companion standing
/// on it, and the «tap to jump» hint before the first tap.
library;

import 'package:flutter/material.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/shared/companion/domain/companion_catalog.dart';
import 'package:zad/shared/companion/domain/run_game.dart';
import 'package:zad/shared/companion/presentation/game_art.dart';
import 'package:zad/shared/companion/presentation/run_painter.dart';
import 'package:zad/shared/orb/domain/companion_state.dart';
import 'package:zad/shared/orb/presentation/companion_orb.dart';

/// The scene.
class RunScene extends StatelessWidget {
  /// Creates it.
  const new({
    required this.game,
    required this.frame,
    required this.name,
    required this.mood,
    required this.look,
    required this.reduceMotion,
    required this.started,
    required this.onTap,
    super.key,
  });

  /// The round.
  final RunGame game;

  /// Ticks on every frame.
  final Listenable frame;

  /// The pet's name.
  final String name;

  /// What the pet feels.
  final CompanionState mood;

  /// The user's own companion.
  final CompanionLook look;

  /// Reduced motion: still hills, a still orb.
  final bool reduceMotion;

  /// The first tap was made.
  final bool started;

  /// A tap on the field.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return LayoutBuilder(
      builder: (context, c) {
        final scale = c.maxWidth / RunGame.width;
        final ground = runGroundThickness * scale;
        final zado = 64 * scale;
        return Stack(
          children: <Widget>[
            Positioned.fill(
              child: Semantics(
                button: true,
                label: l.runGameHint(name),
                child: GestureDetector(
                  key: const ValueKey<String>('run-field'),
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) => onTap(),
                  child: CustomPaint(
                    painter: RunPainter(
                      game: game,
                      repaint: frame,
                      parallax: !reduceMotion,
                    ),
                  ),
                ),
              ),
            ),
            ListenableBuilder(
              listenable: frame,
              builder: (_, _) => Positioned(
                left: (RunGame.zadoX - 32) * scale,
                bottom: ground + game.y * scale - 6 * scale,
                width: zado,
                height: zado,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: game.mercy > 0 && (game.mercy * 10).floor().isEven
                        ? 0.45
                        : 1,
                    child: CompanionOrb(
                      state: mood,
                      size: zado,
                      look: look,
                      animated: !reduceMotion,
                    ),
                  ),
                ),
              ),
            ),
            if (!started)
              Positioned(
                left: ZadSpacing.xl,
                right: ZadSpacing.xl,
                top: ZadSpacing.xl,
                child: IgnorePointer(
                  child: Text(
                    l.runGameHint(name),
                    key: const ValueKey<String>('run-hint'),
                    textAlign: TextAlign.center,
                    style: ZadType.titleMedium.copyWith(color: ZadColors.slate),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The seeds picked up this round, beside the best score.
class RunSeedsChip extends StatelessWidget {
  /// Creates it.
  const new({required this.count, super.key});

  /// Seeds picked up.
  final int count;

  @override
  Widget build(BuildContext context) => Semantics(
    label: context.l10n.runGameSeedsSemantics(count),
    excludeSemantics: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const SeedIcon(),
        const SizedBox(width: ZadSpacing.xs),
        Text(
          '$count',
          key: const ValueKey<String>('run-seeds'),
          style: ZadType.titleSmall,
        ),
      ],
    ),
  );
}
