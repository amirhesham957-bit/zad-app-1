/// Small helpers the painted scenes share. A scene is drawn in a 430×230
/// design space; the scaffold scales it to the screen's width.
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// The scene's design size.
const Size kWorldSceneSize = Size(430, 230);

/// The soft ellipse everything stands on.
void paintWorldGround(Canvas canvas, Color color) {
  canvas.drawOval(
    Rect.fromCenter(center: const Offset(215, 214), width: 360, height: 28),
    Paint()..color = color.withValues(alpha: 0.18),
  );
}

/// A slow vertical bob of ±[amplitude] over the loop (one period per loop).
double worldBob(double loop, {double amplitude = 4, double phase = 0}) =>
    math.sin((loop + phase) * 2 * math.pi) * amplitude;

/// 0..1, two soft pulses per loop — a twinkle.
double worldTwinkle(double loop, {double phase = 0}) =>
    0.5 + 0.5 * math.sin((loop + phase) * 4 * math.pi);

/// 0..1 progress of a falling thing that restarts every loop, offset by
/// [phase] so several do not fall together.
double worldFall(double loop, {double phase = 0}) => (loop + phase) % 1;

/// Scales a design-space painter to the real width.
class ScaledScene extends CustomPainter {
  /// Wraps [inner] at [scale].
  new(this.inner, this.scale) : super(repaint: inner);

  /// The scene.
  final CustomPainter inner;

  /// Real pixels per design unit.
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..scale(scale);
    inner.paint(canvas, kWorldSceneSize);
    canvas.restore();
  }

  @override
  bool shouldRepaint(ScaledScene old) =>
      old.scale != scale || inner.shouldRepaint(old.inner);
}
