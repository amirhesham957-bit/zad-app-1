/// The prices world's scene: a price tag hanging from a string and swinging,
/// with a rising arrow and a falling arrow beside it. The arrow for a price
/// that moved today glows; the other rests.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_world_colors.dart';
import 'package:zad/shared/worlds/art/art_painter.dart';
import 'package:zad/shared/worlds/art/zad_art.dart' show zadIconSvg;
import 'package:zad/shared/worlds/art/zad_art_kinds.dart';
import 'package:zad/shared/worlds/world_scene.dart';

// Illustrative one-off colours (a scene, not a shared component).
const Color _string = Color(0xFF7A5A1E);
const Color _up = ZadColors.green700;
final Color _down = ZadColors.terracottaRust;

/// Paints the swinging tag and the two arrows.
class PricesWorldScene extends CustomPainter {
  /// Creates the painter. [up] / [down]: a price moved that way today.
  new(this.loop, {required this.up, required this.down}) : super(repaint: loop);

  /// The scaffold's loop.
  final Animation<double> loop;

  /// Some price is rising.
  final bool up;

  /// Some price is falling.
  final bool down;

  static final ArtPainter _tag = ArtPainter(
    id: 'i:tag',
    svg: zadIconSvg(ZadIconArt.tag),
  );

  @override
  void paint(Canvas canvas, Size size) {
    final t = loop.value;
    paintWorldGround(canvas, ZadWorldColors.prices);

    // The tag, swinging from a nail.
    const nail = Offset(225, 6);
    final swing = math.sin(t * 2 * math.pi) * 0.09;
    canvas
      ..save()
      ..translate(nail.dx, nail.dy)
      ..rotate(swing)
      ..drawLine(
        Offset.zero,
        const Offset(0, 76),
        Paint()
          ..color = _string
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      )
      ..translate(-110, 30);
    _tag.paint(canvas, const Size(160, 160));
    canvas
      ..restore()
      ..drawCircle(nail, 6, Paint()..color = _string);

    _arrow(canvas, const Offset(350, 70), up: true, glow: up, t: t);
    _arrow(canvas, const Offset(350, 150), up: false, glow: down, t: t);
  }

  void _arrow(
    Canvas canvas,
    Offset c, {
    required bool up,
    required bool glow,
    required double t,
  }) {
    final color = up ? _up : _down;
    final dir = up ? -1.0 : 1.0;
    final bob = glow ? worldBob(t, amplitude: 5) * dir : 0.0;
    final alpha = glow ? 1.0 : 0.3;
    if (glow) {
      canvas.drawCircle(
        c,
        34 + 6 * worldTwinkle(t),
        Paint()..color = color.withValues(alpha: 0.16),
      );
    }
    final p = Path()
      ..moveTo(c.dx, c.dy + dir * 26 + bob)
      ..lineTo(c.dx + 24, c.dy - dir * 2 + bob)
      ..lineTo(c.dx + 10, c.dy - dir * 2 + bob)
      ..lineTo(c.dx + 10, c.dy - dir * 24 + bob)
      ..lineTo(c.dx - 10, c.dy - dir * 24 + bob)
      ..lineTo(c.dx - 10, c.dy - dir * 2 + bob)
      ..lineTo(c.dx - 24, c.dy - dir * 2 + bob)
      ..close();
    canvas.drawPath(
      p,
      Paint()
        ..color = color.withValues(alpha: alpha)
        ..style = PaintingStyle.fill
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(PricesWorldScene old) => old.up != up || old.down != down;
}
