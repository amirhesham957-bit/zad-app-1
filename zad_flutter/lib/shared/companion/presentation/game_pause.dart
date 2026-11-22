/// Shown over a game when the app was left: the round waits until tapped.
library;

import 'package:flutter/material.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';

/// The pause veil.
class GamePauseOverlay extends StatelessWidget {
  /// Creates it.
  const new({required this.onResume, super.key});

  /// Back to the round.
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ColoredBox(
      key: const ValueKey<String>('game-paused'),
      color: const Color(0x99000000),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              l.gamePaused,
              style: ZadType.titleLarge.copyWith(color: ZadColors.surface),
            ),
            const SizedBox(height: ZadSpacing.lg),
            FilledButton(
              key: const ValueKey<String>('game-resume'),
              style: FilledButton.styleFrom(minimumSize: const Size(160, 52)),
              onPressed: onResume,
              child: Text(l.gameResume),
            ),
          ],
        ),
      ),
    );
  }
}

/// The dark veil with the end card at the bottom, thumb-reachable.
class GameScrim extends StatelessWidget {
  /// Creates it.
  const new({required this.child, super.key});

  /// The end card.
  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0x66000000),
    child: Align(
      alignment: Alignment.bottomCenter,
      child: SingleChildScrollView(
        reverse: true,
        padding: const EdgeInsets.all(ZadSpacing.lg),
        child: child,
      ),
    ),
  );
}
