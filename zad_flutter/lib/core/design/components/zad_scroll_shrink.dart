/// The home's money shrinking back as the list moves on (ZAD_PLAN ٢.٣): over
/// the first stretch of scroll its child scales down a little and fades a
/// little, then holds — the number is still there to read, it just steps
/// back for what comes under it.
///
/// Tied to the scroll, never to a clock, so it costs nothing at rest. Outside
/// a scrollable it is its child as it is.
library;

import 'package:flutter/widgets.dart';

/// How far the child has stepped back at [pixels] of scroll over
/// [distance], 0..1.
double scrollShrinkAt(double pixels, double distance) =>
    distance <= 0 ? 0 : (pixels / distance).clamp(0, 1);

/// Scales and fades [child] with the enclosing scroll.
class ZadScrollShrink extends StatelessWidget {
  /// Creates the effect.
  const new({
    required this.child,
    this.distance = 240,
    this.minScale = 0.92,
    this.minOpacity = 0.6,
    super.key,
  });

  /// What steps back.
  final Widget child;

  /// The scroll over which it does.
  final double distance;

  /// Its size once it has.
  final double minScale;

  /// Its opacity once it has.
  final double minOpacity;

  @override
  Widget build(BuildContext context) {
    final position = Scrollable.maybeOf(context)?.position;
    if (position == null) return child;
    return ListenableBuilder(
      listenable: position,
      child: child,
      builder: (context, child) {
        final t = position.hasPixels
            ? scrollShrinkAt(position.pixels, distance)
            : 0.0;
        if (t == 0) return child!;
        return Opacity(
          opacity: 1 - (1 - minOpacity) * t,
          child: Transform.scale(
            scale: 1 - (1 - minScale) * t,
            alignment: Alignment.topCenter,
            child: child,
          ),
        );
      },
    );
  }
}
