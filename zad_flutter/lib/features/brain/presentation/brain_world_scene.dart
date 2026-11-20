/// The brain world's scene: a dark night panel with a quiet grid, ideas that
/// drift round the companion on slow orbits and thin links that glow as they
/// pass. Drawn, no emoji; the companion itself is the scaffold's.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:zad/core/design/tokens/zad_palette.dart';

const Color _glow = Color(0xFF6EE7B7);

/// Paints the night panel. [loop] is the scaffold's loop.
class BrainWorldScene extends CustomPainter {
  /// Creates the painter.
  new(this.loop) : super(repaint: loop);

  /// The scaffold's loop.
  final Animation<double> loop;

  static const Offset _core = Offset(215, 112);

  // (orbit rx, orbit ry, start angle, radius, laps per loop, colour)
  static const List<(double, double, double, double, int, Color)> _ideas =
      <(double, double, double, double, int, Color)>[
        (120, 66, 0.2, 7, 1, ZadPalette.sciFiCyanElectric),
        (150, 80, 1.4, 5, 1, _glow),
        (96, 52, 2.6, 6, 1, ZadPalette.sciFiAmber),
        (170, 92, 3.5, 4.5, 1, ZadPalette.sciFiCyanSoft),
        (130, 70, 4.4, 6.5, 1, _glow),
        (84, 44, 5.4, 4, 1, ZadPalette.sciFiCyanElectric),
      ];

  @override
  void paint(Canvas canvas, Size size) {
    final t = loop.value;
    final panel = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 4, 430, 222),
      const Radius.circular(28),
    );
    canvas
      ..save()
      ..clipRRect(panel)
      ..drawRRect(
        panel,
        Paint()
          ..shader = const RadialGradient(
            colors: <Color>[Color(0xFF0E2A2A), ZadPalette.sciFiBg],
          ).createShader(const Rect.fromLTWH(0, 4, 430, 222)),
      );
    final grid = Paint()
      ..color = ZadPalette.sciFiGrid.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    for (var x = 0.0; x <= 430; x += 24) {
      canvas.drawLine(Offset(x, 4), Offset(x, 226), grid);
    }
    for (var y = 4.0; y <= 226; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(430, y), grid);
    }
    canvas.drawCircle(
      _core,
      88 + 6 * math.sin(t * 2 * math.pi),
      Paint()..color = _glow.withValues(alpha: 0.07),
    );
    for (final (rx, ry, a0, r, laps, c) in _ideas) {
      final a = a0 + t * 2 * math.pi * laps;
      final p = _core + Offset(math.cos(a) * rx, math.sin(a) * ry);
      final pulse = 0.5 + 0.5 * math.sin(a * 2);
      canvas
        ..drawLine(
          _core,
          p,
          Paint()
            ..color = c.withValues(alpha: 0.10 + 0.14 * pulse)
            ..strokeWidth = 1.2,
        )
        ..drawCircle(p, r + 5, Paint()..color = c.withValues(alpha: 0.12))
        ..drawCircle(p, r, Paint()..color = c.withValues(alpha: 0.9));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(BrainWorldScene old) => false;
}
