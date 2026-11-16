/// The shopping world's scene: a cart that bobs, and things falling into it.
library;

import 'package:flutter/material.dart';
import 'package:zad/core/design/tokens/zad_world_colors.dart';
import 'package:zad/shared/worlds/world_scene.dart';

// Illustrative one-off colours (a scene, not a shared component).
const Color _navy = Color(0xFF1B3B6B);
const List<Color> _things = <Color>[
  Color(0xFFF2B91E),
  Color(0xFFE5473C),
  Color(0xFF8BC34A),
  Color(0xFFFFFFFF),
];

/// Paints the cart. [filled] says the list has lines: the things fall in;
/// an empty list leaves a calm cart.
class ShopWorldScene extends CustomPainter {
  /// Creates the painter.
  new(this.loop, {required this.filled}) : super(repaint: loop);

  /// The scaffold's loop.
  final Animation<double> loop;

  /// Whether the list has anything to fall in.
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final t = loop.value;
    paintWorldGround(canvas, ZadWorldColors.shopping);
    canvas
      ..save()
      ..translate(0, worldBob(t, amplitude: 3));
    final basket = Path()
      ..moveTo(210, 70)
      ..lineTo(360, 70)
      ..lineTo(342, 160)
      ..lineTo(226, 160)
      ..close();
    canvas
      ..drawPath(basket, Paint()..color = ZadWorldColors.shopping)
      ..drawPath(
        Path()
          ..moveTo(190, 50)
          ..lineTo(214, 50)
          ..lineTo(240, 170),
        Paint()
          ..color = _navy
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    // The grill lines of the basket, drawn so it reads as a cart.
    final grill = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 3;
    for (final x in <double>[250, 285, 320]) {
      canvas.drawLine(Offset(x, 78), Offset(x - 3, 152), grill);
    }
    canvas
      ..drawCircle(const Offset(250, 196), 13, Paint()..color = _navy)
      ..drawCircle(const Offset(330, 196), 13, Paint()..color = _navy);
    if (filled) {
      for (var i = 0; i < _things.length; i++) {
        final f = worldFall(t, phase: i * 0.25);
        // Falls from above the cart and is gone as it lands.
        final y = 10 + 70 * f;
        final a = f < 0.8 ? 1.0 : (1 - f) / 0.2;
        canvas.drawCircle(
          Offset(250.0 + i * 24, y),
          11,
          Paint()..color = _things[i].withValues(alpha: a),
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(ShopWorldScene old) => old.filled != filled;
}
