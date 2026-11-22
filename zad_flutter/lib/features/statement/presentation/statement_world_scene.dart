/// The statement world's scene: the spending curve drawing itself, and the
/// last three months' points twinkling once it is done.
library;

import 'package:flutter/material.dart';
import 'package:zad/core/design/tokens/zad_world_colors.dart';
import 'package:zad/shared/worlds/world_scene.dart';

// Illustrative one-off colours (a scene, not a shared component).
const Color _line = Color(0xFFC68216);
const Color _fill = Color(0xFFF5B93A);

/// What the curve draws when there are too few months to draw: a calm climb.
const List<double> kStatementSampleCurve = <double>[
  0.12,
  0.3,
  0.24,
  0.5,
  0.66,
  0.9,
];

/// Paints the curve through [series] (0..1, oldest first).
class StatementWorldScene extends CustomPainter {
  /// Creates the painter. [draw] runs 0..1 once, as the curve draws itself.
  new(this.loop, this.draw, this.series)
    : super(repaint: Listenable.merge(<Listenable>[loop, draw]));

  /// The scaffold's loop.
  final Animation<double> loop;

  /// How much of the curve is drawn.
  final Animation<double> draw;

  /// The points, 0..1.
  final List<double> series;

  @override
  void paint(Canvas canvas, Size size) {
    paintWorldGround(canvas, ZadWorldColors.statement);
    final pts = _points();
    final path = _smooth(pts);
    final t = Curves.easeOut.transform(draw.value);
    final metrics = path.computeMetrics().toList();
    final total = metrics.fold<double>(0, (s, m) => s + m.length);
    final shown = Path();
    var left = total * t;
    for (final m in metrics) {
      if (left <= 0) break;
      shown.addPath(m.extractPath(0, left.clamp(0, m.length)), Offset.zero);
      left -= m.length;
    }
    if (t > 0) {
      final under = Path.from(shown)
        ..lineTo(pts.last.dx * t + pts.first.dx * (1 - t), 196)
        ..lineTo(pts.first.dx, 196)
        ..close();
      canvas.drawPath(under, Paint()..color = _fill.withValues(alpha: 0.14));
    }
    canvas.drawPath(
      shown,
      Paint()
        ..color = _line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    // The last three months twinkle; the earlier ones sit still.
    for (var i = 0; i < pts.length; i++) {
      final reached = pts.length == 1 ? 1.0 : i / (pts.length - 1);
      if (t < reached) continue;
      final recent = i >= pts.length - 3;
      final tw = recent ? worldTwinkle(loop.value, phase: i * 0.15) : 0.0;
      canvas
        ..drawCircle(
          pts[i],
          recent ? 9 + 4 * tw : 5,
          Paint()..color = _line.withValues(alpha: recent ? 0.16 : 0.0),
        )
        ..drawCircle(pts[i], recent ? 7 : 5, Paint()..color = _line)
        ..drawCircle(pts[i], 2.5, Paint()..color = Colors.white);
    }
  }

  List<Offset> _points() {
    final s = series.length >= 2 ? series : kStatementSampleCurve;
    const left = 190.0;
    const right = 408.0;
    return <Offset>[
      for (var i = 0; i < s.length; i++)
        Offset(
          left + (right - left) * i / (s.length - 1),
          190 - 140 * s[i].clamp(0.0, 1.0),
        ),
    ];
  }

  /// A smooth curve through [p] (Catmull-Rom as cubic Béziers).
  Path _smooth(List<Offset> p) {
    final path = Path()..moveTo(p.first.dx, p.first.dy);
    for (var i = 0; i < p.length - 1; i++) {
      final p0 = i == 0 ? p[i] : p[i - 1];
      final p1 = p[i];
      final p2 = p[i + 1];
      final p3 = i + 2 < p.length ? p[i + 2] : p[i + 1];
      path.cubicTo(
        p1.dx + (p2.dx - p0.dx) / 6,
        p1.dy + (p2.dy - p0.dy) / 6,
        p2.dx - (p3.dx - p1.dx) / 6,
        p2.dy - (p3.dy - p1.dy) / 6,
        p2.dx,
        p2.dy,
      );
    }
    return path;
  }

  @override
  bool shouldRepaint(StatementWorldScene old) => old.series != series;
}
