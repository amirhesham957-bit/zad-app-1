/// The pharmacy world's scene: a blister pack with its pills lit, one pill
/// floating above it. A dose taken pops the next pill out of the pack and it
/// drifts up and away.
library;

import 'package:flutter/material.dart';
import 'package:zad/core/design/tokens/zad_world_colors.dart';
import 'package:zad/shared/worlds/world_scene.dart';

// Illustrative one-off colours (a scene, not a shared component).
const Color _packTop = Color(0xFF6B5FC7);
const Color _packBottom = Color(0xFF4A3F94);
const Color _pillLight = Color(0xFFFFFFFF);
const Color _pillMid = Color(0xFFD9D3F5);
const Color _pillEdge = Color(0xFFA9A4DB);
const Color _empty = Color(0xFF2E2670);

/// The number of cells in the painted pack.
const int kPharmacyPackCells = 12;

/// Paints the pack. [popped] cells are empty; [pop] is 0..1 while the last
/// one leaves.
class PharmacyWorldScene extends CustomPainter {
  /// Creates the painter.
  new(this.loop, {required this.popped, required this.pop})
    : super(repaint: Listenable.merge(<Listenable>[loop, pop]));

  /// The scaffold's loop.
  final Animation<double> loop;

  /// How many of the pack's cells are empty (doses taken today).
  final int popped;

  /// 0..1 progress of the pill that just left; 1 when none is leaving.
  final Animation<double> pop;

  @override
  void paint(Canvas canvas, Size size) {
    paintWorldGround(canvas, ZadWorldColors.pharmacy);
    final t = loop.value;
    canvas
      ..save()
      ..translate(298, 118)
      ..rotate(-0.1)
      ..translate(-298, -118);
    final pack = RRect.fromRectAndRadius(
      const Rect.fromLTWH(218, 40, 160, 156),
      const Radius.circular(22),
    );
    canvas
      ..drawRRect(
        pack,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[_packTop, _packBottom],
          ).createShader(pack.outerRect),
      )
      ..drawRRect(
        pack,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    final leaving = popped - 1;
    for (var i = 0; i < kPharmacyPackCells; i++) {
      final c = Offset(246 + (i % 4) * 36.0, 70 + (i ~/ 4) * 42.0);
      final gone = i < popped;
      if (gone) {
        canvas.drawCircle(
          c,
          13,
          Paint()..color = _empty.withValues(alpha: 0.85),
        );
      }
      if (!gone || (i == leaving && pop.value < 1)) {
        final p = gone ? pop.value : 0.0;
        _pill(
          canvas,
          c.translate(0, -34 * p),
          13 * (1 - 0.6 * p),
          1 - p,
          lit: !gone,
          sparkle: !gone ? worldTwinkle(t, phase: i * 0.13) : 0,
        );
      }
    }
    canvas.restore();
    // The pill floating over the pack.
    final bob = worldBob(t, amplitude: 5);
    canvas
      ..save()
      ..translate(206, 52 + bob)
      ..rotate(-0.6);
    final capsule = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-17, -8, 34, 16),
      const Radius.circular(8),
    );
    canvas
      ..drawRRect(capsule, Paint()..color = Colors.white)
      ..drawRRect(
        RRect.fromRectAndCorners(
          const Rect.fromLTWH(0, -8, 17, 16),
          topRight: const Radius.circular(8),
          bottomRight: const Radius.circular(8),
        ),
        Paint()..color = ZadWorldColors.pharmacy,
      )
      ..restore();
  }

  void _pill(
    Canvas canvas,
    Offset c,
    double r,
    double alpha, {
    required bool lit,
    required double sparkle,
  }) {
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas
      ..drawCircle(
        c.translate(0, 2),
        r,
        Paint()..color = Colors.black.withValues(alpha: 0.22 * alpha),
      )
      ..drawCircle(
        c,
        r,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.3, -0.4),
            colors: <Color>[_pillLight, _pillMid, _pillEdge],
            stops: <double>[0, 0.65, 1],
          ).createShader(rect)
          ..color = Colors.white.withValues(alpha: alpha),
      );
    if (lit && sparkle > 0.85) {
      canvas.drawCircle(
        c.translate(-4, -4),
        2.2,
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(PharmacyWorldScene old) => old.popped != popped;
}
