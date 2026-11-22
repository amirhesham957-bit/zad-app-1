/// The transactions world's scene: a printer with a receipt hanging out of
/// it. Each time a new transaction arrives the receipt prints a little
/// longer and eases back.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:zad/core/design/tokens/zad_world_colors.dart';
import 'package:zad/shared/worlds/world_scene.dart';

// Illustrative one-off colours (a scene, not a shared component).
const Color _body = Color(0xFF1B4332);
const Color _line = Color(0xFFDCE6E0);
const Color _paperEdge = Color(0xFFDCE6E0);
const List<Color> _amounts = <Color>[
  Color(0xFF0F9B76),
  Color(0xFFC68216),
  Color(0xFFE5473C),
  Color(0xFF0F9B76),
  Color(0xFFC68216),
];

/// Paints the printer. [printing] is 0..1 while a receipt comes out.
class TransactionsWorldScene extends CustomPainter {
  /// Creates the painter.
  new(this.loop, this.printing)
    : super(repaint: Listenable.merge(<Listenable>[loop, printing]));

  /// The scaffold's loop.
  final Animation<double> loop;

  /// A new transaction arrived: 0 resting, rising to 1 and back.
  final Animation<double> printing;

  @override
  void paint(Canvas canvas, Size size) {
    paintWorldGround(canvas, ZadWorldColors.transactions);
    canvas
      ..save()
      ..translate(0, worldBob(loop.value, amplitude: 3));
    // The receipt comes out of the slot, under the printer's lid.
    final p = Curves.easeInOut.transform(
      math.sin(printing.value * math.pi).clamp(0.0, 1.0),
    );
    final len = 100 + 56 * p;
    const left = 222.0;
    const width = 126.0;
    const top = 62.0;
    final paper = Path()
      ..moveTo(left, top)
      ..lineTo(left + width, top)
      ..lineTo(left + width, top + len);
    // A torn, zig-zag bottom edge.
    const teeth = 7;
    for (var i = teeth; i > 0; i--) {
      final x = left + width * (i - 0.5) / teeth;
      paper
        ..lineTo(x, top + len + 7)
        ..lineTo(left + width * (i - 1) / teeth, top + len);
    }
    paper.close();
    canvas
      ..drawShadow(paper, Colors.black.withValues(alpha: 0.4), 3, false)
      ..drawPath(paper, Paint()..color = Colors.white)
      ..drawPath(
        paper,
        Paint()
          ..color = _paperEdge
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      )
      ..save()
      ..clipPath(paper);
    for (var i = 0; i < 5; i++) {
      final y = top + 22 + i * 24.0;
      if (y > top + len - 8) break;
      canvas
        ..drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(left + 14, y, 54 + ((i * 23) % 34).toDouble(), 7),
            const Radius.circular(3.5),
          ),
          Paint()..color = _line,
        )
        ..drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(left + width - 40, y, 24, 7),
            const Radius.circular(3.5),
          ),
          Paint()..color = _amounts[i],
        );
    }
    canvas.restore();
    // The printer itself, over the paper's top edge.
    final lid = RRect.fromRectAndRadius(
      const Rect.fromLTWH(200, 22, 170, 44),
      const Radius.circular(12),
    );
    canvas
      ..drawRRect(lid, Paint()..color = _body)
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(214, 54, 142, 8),
          const Radius.circular(4),
        ),
        Paint()..color = Colors.black.withValues(alpha: 0.45),
      )
      ..drawCircle(
        const Offset(228, 38),
        4,
        Paint()
          ..color = Color.lerp(
            const Color(0xFF6EE7B7),
            Colors.white,
            printing.value > 0 ? 0 : worldTwinkle(loop.value),
          )!,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(TransactionsWorldScene old) => false;
}
