/// The games world's scene: a ball bouncing on the ground, a star twinkling
/// and a seed bobbing beside the companion, on the games world's violet.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:zad/core/design/tokens/zad_world_colors.dart';
import 'package:zad/shared/companion/presentation/game_art.dart';
import 'package:zad/shared/worlds/world_scene.dart';

// Illustrative one-off colours (a scene, not a shared component).
const Color _ball = Color(0xFFF2762E);
const Color _ballLine = Color(0xFFFFFFFF);

/// Paints the toys.
class GamesWorldScene extends CustomPainter {
  /// Creates the painter. [streak]: the flame beside the ball is lit when the
  /// day streak is alive.
  new(this.loop, {required this.streak}) : super(repaint: loop);

  /// The scaffold's loop.
  final Animation<double> loop;

  /// Consecutive days played.
  final int streak;

  @override
  void paint(Canvas canvas, Size size) {
    final t = loop.value;
    paintWorldGround(canvas, ZadWorldColors.games);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(330, 204), width: 70, height: 12),
      Paint()..color = ZadWorldColors.games.withValues(alpha: 0.22),
    );

    // The ball: one bounce per loop, with a turning seam.
    final bounce = (math.sin(t * math.pi * 2).abs()) * 70;
    final c = Offset(330, 184 - bounce);
    canvas
      ..drawCircle(c, 28, Paint()..color = _ball)
      ..save()
      ..translate(c.dx, c.dy)
      ..rotate(t * math.pi * 2)
      ..drawArc(
        Rect.fromCircle(center: Offset.zero, radius: 20),
        0.4,
        2.3,
        false,
        Paint()
          ..color = _ballLine
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
      )
      ..restore();

    // A star and a seed.
    paintStar(
      canvas,
      Offset(250, 52 + worldBob(t, amplitude: 5)),
      18 + 3 * worldTwinkle(t),
      turn: worldBob(t, amplitude: 0.2),
    );
    paintSeed(canvas, Offset(390, 70 + worldBob(t, phase: 0.4)), 14);
    if (streak > 0) {
      paintStar(
        canvas,
        Offset(380, 140 + worldBob(t, amplitude: 3, phase: 0.7)),
        9,
        turn: 0.2,
      );
    }
  }

  @override
  bool shouldRepaint(GamesWorldScene old) => old.streak != streak;
}
