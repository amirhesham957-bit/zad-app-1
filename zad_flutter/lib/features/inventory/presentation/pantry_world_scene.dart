/// The pantry world's scene: a fridge that breathes, shelves with produce,
/// and the carton that is about to run out, twinkling.
library;

import 'package:flutter/material.dart';
import 'package:zad/core/design/tokens/zad_world_colors.dart';
import 'package:zad/shared/worlds/world_scene.dart';

// Illustrative one-off colours (a scene, not a shared component).
const Color _frame = Color(0xFFD6E9DE);
const Color _red = Color(0xFFE5473C);

/// Paints the fridge. [running] is whether something is running out: the
/// carton then glows red and twinkles; otherwise it is as calm as the rest.
class PantryWorldScene extends CustomPainter {
  /// Creates the painter.
  new(this.loop, {required this.running}) : super(repaint: loop);

  /// The scaffold's loop.
  final Animation<double> loop;

  /// Whether an item is about to run out.
  final bool running;

  @override
  void paint(Canvas canvas, Size size) {
    final t = loop.value;
    paintWorldGround(canvas, ZadWorldColors.inventory);
    canvas
      ..save()
      ..translate(0, worldBob(t));
    final stroke = Paint()
      ..color = _frame
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(230, 20, 150, 190),
      const Radius.circular(20),
    );
    canvas
      ..drawRRect(body, Paint()..color = Colors.white)
      ..drawRRect(body, stroke)
      ..drawLine(const Offset(230, 84), const Offset(380, 84), stroke)
      ..drawLine(const Offset(230, 146), const Offset(380, 146), stroke);
    void box(Rect r, Color c, [double rad = 5]) => canvas.drawRRect(
      RRect.fromRectAndRadius(r, Radius.circular(rad)),
      Paint()..color = c,
    );
    box(const Rect.fromLTWH(246, 40, 24, 40), const Color(0xFFE6F4EC));
    box(const Rect.fromLTWH(276, 48, 20, 32), const Color(0xFFFFE8B8), 4);
    canvas.drawCircle(const Offset(330, 64), 16, Paint()..color = _red);
    box(const Rect.fromLTWH(352, 44, 18, 36), const Color(0xFFF2B91E), 4);
    box(const Rect.fromLTWH(246, 100, 40, 40), const Color(0xFF9ED9BC), 6);
    _carton(canvas, t);
    canvas.drawCircle(
      const Offset(350, 122),
      14,
      Paint()..color = const Color(0xFF8BC34A),
    );
    box(const Rect.fromLTWH(246, 160, 120, 40), const Color(0xFFF4F6F2), 8);
    canvas.restore();
  }

  void _carton(Canvas canvas, double t) {
    const r = Rect.fromLTWH(300, 96, 22, 44);
    final tw = running ? worldTwinkle(t) : 0.0;
    if (running) {
      canvas.drawCircle(
        r.center,
        20 + 6 * tw,
        Paint()..color = _red.withValues(alpha: 0.10 + 0.18 * tw),
      );
    }
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(4));
    canvas
      ..drawRRect(rr, Paint()..color = Colors.white)
      ..drawRRect(
        rr,
        Paint()
          ..color = running ? _red : _frame
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      )
      // The label stripe, drawn rather than written.
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(305, 112, 12, 8),
          const Radius.circular(2),
        ),
        Paint()..color = (running ? _red : _frame).withValues(alpha: 0.7),
      );
  }

  @override
  bool shouldRepaint(PantryWorldScene old) => old.running != running;
}
