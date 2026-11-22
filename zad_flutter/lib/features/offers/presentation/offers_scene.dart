/// The offers world's scene: a gift box that bobs, with two coupon tickets
/// swaying beside it. With live offers the tickets glow.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:zad/core/design/tokens/zad_world_colors.dart';
import 'package:zad/shared/worlds/art/art_painter.dart';
import 'package:zad/shared/worlds/art/zad_art.dart' show zadIconSvg;
import 'package:zad/shared/worlds/art/zad_art_kinds.dart';
import 'package:zad/shared/worlds/world_scene.dart';

// Illustrative one-off colours (a scene, not a shared component).
const Color _gold = Color(0xFFF5B93A);
const Color _coral = Color(0xFFE5473C);

/// Paints the gift and the tickets. [live]: some offer is running.
class OffersWorldScene extends CustomPainter {
  /// Creates the painter.
  new(this.loop, {required this.live}) : super(repaint: loop);

  /// The scaffold's loop.
  final Animation<double> loop;

  /// Whether any offer is live.
  final bool live;

  static final ArtPainter _gift = ArtPainter(
    id: 'i:gift',
    svg: zadIconSvg(ZadIconArt.gift),
  );

  @override
  void paint(Canvas canvas, Size size) {
    final t = loop.value;
    paintWorldGround(canvas, ZadWorldColors.offers);
    final bob = worldBob(t, amplitude: 5);
    canvas
      ..save()
      ..translate(215, 40 + bob)
      ..translate(-80, 0);
    _gift.paint(canvas, const Size(160, 160));
    canvas.restore();
    _ticket(canvas, const Offset(350, 80), _gold, -0.2, t, 0);
    _ticket(canvas, const Offset(345, 160), _coral, 0.14, t, 0.4);
  }

  void _ticket(
    Canvas canvas,
    Offset c,
    Color color,
    double tilt,
    double t,
    double phase,
  ) {
    final sway = math.sin((t + phase) * 2 * math.pi) * 0.06;
    final glow = live ? 0.14 + 0.1 * worldTwinkle(t, phase: phase) : 0.0;
    canvas
      ..save()
      ..translate(c.dx, c.dy)
      ..rotate(tilt + sway);
    if (live) {
      canvas.drawCircle(
        Offset.zero,
        50,
        Paint()..color = color.withValues(alpha: glow),
      );
    }
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: 92, height: 46),
      const Radius.circular(10),
    );
    canvas
      ..drawRRect(body, Paint()..color = color)
      ..drawLine(
        const Offset(-12, -16),
        const Offset(-12, 16),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.7)
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(2, -6, 34, 7),
          const Radius.circular(3.5),
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.75),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(OffersWorldScene old) => old.live != live;
}
