/// The appointments world's scene: a calendar page that flips to today, and a
/// clock whose hand turns.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:zad/core/design/tokens/zad_world_colors.dart';
import 'package:zad/shared/worlds/world_scene.dart';

// Illustrative one-off colours (a scene, not a shared component).
const Color _rim = Color(0xFFF3D2DF);
const Color _ink = Color(0xFF1F1F14);

/// Paints the calendar of [day] / [month] and the clock.
class AppointmentsWorldScene extends CustomPainter {
  /// Creates the painter; [day] and [month] are today's, as text.
  new(this.loop, {required this.day, required this.month})
    : super(repaint: loop);

  /// The scaffold's loop.
  final Animation<double> loop;

  /// Today's day of the month.
  final String day;

  /// Today's month name.
  final String month;

  @override
  void paint(Canvas canvas, Size size) {
    final t = loop.value;
    const pink = ZadWorldColors.appointments;
    paintWorldGround(canvas, pink);
    canvas
      ..save()
      ..translate(0, worldBob(t, amplitude: 3));
    const page = Rect.fromLTWH(220, 30, 150, 160);
    final rr = RRect.fromRectAndRadius(page, const Radius.circular(18));
    canvas
      ..drawRRect(rr, Paint()..color = Colors.white)
      ..drawRRect(
        rr,
        Paint()
          ..color = _rim
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      )
      ..drawRRect(
        RRect.fromRectAndCorners(
          const Rect.fromLTWH(220, 30, 150, 44),
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
        ),
        Paint()..color = pink,
      );
    paintWorldText(
      canvas,
      month,
      const Offset(295, 52),
      size: 20,
      color: Colors.white,
    );
    paintWorldText(canvas, day, const Offset(295, 130), size: 64, color: _ink);
    // The page that turns to today: in the first fifth of the loop an old
    // page folds away from the bottom edge, upward.
    final flip = (t / 0.2).clamp(0.0, 1.0);
    if (flip < 1) {
      final h = 160 * (1 - flip);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(220, 30, 150, h),
          const Radius.circular(18),
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.92),
      );
    }
    canvas.restore();
    _clock(canvas, t);
  }

  void _clock(Canvas canvas, double t) {
    const c = Offset(160, 150);
    canvas
      ..drawCircle(c, 34, Paint()..color = Colors.white)
      ..drawCircle(
        c,
        34,
        Paint()
          ..color = ZadWorldColors.appointments
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      );
    Offset tip(double turns, double len) {
      final a = turns * 2 * math.pi - math.pi / 2;
      return c + Offset(math.cos(a), math.sin(a)) * len;
    }

    final hand = Paint()
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(c, tip(t, 24), hand..color = _ink)
      ..drawLine(
        c,
        tip(t / 12 + 0.12, 14),
        hand..color = ZadWorldColors.appointments,
      );
  }

  @override
  bool shouldRepaint(AppointmentsWorldScene old) =>
      old.day != day || old.month != month;
}
