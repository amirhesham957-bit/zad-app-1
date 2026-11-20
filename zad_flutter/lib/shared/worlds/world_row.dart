/// The one row a world's card is made of: a drawn tile, a title, a line of
/// state in the row's own colour, an optional bar that fills toward the
/// thing, and whatever sits at the end. Worlds do not draw their own rows.
library;

import 'package:flutter/material.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_motion.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';

/// A row in a world's card.
class ZadWorldRow extends StatelessWidget {
  /// Creates the row. [leading] is a drawn tile (see `ZadWorldTile`).
  const new({
    required this.leading,
    required this.title,
    this.subtitle,
    this.stateColor,
    this.progress,
    this.trailing,
    this.onTap,
    this.titleStyle,
    super.key,
  });

  /// The tile at the start.
  final Widget leading;

  /// The name.
  final String title;

  /// The line under it, drawn in [stateColor].
  final String? subtitle;

  /// The row's state colour: the subtitle and the bar (muted when null).
  final Color? stateColor;

  /// 0..1: a bar under the text; null draws none.
  final double? progress;

  /// What sits at the end.
  final Widget? trailing;

  /// Tapping the row.
  final VoidCallback? onTap;

  /// Overrides the title's style (a struck-through bought line).
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    final state = stateColor ?? ZadColors.inkMuted;
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final body = Row(
      children: <Widget>[
        leading,
        const SizedBox(width: ZadSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: titleStyle ?? ZadType.titleSmall,
              ),
              if (subtitle case final s? when s.isNotEmpty)
                Text(
                  s,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: ZadType.labelSmall.copyWith(
                    color: state,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              if (progress case final p?) ...<Widget>[
                const SizedBox(height: ZadSpacing.xs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(ZadRadii.pill),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(end: p.clamp(0, 1)),
                    duration: still ? Duration.zero : ZadDuration.settle,
                    curve: ZadCurves.standard,
                    builder: (_, v, _) => LinearProgressIndicator(
                      value: v,
                      minHeight: 6,
                      color: state,
                      backgroundColor: state.withValues(alpha: 0.14),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
    if (onTap == null) return body;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ZadRadii.chip),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: body,
      ),
    );
  }
}

/// The drawn square a [ZadWorldRow] starts with: [child] (art) on a soft
/// tile of [color].
class ZadWorldTile extends StatelessWidget {
  /// Creates the tile.
  const new({
    required this.color,
    required this.child,
    this.size = 44,
    super.key,
  });

  /// The tint under the drawing.
  final Color color;

  /// The drawing.
  final Widget child;

  /// The side.
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(ZadRadii.chip),
    ),
    child: child,
  );
}

/// A hairline between two rows of a card.
class ZadWorldDivider extends StatelessWidget {
  /// Creates it.
  const new({super.key});

  @override
  Widget build(BuildContext context) =>
      const Divider(height: ZadSpacing.lg, color: ZadColors.hairline);
}
