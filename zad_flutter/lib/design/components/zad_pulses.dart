/// Kotlin's two looping attention cues: `zadDotPulse` (ZadV2.kt) and
/// `bellShake` (ZadAnimations.kt), with their numbers.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// `zadDotPulse`: scale 1 → 1.3 and alpha 1 → 0.7 over [period],
/// FastOutSlowIn, reversing — a live dot breathing.
class ZadDotPulse extends StatefulWidget {
  /// Pulses [child].
  const new({
    required this.child,
    this.period = const Duration(milliseconds: 2400),
    super.key,
  });

  /// The dot.
  final Widget child;

  /// One way of the breath.
  final Duration period;

  @override
  State<ZadDotPulse> createState() => _ZadDotPulseState();
}

class _ZadDotPulseState extends State<ZadDotPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.period,
  )..repeat(reverse: true);

  late final Animation<double> _t = CurvedAnimation(
    parent: _c,
    curve: Curves.fastOutSlowIn,
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 1,
    end: 1.3,
  ).animate(_t);
  late final Animation<double> _alpha = Tween<double>(
    begin: 1,
    end: 0.7,
  ).animate(_t);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: ScaleTransition(
      scale: _scale,
      child: FadeTransition(opacity: _alpha, child: widget.child),
    ),
  );
}

/// `bellShake`: still for 1.6s, then -10° → 10° → -6° → 6° → 0 in 100ms
/// steps, on a 2.2s loop. Off when [enabled] is false.
class ZadBellShake extends StatefulWidget {
  /// Shakes [child] while [enabled].
  const new({required this.child, this.enabled = true, super.key});

  /// The bell.
  final Widget child;

  /// Whether there is something unread.
  final bool enabled;

  @override
  State<ZadBellShake> createState() => _ZadBellShakeState();
}

class _ZadBellShakeState extends State<ZadBellShake>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  // Compose keyframes interpolate linearly between the marks.
  static final Animatable<double> _degrees = TweenSequence<double>(
    <TweenSequenceItem<double>>[
      TweenSequenceItem<double>(tween: ConstantTween<double>(0), weight: 1600),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0, end: -10),
        weight: 100,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: -10, end: 10),
        weight: 100,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 10, end: -6),
        weight: 100,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: -6, end: 6),
        weight: 100,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 6, end: 0),
        weight: 100,
      ),
      TweenSequenceItem<double>(tween: ConstantTween<double>(0), weight: 100),
    ],
  );

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _c.repeat();
  }

  @override
  void didUpdateWidget(ZadBellShake old) {
    super.didUpdateWidget(old);
    if (widget.enabled && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.enabled && _c.isAnimating) {
      _c
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, child) => Transform.rotate(
      angle: _degrees.evaluate(_c) * math.pi / 180,
      child: child,
    ),
    child: widget.child,
  );
}
