/// The board of «زادو بيرتّب»: a 4x4 grid of seeds coloured by level, and the
/// four arrows under it for those who do not swipe (and for TalkBack).
library;

import 'package:flutter/material.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_motion.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/shared/companion/domain/sort_game.dart';

/// The colour of a seed level: green for small, gold for big.
Color sortTileColor(int level) {
  if (level <= 0) return ZadColors.mint100;
  final t = ((level - 1) / 8).clamp(0, 1).toDouble();
  return Color.lerp(const Color(0xFF9FD3B8), const Color(0xFFF2B632), t)!;
}

/// The grid.
class SortBoard extends StatelessWidget {
  /// Creates it.
  const new({required this.game, required this.onMove, super.key});

  /// The round.
  final SortGame game;

  /// A swipe, or an arrow.
  final void Function(SortMove) onMove;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey<String>('sort-board'),
      behavior: HitTestBehavior.opaque,
      onPanEnd: (d) {
        final v = d.velocity.pixelsPerSecond;
        if (v.distance < 120) return;
        onMove(
          v.dx.abs() > v.dy.abs()
              ? (v.dx > 0 ? SortMove.right : SortMove.left)
              : (v.dy > 0 ? SortMove.down : SortMove.up),
        );
      },
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          padding: const EdgeInsets.all(ZadSpacing.sm),
          decoration: BoxDecoration(
            color: const Color(0xFFD7E8DE),
            borderRadius: BorderRadius.circular(ZadRadii.card),
          ),
          child: Column(
            children: <Widget>[
              for (var r = 0; r < SortGame.size; r++)
                Expanded(
                  child: Row(
                    children: <Widget>[
                      for (var c = 0; c < SortGame.size; c++)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(ZadSpacing.xs),
                            child: _Tile(level: game.grid[r][c]),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const new({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) => Semantics(
    label: level == 0
        ? null
        : context.l10n.sortGameTile(SortGame.valueOf(level)),
    excludeSemantics: true,
    child: AnimatedContainer(
      duration: ZadDuration.quick,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: sortTileColor(level),
        borderRadius: BorderRadius.circular(ZadRadii.chip),
      ),
      child: level == 0
          ? null
          : FittedBox(
              child: Padding(
                padding: const EdgeInsets.all(ZadSpacing.xs),
                child: Text(
                  '${SortGame.valueOf(level)}',
                  style: ZadType.titleLarge.copyWith(
                    fontWeight: FontWeight.w800,
                    color: ZadColors.forestEmerald,
                  ),
                ),
              ),
            ),
    ),
  );
}

/// The four arrows.
class SortArrows extends StatelessWidget {
  /// Creates it.
  const new({required this.onMove, super.key});

  /// An arrow was tapped.
  final void Function(SortMove) onMove;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget arrow(SortMove m, IconData icon, String label) => Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: IconButton.filledTonal(
        key: ValueKey<String>('sort-${m.name}'),
        constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
        onPressed: () => onMove(m),
        icon: Icon(icon),
      ),
    );
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: ZadSpacing.md,
      children: <Widget>[
        arrow(SortMove.left, Icons.keyboard_arrow_left, l.sortGameLeft),
        arrow(SortMove.up, Icons.keyboard_arrow_up, l.sortGameUp),
        arrow(SortMove.down, Icons.keyboard_arrow_down, l.sortGameDown),
        arrow(SortMove.right, Icons.keyboard_arrow_right, l.sortGameRight),
      ],
    );
  }
}
