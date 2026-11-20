/// The notifications world's scene: a bell that swings gently and soft
/// waves spreading out from it. With something unread the waves are
/// stronger and the clapper swings wider.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:zad/core/design/tokens/zad_world_colors.dart';
import 'package:zad/shared/worlds/world_scene.dart';

/// Paints the bell. [ringing] is whether something is unread.
class NotificationWorldScene extends CustomPainter {
  /// Creates the painter.
  new(this.loop, {required this.ringing}) : super(repaint: loop);

  /// The scaffold's loop.
  final Animation<double> loop;

  /// Whether something is unread.
  final bool ringing;

  static const Offset _hub = Offset(318, 112);

  @override
  void paint(Canvas canvas, Size size) {
    final t = loop.value;
    const world = ZadWorldColors.notifications;
    paintWorldGround(canvas, world);

    // Soft waves: three rings that grow and fade, offset in time.
    for (var i = 0; i < 3; i++) {
      final p = worldFall(t, phase: i / 3);
      canvas.drawCircle(
        _hub,
        44 + 78 * p,
        Paint()
          ..color = world.withValues(alpha: (ringing ? 0.30 : 0.14) * (1 - p))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }

    final swing = math.sin(t * 4 * math.pi) * (ringing ? 0.16 : 0.05);
    canvas
      ..save()
      ..translate(_hub.dx, _hub.dy - 40)
      ..rotate(swing)
      ..translate(-_hub.dx, -(_hub.dy - 40));
    final fill = Paint()..color = Colors.white;
    final line = Paint()
      ..color = world
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeJoin = StrokeJoin.round;
    final body = Path()
      ..moveTo(_hub.dx - 44, _hub.dy + 38)
      ..quadraticBezierTo(_hub.dx - 40, _hub.dy + 28, _hub.dx - 36, _hub.dy - 6)
      ..cubicTo(
        _hub.dx - 34,
        _hub.dy - 44,
        _hub.dx + 34,
        _hub.dy - 44,
        _hub.dx + 36,
        _hub.dy - 6,
      )
      ..quadraticBezierTo(
        _hub.dx + 40,
        _hub.dy + 28,
        _hub.dx + 44,
        _hub.dy + 38,
      )
      ..close();
    canvas
      ..drawCircle(Offset(_hub.dx, _hub.dy - 46), 6, Paint()..color = world)
      ..drawPath(body, fill)
      ..drawPath(body, line)
      ..drawCircle(Offset(_hub.dx, _hub.dy + 46), 9, Paint()..color = world)
      ..restore();

    // A few small sparks beside the bell that twinkle.
    for (final (i, o) in const <Offset>[
      Offset(240, 60),
      Offset(396, 70),
      Offset(380, 168),
    ].indexed) {
      canvas.drawCircle(
        o,
        3 + 2 * worldTwinkle(t, phase: i * 0.3),
        Paint()..color = world.withValues(alpha: 0.35),
      );
    }
  }

  @override
  bool shouldRepaint(NotificationWorldScene old) => old.ringing != ringing;
}
