/// The plain white card, and the surface most of the app is built from.
library;

import 'package:flutter/widgets.dart';
import 'package:zad/design/components/zad_pressable.dart';
import 'package:zad/design/foundation/elevation.dart';
import 'package:zad/design/foundation/squircle.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_motion.dart';
import 'package:zad/design/tokens/zad_spacing.dart';

/// A card.
class ZadCard extends StatefulWidget {
  /// Creates a card.
  const new({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(ZadSpacing.lg),
    this.radius = ZadRadii.card,
    this.color = ZadColors.surface,
    super.key,
  });

  /// The content.
  final Widget child;

  /// What tapping it does. Null makes it a plain surface with no feedback.
  final VoidCallback? onTap;

  /// Inner padding.
  final EdgeInsets padding;

  /// Corner radius.
  final double radius;

  /// Fill.
  final Color color;

  @override
  State<ZadCard> createState() => _ZadCardState();
}

class _ZadCardState extends State<ZadCard> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final surface = AnimatedContainer(
      duration: ZadDuration.press,
      curve: ZadCurves.press,
      decoration: ShapeDecoration(
        color: widget.color,
        shape: zadSquircle(
          widget.radius,
          // A half-pixel hairline, iOS-style, instead of a border. On a white
          // card over a near-white canvas the edge is what separates them; a
          // 1px line at this contrast reads as a drawn box.
          side: const BorderSide(color: ZadColors.hairline, width: 0.5),
        ),
        shadows: _down ? ZadElevation.pressed : ZadElevation.card,
      ),
      child: Padding(padding: widget.padding, child: widget.child),
    );

    if (widget.onTap == null) return surface;

    return Listener(
      onPointerDown: (_) => setState(() => _down = true),
      onPointerUp: (_) => setState(() => _down = false),
      onPointerCancel: (_) => setState(() => _down = false),
      child: ZadPressable(onPressed: widget.onTap, child: surface),
    );
  }
}
