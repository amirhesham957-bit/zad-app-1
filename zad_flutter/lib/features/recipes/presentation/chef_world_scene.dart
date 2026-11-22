/// The chef world's scene: a pot on the counter with its lid rattling, steam
/// rising, and the day's food falling into it. While the chef is thinking the
/// fire under the pot glows and the lid rattles faster.
library;

import 'package:flutter/material.dart';
import 'package:zad/core/design/tokens/zad_world_colors.dart';
import 'package:zad/shared/worlds/world_scene.dart';

// Illustrative one-off colours (a scene, not a shared component).
const Color _potRed = Color(0xFFE5473C);
const Color _potDark = Color(0xFFA9271D);
const Color _lid = Color(0xFF7A1F1A);
const Color _counter = Color(0xFFE9DCC6);
const Color _fire = Color(0xFFFFE08A);
const List<(Color, double)> _foods = <(Color, double)>[
  (Color(0xFFF2B91E), 8),
  (Color(0xFFE5473C), 6),
  (Color(0xFF8BC34A), 6),
  (Color(0xFFA0522D), 5),
  (Color(0xFFF5E6C8), 7),
];

/// Paints the pot. [cooking] is whether the chef is working on an answer.
class ChefWorldScene extends CustomPainter {
  /// Creates the painter.
  new(this.loop, {required this.cooking}) : super(repaint: loop);

  /// The scaffold's loop.
  final Animation<double> loop;

  /// Whether an answer is being cooked.
  final bool cooking;

  @override
  void paint(Canvas canvas, Size size) {
    final t = loop.value;
    paintWorldGround(canvas, ZadWorldColors.chef);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(30, 196, 370, 16),
        const Radius.circular(8),
      ),
      Paint()..color = _counter,
    );
    final glow = cooking ? 0.5 + 0.5 * worldTwinkle(t) : 0.35;
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(280, 194), width: 150, height: 22),
      Paint()..color = _fire.withValues(alpha: glow),
    );
    _food(canvas, t);
    _steam(canvas, t);
    // The lid rattles a little; more while the chef thinks.
    final rattle = worldBob(
      t * (cooking ? 4 : 1),
      amplitude: cooking ? 3 : 1.5,
    );
    canvas
      ..save()
      ..translate(0, -2 + rattle)
      ..drawOval(
        Rect.fromCenter(center: const Offset(280, 112), width: 150, height: 18),
        Paint()..color = _lid,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(269, 98, 22, 10),
          const Radius.circular(4),
        ),
        Paint()..color = _lid,
      )
      ..restore();
    final body = Path()
      ..moveTo(215, 118)
      ..lineTo(345, 118)
      ..lineTo(345, 158)
      ..arcToPoint(const Offset(305, 192), radius: const Radius.circular(36))
      ..lineTo(255, 192)
      ..arcToPoint(const Offset(215, 158), radius: const Radius.circular(36))
      ..close();
    canvas
      ..drawPath(
        body,
        Paint()
          ..shader = const LinearGradient(colors: <Color>[_potRed, _potDark])
              .createShader(const Rect.fromLTWH(215, 118, 130, 74)),
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(194, 128, 24, 11),
          const Radius.circular(5),
        ),
        Paint()..color = _lid,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(342, 128, 24, 11),
          const Radius.circular(5),
        ),
        Paint()..color = _lid,
      )
      ..drawLine(
        const Offset(232, 136),
        const Offset(258, 136),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.35)
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round,
      );
  }

  void _food(Canvas canvas, double t) {
    for (var i = 0; i < _foods.length; i++) {
      final f = worldFall(t, phase: i * 0.2);
      final (color, r) = _foods[i];
      canvas.drawCircle(
        Offset(250 + i * 16.0, 24 + f * 80),
        r,
        Paint()..color = color.withValues(alpha: 1 - f * f),
      );
    }
  }

  void _steam(Canvas canvas, double t) {
    for (var i = 0; i < 3; i++) {
      final p = worldFall(t, phase: i * 0.33);
      final x = 256 + i * 24.0;
      final y = 100 - p * 46;
      canvas.drawPath(
        Path()
          ..moveTo(x, y)
          ..quadraticBezierTo(x - 9, y - 10, x, y - 20),
        Paint()
          ..color = const Color(0xFFD4D7D0).withValues(alpha: 1 - p)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(ChefWorldScene old) => old.cooking != cooking;
}
