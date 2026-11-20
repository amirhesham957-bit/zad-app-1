/// «اصطاد النجوم»'s night sky: stars falling to the ground. Zado is the
/// companion widget laid over it (`star_catch_game.dart`). Illustrative
/// one-off colours: a scene, not a shared widget.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:zad/shared/companion/domain/star_game.dart';
import 'package:zad/shared/companion/presentation/game_art.dart';

/// Height of the grass strip under Zado, in world units.
const double starGroundThickness = 40;

/// Paints `game` each time `repaint` ticks. With `twinkle` off (reduced
/// motion) the stars do not spin as they fall.
class StarFieldPainter extends CustomPainter {
  /// Creates it.
  new({required this.game, required Listenable repaint, this.twinkle = true})
    : super(repaint: repaint);

  /// The round.
  final StarGame game;

  /// Stars turn as they fall.
  final bool twinkle;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / StarGame.width;
    final sy = size.height / StarGame.height;
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF1E2147), Color(0xFF5B5FA8)],
        ).createShader(rect),
    );
    // A fixed handful of far-away dots.
    final dots = Paint()..color = const Color(0x55FFFFFF);
    for (var i = 0; i < 24; i++) {
      final x = (i * 97 % 360) * sx;
      final y = (i * 53 % 440) * sy;
      canvas.drawCircle(Offset(x, y), (0.8 + i % 3 * 0.5) * sx, dots);
    }
    final ground = size.height - starGroundThickness * sy;
    canvas.drawRect(
      Rect.fromLTWH(0, ground, size.width, size.height - ground),
      Paint()..color = const Color(0xFF2F7D55),
    );
    for (final s in game.stars) {
      paintStar(
        canvas,
        Offset(s.x * sx, s.fall * sy),
        13 * sx,
        turn: twinkle ? s.fall / 60 : 0,
      );
    }
    // The catching reach, as a faint basket under Zado.
    final basket = Rect.fromCenter(
      center: Offset(game.zadoX * sx, StarGame.catchLine * sy + 8 * sy),
      width: StarGame.reach * 2 * sx,
      height: 6 * sy,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(basket, Radius.circular(3 * sy)),
      Paint()..color = const Color(0x66FFD54F),
    );
  }

  @override
  bool shouldRepaint(StarFieldPainter old) =>
      old.game != game || old.twinkle != twinkle;
}

/// Where the orb stands for a Zado at [x]: its left edge in the view.
double starOrbLeft(double x, double scale, double orb) =>
    math.max(0, x * scale - orb / 2);
