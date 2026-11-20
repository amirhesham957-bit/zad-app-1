/// The subscriptions world's scene: a calendar page with a ribbon of the next
/// thirty days, one drop per upcoming charge in its brand's colour. «النهارده»
/// pulses at the ribbon's start and a charge three days away or less glows.
library;

import 'package:flutter/material.dart';
import 'package:zad/core/design/tokens/zad_world_colors.dart';
import 'package:zad/shared/worlds/world_scene.dart';

/// One charge on the ribbon: `day` days from today (0..30) in `color`.
typedef WorldCharge = ({int day, Color color});

/// How many days the ribbon covers.
const int kSubsRibbonDays = 30;

// Illustrative one-off colours (a scene, not a shared component).
const Color _rim = Color(0xFFF2D49A);
const Color _track = Color(0xFFFFF1D6);

const double _left = 145;
const double _right = 400;
const double _ribbonY = 150;

/// Paints the calendar and the ribbon of [charges].
class SubscriptionsWorldScene extends CustomPainter {
  /// Creates the painter.
  new(this.loop, {required this.charges}) : super(repaint: loop);

  /// The scaffold's loop.
  final Animation<double> loop;

  /// The upcoming charges, any order.
  final List<WorldCharge> charges;

  static double _x(int day) =>
      _left +
      day.clamp(0, kSubsRibbonDays) / kSubsRibbonDays * (_right - _left);

  @override
  void paint(Canvas canvas, Size size) {
    final t = loop.value;
    const amber = ZadWorldColors.subscriptions;
    paintWorldGround(canvas, amber);

    const page = Rect.fromLTWH(125, 22, 295, 172);
    final rr = RRect.fromRectAndRadius(page, const Radius.circular(20));
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
          const Rect.fromLTWH(125, 22, 295, 30),
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
        ),
        Paint()..color = amber,
      );
    for (final x in <double>[185, 272, 360]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, 22), width: 8, height: 22),
          const Radius.circular(4),
        ),
        Paint()..color = const Color(0xFF7A4E06),
      );
    }

    // The ribbon and its weekly ticks.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(_left - 8, _ribbonY - 7, _right + 8, _ribbonY + 7),
        const Radius.circular(7),
      ),
      Paint()..color = _track,
    );
    final tick = Paint()
      ..color = _rim
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var d = 7; d <= kSubsRibbonDays; d += 7) {
      canvas.drawLine(
        Offset(_x(d), _ribbonY + 10),
        Offset(_x(d), _ribbonY + 18),
        tick,
      );
    }

    // Today: a dot with a ring that breathes.
    final pulse = worldTwinkle(t);
    canvas
      ..drawCircle(
        Offset(_x(0), _ribbonY),
        9 + 5 * pulse,
        Paint()..color = amber.withValues(alpha: 0.22 * (1 - pulse)),
      )
      ..drawCircle(Offset(_x(0), _ribbonY), 6, Paint()..color = amber);

    // One drop per charge, on a stem of one of three heights.
    final sorted = [...charges]..sort((a, b) => a.day.compareTo(b.day));
    for (final (i, c) in sorted.indexed) {
      if (c.day < 0 || c.day > kSubsRibbonDays) continue;
      final x = _x(c.day);
      final y =
          _ribbonY -
          32 -
          (i % 3) * 24 +
          worldBob(t, amplitude: 2, phase: i * 0.13);
      canvas.drawLine(
        Offset(x, _ribbonY),
        Offset(x, y),
        Paint()
          ..color = c.color.withValues(alpha: 0.4)
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
      if (c.day <= 3) {
        canvas.drawCircle(
          Offset(x, y),
          13 + 6 * worldTwinkle(t, phase: i * 0.2),
          Paint()..color = c.color.withValues(alpha: 0.25),
        );
      }
      canvas
        ..drawCircle(Offset(x, y), 11, Paint()..color = c.color)
        ..drawCircle(Offset(x, y), 4, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(SubscriptionsWorldScene old) => old.charges != charges;
}
