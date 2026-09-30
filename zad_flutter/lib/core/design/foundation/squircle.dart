/// The app's corner shape.
///
/// Flutter's own `BorderRadius` draws a quarter-circle at each corner, and
/// Apple's does not — iOS uses a superellipse, where the curvature ramps in
/// gradually instead of starting at full tilt. The difference is invisible at
/// 8pt and unmistakable at 28, which is exactly where the green card lives: a
/// circular-arc corner at that size reads as a cheap rounded box.
///
/// `smooth_corner` supplies the superellipse. Everything in this app that has a
/// corner goes through here, so there is one shape to change and no screen
/// quietly using `BorderRadius.circular` instead.
library;

import 'package:flutter/widgets.dart';
import 'package:smooth_corner/smooth_corner.dart';

/// How far a corner departs from a circular arc.
///
/// 0 is Flutter's quarter-circle; 1 is the most extreme superellipse the
/// package draws. 0.6 is the package default and the closest match to iOS at
/// the radii this app uses. It is a named constant rather than a literal at
/// each call site because a card with a different smoothness from the sheet it
/// opens into is the kind of mismatch nobody can name but everybody sees.
const double kZadCornerSmoothing = 0.6;

/// The border shape for a [radius]-cornered surface.
///
/// Typed `OutlinedBorder` and not `ShapeBorder` because that is what
/// `ButtonStyle.shape` and `CardTheme.shape` accept.
OutlinedBorder zadSquircle(
  double radius, {
  BorderSide side = BorderSide.none,
}) => SmoothRectangleBorder(
  borderRadius: BorderRadius.circular(radius),
  smoothness: kZadCornerSmoothing,
  side: side,
);

/// Clips [child] to a squircle.
///
/// Use this and not `ClipRRect`: a gradient or an image clipped to a
/// quarter-circle corner inside a squircle-bordered card leaves a sliver of
/// mismatch along the curve.
class ZadSquircleClip extends StatelessWidget {
  /// Clips [child] to a squircle of [radius].
  const new({required this.radius, required this.child, super.key});

  /// The corner radius.
  final double radius;

  /// The clipped subtree.
  final Widget child;

  @override
  Widget build(BuildContext context) => SmoothClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: child,
  );
}
