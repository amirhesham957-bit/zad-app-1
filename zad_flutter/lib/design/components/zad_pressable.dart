/// The app's press feedback: a scale, a shadow that closes, and one haptic
/// tick.
///
/// This replaces Material's ripple everywhere. A ripple spreads as a circle,
/// which fights a squircle's corners, and it answers a tap after the fact; a
/// scale answers the finger while it is still down.
///
/// The haptic fires on press *down*, not on the callback. Feedback that waits
/// for the work to finish is feedback about the work, and by then the user has
/// already stopped wondering whether the tap registered.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zad/design/tokens/zad_motion.dart';

/// Wraps [child] in this app's press behaviour.
class ZadPressable extends StatefulWidget {
  /// Creates a pressable.
  const new({
    required this.child,
    this.onPressed,
    this.scale = 0.97,
    this.haptic = true,
    this.semanticLabel,
    super.key,
  });

  /// The content.
  final Widget child;

  /// What the press does. A null callback disables the press and its feedback,
  /// so a disabled card does not animate as though it did something.
  final VoidCallback? onPressed;

  /// How far it shrinks. Deliberately shallow — 0.97 on a large card is a
  /// noticeable give; anything under about 0.93 looks like the card is falling
  /// away from the finger.
  final double scale;

  /// Whether to buzz. Off for anything that repeats quickly, where a tick per
  /// event turns into a rattle.
  final bool haptic;

  /// What a screen reader announces.
  final String? semanticLabel;

  @override
  State<ZadPressable> createState() => _ZadPressableState();
}

class _ZadPressableState extends State<ZadPressable> {
  bool _down = false;

  bool get _enabled => widget.onPressed != null;

  void _setDown(bool down) {
    if (!_enabled || _down == down) return;
    setState(() => _down = down);
    if (down && widget.haptic) {
      // selectionClick, not mediumImpact: this is an acknowledgement, and the
      // heavier impacts belong to something completing or failing.
      unawaited(HapticFeedback.selectionClick());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticLabel,
      button: _enabled,
      enabled: _enabled,
      child: GestureDetector(
        onTapDown: (_) => _setDown(true),
        onTapUp: (_) => _setDown(false),
        onTapCancel: () => _setDown(false),
        onTap: widget.onPressed,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _down ? widget.scale : 1,
          duration: ZadDuration.press,
          curve: ZadCurves.press,
          child: widget.child,
        ),
      ),
    );
  }
}
