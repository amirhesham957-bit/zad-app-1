/// «نطّة زادو»'s scene: sky, hills, ground, crates and seeds. Zado himself is
/// the companion widget laid over this canvas, so the user's own character
/// runs. Illustrative one-off colours: a scene, not a shared widget.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:zad/shared/companion/domain/run_game.dart';
import 'package:zad/shared/companion/presentation/game_art.dart';

/// Height of the strip of ground under Zado's feet, in world units.
const double runGroundThickness = 56;

/// Paints `game` each time `repaint` ticks.
class RunPainter extends CustomPainter {
  /// Creates it. With `parallax` off (reduced motion) the hills stand still.
  new({required this.game, required Listenable repaint, this.parallax = true})
    : super(repaint: repaint);

  /// The round.
  final RunGame game;

  /// Hills drift slower than the ground.
  final bool parallax;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / RunGame.width;
    final groundY = size.height - runGroundThickness * s;
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFFCDEBFF), Color(0xFFF3FBF6)],
        ).createShader(rect),
    );
    final d = parallax ? game.distance : 0.0;
    _hills(
      canvas,
      size,
      groundY,
      d * 0.12 * s,
      70 * s,
      const Color(0xFFBFE3CF),
      260 * s,
    );
    _hills(
      canvas,
      size,
      groundY,
      d * 0.3 * s,
      44 * s,
      const Color(0xFF9FD3B8),
      180 * s,
    );

    canvas
      ..drawRect(
        Rect.fromLTWH(0, groundY, size.width, size.height - groundY),
        Paint()..color = const Color(0xFF7A5A3A),
      )
      ..drawRect(
        Rect.fromLTWH(0, groundY, size.width, 8 * s),
        Paint()..color = const Color(0xFF3F9E6B),
      );
    // Sleepers scroll with the ground so speed can be felt (still under
    // reduced motion: the crates move anyway, this is only decoration).
    final mark = Paint()..color = const Color(0x33000000);
    final period = 48 * s;
    final shift = (d * s) % period;
    for (var x = -shift; x < size.width; x += period) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, groundY + 26 * s, 22 * s, 5 * s),
          Radius.circular(2 * s),
        ),
        mark,
      );
    }
    for (final c in game.crates) {
      _crate(canvas, c, groundY, s);
    }
    for (final seed in game.seeds) {
      if (!seed.taken) {
        paintSeed(canvas, Offset(seed.x * s, groundY - seed.y * s), 9 * s);
      }
    }
  }

  void _hills(
    Canvas canvas,
    Size size,
    double groundY,
    double shift,
    double amp,
    Color color,
    double wave,
  ) {
    final path = Path()..moveTo(0, groundY);
    for (var x = 0.0; x <= size.width + 4; x += 4) {
      final y =
          groundY -
          amp * (0.55 + 0.45 * math.sin((x + shift) / wave * 2 * math.pi));
      path.lineTo(x, y);
    }
    path
      ..lineTo(size.width, groundY)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _crate(Canvas canvas, RunCrate c, double groundY, double s) {
    final r = Rect.fromLTWH(c.x * s, groundY - c.h * s, c.w * s, c.h * s);
    final body = RRect.fromRectAndRadius(r, Radius.circular(4 * s));
    final line = Paint()
      ..color = const Color(0xFF8A5A2B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * s;
    canvas
      ..drawRRect(body, Paint()..color = const Color(0xFFC98A4B))
      ..drawRRect(body, line)
      ..drawLine(r.topLeft, r.bottomRight, line)
      ..drawLine(r.topRight, r.bottomLeft, line);
  }

  @override
  bool shouldRepaint(RunPainter old) =>
      old.game != game || old.parallax != parallax;
}
