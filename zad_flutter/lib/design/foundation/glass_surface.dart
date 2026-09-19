/// Frosted glass.
///
/// `BackdropFilter` is the most expensive widget in this design language. It
/// forces the layer beneath it into a saveLayer and blurs it every frame, and
/// on a mid-range Android that cost is measured in whole milliseconds — enough
/// that two or three of them on one screen will not hold 120fps, and may not
/// hold 60.
///
/// So glass is a component here, not a modifier anyone can sprinkle on. The
/// rules it enforces:
///
/// * one blur pass per glass surface, never a blur inside a blur;
/// * the surface is always clipped, because an unclipped `BackdropFilter` blurs
///   the whole layer it sits in and not just its own bounds;
/// * a translucent fill and a hairline edge on top of the blur, because a blur
///   alone reads as a smudge — the edge is what makes it read as a pane;
/// * and a `solid` escape hatch, so a long scrolling list can render the same
///   component without the blur.
library;

import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:zad/design/foundation/squircle.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_spacing.dart';

/// A pane of frosted glass.
class ZadGlass extends StatelessWidget {
  /// Creates a glass surface.
  const new({
    required this.child,
    this.radius = ZadRadii.card,
    this.blur = 24,
    this.tint = const Color(0x99FFFFFF),
    this.edge = ZadColors.hairline,
    this.padding = const EdgeInsets.all(ZadSpacing.lg),
    this.solid = false,
    super.key,
  });

  /// Glass over a dark surface: a lighter edge, a darker tint.
  ///
  /// The same widget with inverted values, named because getting the edge wrong
  /// on dark is what makes glass look like a grey rectangle.
  const new onDark({
    required this.child,
    this.radius = ZadRadii.card,
    this.blur = 18,
    this.tint = const Color(0x1FFFFFFF),
    this.edge = ZadColors.glassEdge,
    this.padding = const EdgeInsets.all(ZadSpacing.lg),
    this.solid = false,
    super.key,
  });

  /// The content.
  final Widget child;

  /// The corner radius.
  final double radius;

  /// Blur sigma. Past about 30 the backdrop stops being recognisable and the
  /// effect costs more for less.
  final double blur;

  /// The translucent fill laid over the blur.
  final Color tint;

  /// The hairline that makes the pane read as an edge.
  final Color edge;

  /// Inner padding.
  final EdgeInsets padding;

  /// Skips the blur and fills opaquely instead.
  ///
  /// For a repeated row in a long list, where the blur would be paid per item
  /// per frame and the visual difference is close to nothing.
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final surface = DecoratedBox(
      decoration: ShapeDecoration(
        // A blurred backdrop plus a translucent tint; or, when solid, the tint
        // composited onto white so the same colour lands without the blur.
        color: solid ? Color.alphaBlend(tint, ZadColors.surface) : tint,
        shape: zadSquircle(radius, side: BorderSide(color: edge, width: 0.5)),
      ),
      child: Padding(padding: padding, child: child),
    );

    if (solid) return surface;

    // Clipped, always: an unclipped BackdropFilter blurs its whole parent
    // layer.
    return ZadSquircleClip(
      radius: radius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: surface,
      ),
    );
  }
}
