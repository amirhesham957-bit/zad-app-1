/// The premium world's scene: a gold sunburst turning slowly behind the
/// companion, a crown hovering above it, coins and stars twinkling around.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:zad/core/design/tokens/zad_world_colors.dart';
import 'package:zad/shared/worlds/world_scene.dart';

// Illustrative one-off golds (a scene, not a shared component).
const Color _goldLight = Color(0xFFFFD36B);
const Color _goldDeep = Color(0xFFC68216);

/// Paints the sunburst, the crown, the coins and the stars.
class PaywallWorldScene extends CustomPainter {
  /// Creates the painter.
  new(this.loop) : super(repaint: loop);

  /// The scaffold's loop.
  final Animation<double> loop;

  @override
  void paint(Canvas canvas, Size size) {
    paintWorldGround(canvas, ZadWorldColors.premium);
    _rays(canvas);
    _crown(canvas, 215, 28 + worldBob(loop.value, amplitude: 3));
    const coins = <Offset>[
      Offset(70, 150),
      Offset(360, 130),
      Offset(98, 70),
      Offset(335, 58),
    ];
    for (var i = 0; i < coins.length; i++) {
      final p = coins[i] + Offset(0, worldBob(loop.value, phase: i * 0.25));
      canvas
        ..drawCircle(p, 15, Paint()..color = _goldDeep)
        ..drawCircle(p, 11.5, Paint()..color = _goldLight)
        ..drawCircle(
          p,
          6,
          Paint()
            ..color = _goldDeep.withValues(alpha: 0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
    }
    const stars = <Offset>[
      Offset(40, 40),
      Offset(390, 100),
      Offset(150, 24),
      Offset(290, 30),
      Offset(60, 200),
      Offset(380, 195),
    ];
    for (var i = 0; i < stars.length; i++) {
      final t = worldTwinkle(loop.value, phase: i * 0.17);
      _star(
        canvas,
        stars[i],
        5 + 4 * t,
        _goldLight.withValues(alpha: 0.5 + 0.5 * t),
      );
    }
  }

  void _rays(Canvas canvas) {
    const centre = Offset(215, 120);
    final turn = loop.value * 2 * math.pi / 4;
    const n = 14;
    final paint = Paint()
      ..color = ZadWorldColors.premium.withValues(alpha: 0.13);
    for (var i = 0; i < n; i++) {
      final a = turn + i * 2 * math.pi / n;
      const w = 0.09;
      final path = Path()
        ..moveTo(centre.dx, centre.dy)
        ..lineTo(
          centre.dx + 260 * math.cos(a - w),
          centre.dy + 260 * math.sin(a - w),
        )
        ..lineTo(
          centre.dx + 260 * math.cos(a + w),
          centre.dy + 260 * math.sin(a + w),
        )
        ..close();
      canvas.drawPath(path, paint);
    }
    canvas.drawCircle(
      centre,
      92,
      Paint()..color = _goldLight.withValues(alpha: 0.3),
    );
  }

  void _crown(Canvas canvas, double cx, double top) {
    final body = Path()
      ..moveTo(cx - 26, top + 30)
      ..lineTo(cx - 30, top + 6)
      ..lineTo(cx - 14, top + 18)
      ..lineTo(cx, top)
      ..lineTo(cx + 14, top + 18)
      ..lineTo(cx + 30, top + 6)
      ..lineTo(cx + 26, top + 30)
      ..close();
    canvas
      ..drawPath(body, Paint()..color = _goldLight)
      ..drawPath(
        body,
        Paint()
          ..color = _goldDeep
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeJoin = StrokeJoin.round,
      )
      ..drawCircle(Offset(cx, top + 22), 3.5, Paint()..color = _goldDeep);
  }

  void _star(Canvas canvas, Offset c, double r, Color color) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final rr = i.isEven ? r : r * 0.35;
      final a = i * math.pi / 4 - math.pi / 2;
      final pt = c + Offset(rr * math.cos(a), rr * math.sin(a));
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    canvas.drawPath(path..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(PaywallWorldScene old) => false;
}
