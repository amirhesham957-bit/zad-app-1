/// The maintenance world's scene: a house with a gear turning in its wall
/// and a wrench leaning on it. The gear turns faster, and reddens, when
/// something is overdue.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:zad/core/design/tokens/zad_world_colors.dart';
import 'package:zad/shared/worlds/world_scene.dart';

// Illustrative one-off colours (a scene, not a shared component).
const Color _roof = Color(0xFF1B4332);
const Color _wall = Color(0xFFD5DAE0);
const Color _red = Color(0xFFE5473C);
const Color _wrench = Color(0xFF8792A0);
const Color _spark = Color(0xFFF5B93A);

/// Paints the house. [overdue] reddens the gear.
class MaintenanceWorldScene extends CustomPainter {
  /// Creates the painter.
  new(this.loop, {required this.overdue}) : super(repaint: loop);

  /// The scaffold's loop.
  final Animation<double> loop;

  /// Whether a task is past its date.
  final bool overdue;

  @override
  void paint(Canvas canvas, Size size) {
    paintWorldGround(canvas, ZadWorldColors.maintenance);
    final house = Path()
      ..moveTo(200, 110)
      ..lineTo(290, 40)
      ..lineTo(380, 110)
      ..lineTo(380, 200)
      ..lineTo(200, 200)
      ..close();
    canvas
      ..drawPath(house, Paint()..color = Colors.white)
      ..drawPath(
        house,
        Paint()
          ..color = _wall
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      )
      ..drawPath(
        Path()
          ..moveTo(186, 118)
          ..lineTo(290, 32)
          ..lineTo(394, 118),
        Paint()
          ..color = _roof
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    final gear = Paint()..color = overdue ? _red : ZadWorldColors.maintenance;
    final turn = loop.value * 2 * math.pi * (overdue ? 2 : 1);
    canvas
      ..save()
      ..translate(290, 140)
      ..rotate(turn)
      ..drawCircle(Offset.zero, 26, gear);
    for (var i = 0; i < 8; i++) {
      canvas
        ..save()
        ..rotate(i * math.pi / 4)
        ..drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-6, -36, 12, 14),
            const Radius.circular(3),
          ),
          gear,
        )
        ..restore();
    }
    final t = worldTwinkle(loop.value);
    canvas
      ..drawCircle(Offset.zero, 10, Paint()..color = Colors.white)
      ..restore()
      ..save()
      ..translate(176, 176)
      ..rotate(-0.7)
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-4, -26, 8, 52),
          const Radius.circular(4),
        ),
        Paint()..color = _wrench,
      )
      ..drawCircle(const Offset(0, -28), 11, Paint()..color = _wrench)
      ..drawCircle(const Offset(0, -33), 5, Paint()..color = Colors.white)
      ..restore()
      ..drawCircle(
        const Offset(200, 150),
        3 + 3 * t,
        Paint()..color = _spark.withValues(alpha: 0.4 + 0.6 * t),
      );
  }

  @override
  bool shouldRepaint(MaintenanceWorldScene old) => old.overdue != overdue;
}
