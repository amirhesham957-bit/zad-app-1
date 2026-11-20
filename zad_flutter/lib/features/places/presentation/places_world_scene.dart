/// «أماكني» scene: a map pin that bobs over soft rings, and the small
/// planets of the shops around it. The orbit proper (tappable) is
/// `PlacesOrbit`, in the habits card below.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:zad/core/design/tokens/zad_world_colors.dart';
import 'package:zad/shared/worlds/world_scene.dart';

/// Paints the scene. [alertsOn] lights the rings (street alerts watching).
class PlacesWorldScene extends CustomPainter {
  /// Creates the painter.
  new(this.loop, {required this.alertsOn}) : super(repaint: loop);

  /// The scaffold's loop.
  final Animation<double> loop;

  /// Whether street alerts are on.
  final bool alertsOn;

  @override
  void paint(Canvas canvas, Size size) {
    final t = loop.value;
    const c = Offset(300, 118);
    paintWorldGround(canvas, ZadWorldColors.places);
    for (var i = 0; i < 3; i++) {
      final k = alertsOn ? (t + i / 3) % 1 : 0.35 + i * 0.2;
      canvas.drawCircle(
        c,
        34 + 52 * k,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = ZadWorldColors.places.withValues(
            alpha: alertsOn ? 0.30 * (1 - k) : 0.10,
          ),
      );
    }
    for (var i = 0; i < 3; i++) {
      final a = (t + i / 3) * 2 * math.pi;
      final r = 52.0 + i * 14;
      canvas.drawCircle(
        c + Offset(math.cos(a) * r, math.sin(a) * r * 0.55),
        6.0 - i,
        Paint()..color = ZadWorldColors.places.withValues(alpha: 0.55),
      );
    }
    canvas
      ..save()
      ..translate(0, worldBob(t));
    final pin = Path()
      ..moveTo(c.dx, c.dy + 42)
      ..cubicTo(c.dx - 40, c.dy, c.dx - 30, c.dy - 40, c.dx, c.dy - 40)
      ..cubicTo(c.dx + 30, c.dy - 40, c.dx + 40, c.dy, c.dx, c.dy + 42)
      ..close();
    canvas
      ..drawPath(pin, Paint()..color = ZadWorldColors.places)
      ..drawCircle(c.translate(0, -12), 12, Paint()..color = Colors.white)
      ..restore();
  }

  @override
  bool shouldRepaint(PlacesWorldScene old) => old.alertsOn != alertsOn;
}
