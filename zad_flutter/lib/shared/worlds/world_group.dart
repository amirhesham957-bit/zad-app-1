/// A titled group of settings rows in a world: a small heading, then one
/// calm card whose rows are divided by hairlines. Used by حسابي and the
/// settings page so both read as one place.
library;

import 'package:flutter/material.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/shared/worlds/art/art.dart';
import 'package:zad/shared/worlds/world_card.dart';
import 'package:zad/shared/worlds/world_row.dart';

/// The group.
class ZadWorldGroup extends StatelessWidget {
  /// Creates a group; [children] are separated by a hairline.
  const new({required this.title, required this.children, super.key});

  /// The heading.
  final String title;

  /// The rows.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: ZadSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.only(
            start: ZadSpacing.xs,
            bottom: ZadSpacing.sm,
          ),
          child: Text(
            title,
            style: ZadType.labelMedium.copyWith(
              color: ZadColors.inkMuted,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        ZadWorldCard(
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              children: <Widget>[
                for (final (i, c) in children.indexed) ...<Widget>[
                  if (i > 0) const ZadWorldDivider(),
                  c,
                ],
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

/// One tappable row of a [ZadWorldGroup]: a drawing in its tile, a title, a
/// quiet line under it and the forward arrow.
class ZadWorldMenuRow extends StatelessWidget {
  /// Creates a row.
  const new({
    required this.art,
    required this.title,
    required this.color,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.danger = false,
    super.key,
  });

  /// The drawing.
  final ZadIconArt art;

  /// The title.
  final String title;

  /// The world colour of the tile.
  final Color color;

  /// The line under the title.
  final String? subtitle;

  /// The tap.
  final VoidCallback? onTap;

  /// Replaces the arrow (a switch, say).
  final Widget? trailing;

  /// A destructive row, drawn in the warning colour.
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final tone = danger ? ZadColors.terracottaRust : color;
    return ZadWorldRow(
      leading: ZadWorldTile(color: tone, child: ZadArt.icon(art, size: 26)),
      title: title,
      subtitle: subtitle,
      titleStyle: danger
          ? ZadType.titleSmall.copyWith(color: ZadColors.terracottaRust)
          : null,
      trailing:
          trailing ??
          (onTap == null
              ? null
              : Icon(
                  Icons.chevron_left_rounded,
                  size: 22,
                  color: ZadColors.inkMuted,
                )),
      onTap: onTap,
    );
  }
}
