/// The «متصلة بـ» strip at the bottom of every world: coloured chips that
/// open the worlds this one feeds. A chip opens through
/// `ZadScreens.worldScreen`, never through another feature; a world with no
/// screen yet has no chip.
library;

import 'package:flutter/material.dart';
import 'package:zad/core/design/components/zad_pressable.dart';
import 'package:zad/core/design/foundation/squircle.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/shared/navigation/zad_screens.dart';
import 'package:zad/shared/worlds/art/zad_art.dart';
import 'package:zad/shared/worlds/world_tone.dart';
import 'package:zad/shared/worlds/zad_world.dart';

/// The strip for [world]; nothing at all when none of its links can open.
class ZadWorldLinks extends StatelessWidget {
  /// Creates the strip.
  const new({required this.world, super.key});

  /// The world it sits under.
  final ZadWorld world;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tone = ZadWorldTone.of(context);
    final open = <(ZadWorld, OpenScreen)>[
      for (final w in world.feeds)
        if (ZadScreens.worldScreen(w) case final screen?) (w, screen),
    ];
    if (open.isEmpty) return const SizedBox.shrink();
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: tone.surface,
        shape: zadSquircle(
          ZadRadii.cardLarge,
          side: BorderSide(color: tone.outline, width: 1.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(ZadSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(
                    text: l.worldLinksTitle,
                    style: ZadType.titleSmall.copyWith(color: tone.ink),
                  ),
                  TextSpan(
                    text: '  ${l.worldLinksHint}',
                    style: ZadType.labelMedium.copyWith(color: tone.inkMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: ZadSpacing.sm),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: open.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: ZadSpacing.sm),
                itemBuilder: (context, i) {
                  final (w, screen) = open[i];
                  return _Chip(world: w, onTap: () => screen(context));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const new({required this.world, required this.onTap});

  final ZadWorld world;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ZadPressable(
    onPressed: onTap,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: world.color,
        borderRadius: BorderRadius.circular(ZadRadii.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: ZadSpacing.md),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(child: ZadArt.icon(world.art, size: 18)),
            ),
            const SizedBox(width: ZadSpacing.sm),
            Text(
              world.label(context.l10n),
              style: ZadType.labelLarge.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    ),
  );
}
