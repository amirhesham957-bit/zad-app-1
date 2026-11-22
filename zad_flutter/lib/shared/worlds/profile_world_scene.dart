/// The account world's scene (حسابي and its settings page): a soft halo
/// behind the companion, a few sparks drifting round it, and the plan as a
/// gold badge when the customer has one. The plan's name is real data, drawn
/// as text — never a fixed label.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:zad/core/design/tokens/zad_world_colors.dart';
import 'package:zad/shared/worlds/world_scene.dart';

/// Paints the account scene. [plan] is the badge's text; null draws none.
class ProfileWorldScene extends CustomPainter {
  /// Creates the painter.
  new(this.loop, {this.plan}) : super(repaint: loop);

  /// The scaffold's loop.
  final Animation<double> loop;

  /// The plan's name, or null on the free plan.
  final String? plan;

  @override
  void paint(Canvas canvas, Size size) {
    final t = loop.value;
    const world = ZadWorldColors.profile;
    paintWorldGround(canvas, world);

    canvas.drawCircle(
      const Offset(215, 112),
      82 + 3 * worldTwinkle(t),
      Paint()..color = const Color(0xFFE6F4EC),
    );

    // Sparks circling the companion, slowly.
    for (var i = 0; i < 5; i++) {
      final a = (t + i / 5) * 2 * math.pi;
      final o = Offset(215 + 112 * math.cos(a), 118 + 56 * math.sin(a));
      canvas.drawCircle(
        o,
        3 + 2 * worldTwinkle(t, phase: i * 0.2),
        Paint()..color = world.withValues(alpha: 0.30),
      );
    }

    if (plan case final p?) {
      final y = 164 + worldBob(t, amplitude: 3);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(338, y), width: 110, height: 34),
          const Radius.circular(17),
        ),
        Paint()..color = ZadWorldColors.achievements,
      );
      paintWorldText(
        canvas,
        p,
        Offset(338, y),
        size: 13,
        color: const Color(0xFF3B2400),
      );
    }
  }

  @override
  bool shouldRepaint(ProfileWorldScene old) => old.plan != plan;
}
