/// The achievements world's scene: a shelf with trophy cups and stars that
/// twinkle. A cup is gold once earned, a grey silhouette until then — the
/// shelf holds `total` cups (at most five are drawn), `unlocked` of them lit.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:zad/core/design/tokens/zad_world_colors.dart';
import 'package:zad/shared/worlds/world_scene.dart';

// Illustrative one-off colours (a scene, not a shared component).
const Color _gold = Color(0xFFF5B93A);
const Color _goldDark = Color(0xFFC68216);
const Color _locked = Color(0xFFD3D8DE);
const Color _shelf = Color(0xFFE9D9B5);

/// Paints the trophy shelf.
class AchievementsWorldScene extends CustomPainter {
  /// Creates the painter.
  new(this.loop, {required this.unlocked, required this.total})
    : super(repaint: loop);

  /// The scaffold's loop.
  final Animation<double> loop;

  /// How many are earned.
  final int unlocked;

  /// How many there are.
  final int total;

  @override
  void paint(Canvas canvas, Size size) {
    final t = loop.value;
    paintWorldGround(canvas, ZadWorldColors.achievements);

    // The shelf.
    final shelf = RRect.fromRectAndRadius(
      const Rect.fromLTWH(200, 176, 210, 12),
      const Radius.circular(6),
    );
    canvas
      ..drawRRect(shelf, Paint()..color = _shelf)
      ..drawRRect(
        shelf.shift(const Offset(0, 5)),
        Paint()..color = _shelf.withValues(alpha: 0.5),
      );

    final cups = math.min(5, math.max(total, 1));
    final lit = total == 0
        ? 0
        : (unlocked / total * cups).ceil().clamp(0, cups);
    for (var i = 0; i < cups; i++) {
      // Biggest in the middle, like a podium.
      final big = i == cups ~/ 2;
      final h = big ? 78.0 : 58.0;
      final x = 222.0 + i * (170 / math.max(cups - 1, 1));
      _cup(canvas, Offset(x, 176), h, i < lit, t, i);
    }

    // Stars above the shelf.
    for (final (i, o) in const <Offset>[
      Offset(232, 42),
      Offset(300, 26),
      Offset(372, 48),
      Offset(404, 112),
    ].indexed) {
      _star(
        canvas,
        o,
        7 + 3 * worldTwinkle(t, phase: i * 0.25),
        _gold.withValues(alpha: 0.35 + 0.4 * worldTwinkle(t, phase: i * 0.25)),
      );
    }
  }

  void _cup(Canvas canvas, Offset base, double h, bool lit, double t, int i) {
    final fill = Paint()..color = lit ? _gold : _locked;
    final edge = Paint()
      ..color = lit ? _goldDark : const Color(0xFFB8BEC6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round;
    final w = h * 0.55;
    final bob = lit ? worldBob(t, amplitude: 1.5, phase: i * 0.2) : 0.0;
    canvas
      ..save()
      ..translate(0, bob);
    final top = base.dy - h;
    // The foot and stem.
    final foot = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(base.dx, base.dy - 4),
        width: w * 0.8,
        height: 8,
      ),
      const Radius.circular(3),
    );
    final stem = Rect.fromCenter(
      center: Offset(base.dx, base.dy - h * 0.22),
      width: w * 0.16,
      height: h * 0.26,
    );
    // The bowl.
    final bowl = Path()
      ..moveTo(base.dx - w / 2, top)
      ..lineTo(base.dx + w / 2, top)
      ..quadraticBezierTo(
        base.dx + w / 2,
        top + h * 0.5,
        base.dx,
        top + h * 0.56,
      )
      ..quadraticBezierTo(base.dx - w / 2, top + h * 0.5, base.dx - w / 2, top)
      ..close();
    // The handles.
    final handles = Path()
      ..addArc(
        Rect.fromCenter(
          center: Offset(base.dx - w / 2, top + h * 0.2),
          width: w * 0.4,
          height: h * 0.28,
        ),
        math.pi / 2,
        math.pi,
      )
      ..addArc(
        Rect.fromCenter(
          center: Offset(base.dx + w / 2, top + h * 0.2),
          width: w * 0.4,
          height: h * 0.28,
        ),
        -math.pi / 2,
        math.pi,
      );
    canvas
      ..drawPath(handles, edge)
      ..drawRRect(foot, fill)
      ..drawRRect(foot, edge)
      ..drawRect(stem, fill)
      ..drawPath(bowl, fill)
      ..drawPath(bowl, edge);
    if (lit) {
      _star(canvas, Offset(base.dx, top + h * 0.26), w * 0.2, Colors.white);
    }
    canvas.restore();
  }

  void _star(Canvas canvas, Offset c, double r, Color color) {
    final p = Path();
    for (var k = 0; k < 10; k++) {
      final rad = k.isEven ? r : r * 0.45;
      final a = -math.pi / 2 + k * math.pi / 5;
      final pt = Offset(c.dx + rad * math.cos(a), c.dy + rad * math.sin(a));
      k == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(p..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(AchievementsWorldScene old) =>
      old.unlocked != unlocked || old.total != total;
}
