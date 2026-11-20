/// The games' drawn art: the seed, the streak flame, a star, a ball and one
/// small emblem per game for the hub. Everything is a `CustomPainter` (no
/// emoji, no images). One-off colours are fine here: these are illustrations.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:zad/shared/companion/domain/zad_game.dart';

const Color _gold = Color(0xFFF2B632);
const Color _goldDark = Color(0xFFB97D0D);

/// A seed, tilted, drawn in [size].
class SeedIcon extends StatelessWidget {
  /// Creates one.
  const new({this.size = 16, super.key});

  /// Box side.
  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: const _SeedPainter());
}

class _SeedPainter extends CustomPainter {
  const new();

  @override
  void paint(Canvas canvas, Size size) =>
      paintSeed(canvas, size.center(Offset.zero), size.shortestSide * 0.45);

  @override
  bool shouldRepaint(_SeedPainter old) => false;
}

/// A seed centred at [at] with radius [r].
void paintSeed(Canvas canvas, Offset at, double r) {
  canvas
    ..save()
    ..translate(at.dx, at.dy)
    ..rotate(-0.5);
  final body = Rect.fromCenter(
    center: Offset.zero,
    width: r * 1.5,
    height: r * 2.1,
  );
  canvas
    ..drawOval(body, Paint()..color = _gold)
    ..drawOval(
      body,
      Paint()
        ..color = _goldDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.18,
    )
    ..drawLine(
      Offset(0, -r * 0.8),
      Offset(0, r * 0.8),
      Paint()
        ..color = _goldDark
        ..strokeWidth = r * 0.15,
    )
    ..restore();
}

/// A five-point star centred at [at] with outer radius [r].
void paintStar(Canvas canvas, Offset at, double r, {double turn = 0}) {
  final path = Path();
  for (var i = 0; i < 10; i++) {
    final radius = i.isEven ? r : r * 0.45;
    final a = -math.pi / 2 + turn + i * math.pi / 5;
    final p = at + Offset(math.cos(a), math.sin(a)) * radius;
    if (i == 0) {
      path.moveTo(p.dx, p.dy);
    } else {
      path.lineTo(p.dx, p.dy);
    }
  }
  path.close();
  canvas
    ..drawPath(path, Paint()..color = const Color(0xFFFFD54F))
    ..drawPath(
      path,
      Paint()
        ..color = _goldDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.12
        ..strokeJoin = StrokeJoin.round,
    );
}

/// The streak's flame: warm when the streak is alive, grey when not.
class FlameIcon extends StatelessWidget {
  /// Creates one.
  const new({required this.lit, this.size = 24, super.key});

  /// The streak is alive.
  final bool lit;

  /// Height; the width is 0.8 of it.
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(size * 0.8, size),
    painter: _FlamePainter(lit: lit),
  );
}

class _FlamePainter extends CustomPainter {
  const new({required this.lit});

  final bool lit;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final outer = Path()
      ..moveTo(w * 0.5, 0)
      ..cubicTo(w * 0.55, h * 0.3, w * 1.05, h * 0.45, w * 0.92, h * 0.72)
      ..cubicTo(w * 0.85, h * 0.95, w * 0.62, h, w * 0.5, h)
      ..cubicTo(w * 0.3, h, w * 0.05, h * 0.9, w * 0.08, h * 0.65)
      ..cubicTo(w * 0.1, h * 0.45, w * 0.3, h * 0.4, w * 0.35, h * 0.2)
      ..cubicTo(w * 0.4, h * 0.12, w * 0.45, h * 0.05, w * 0.5, 0)
      ..close();
    final inner = Path()
      ..moveTo(w * 0.5, h * 0.5)
      ..cubicTo(w * 0.62, h * 0.65, w * 0.78, h * 0.72, w * 0.7, h * 0.88)
      ..cubicTo(w * 0.64, h * 0.98, w * 0.38, h * 0.98, w * 0.32, h * 0.86)
      ..cubicTo(w * 0.26, h * 0.72, w * 0.46, h * 0.66, w * 0.5, h * 0.5)
      ..close();
    canvas
      ..drawPath(
        outer,
        Paint()
          ..color = lit ? const Color(0xFFF2762E) : const Color(0xFFB8BEC6),
      )
      ..drawPath(
        inner,
        Paint()
          ..color = lit ? const Color(0xFFFFC94D) : const Color(0xFFD9DDE2),
      );
  }

  @override
  bool shouldRepaint(_FlamePainter old) => old.lit != lit;
}

/// The emblem of a game, on the hub's cards.
class GameEmblem extends StatelessWidget {
  /// Creates one.
  const new({required this.game, this.size = 56, super.key});

  /// Which game.
  final ZadGame game;

  /// Box side.
  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _EmblemPainter(game));
}

class _EmblemPainter extends CustomPainter {
  const new(this.game);

  final ZadGame game;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final tile = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(s * 0.28),
    );
    final (Color a, Color b) = switch (game) {
      ZadGame.ball => (const Color(0xFFFFE0B2), const Color(0xFFFFB74D)),
      ZadGame.zadoRun => (const Color(0xFFCDEBFF), const Color(0xFF8FCBF0)),
      ZadGame.zadoSort => (const Color(0xFFD7F0E0), const Color(0xFF8FD0AD)),
      ZadGame.starCatch => (const Color(0xFF3B3F6B), const Color(0xFF1E2147)),
    };
    canvas.drawRRect(
      tile,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[a, b],
        ).createShader(Offset.zero & size),
    );
    switch (game) {
      case ZadGame.ball:
        canvas
          ..drawCircle(
            Offset(s * 0.5, s * 0.5),
            s * 0.24,
            Paint()..color = Colors.white,
          )
          ..drawCircle(
            Offset(s * 0.5, s * 0.5),
            s * 0.24,
            Paint()
              ..color = const Color(0xFFE65100)
              ..style = PaintingStyle.stroke
              ..strokeWidth = s * 0.05,
          )
          ..drawArc(
            Rect.fromCircle(center: Offset(s * 0.5, s * 0.5), radius: s * 0.24),
            0.6,
            1.9,
            false,
            Paint()
              ..color = const Color(0xFFE65100)
              ..style = PaintingStyle.stroke
              ..strokeWidth = s * 0.04,
          );
      case ZadGame.zadoRun:
        canvas
          ..drawRect(
            Rect.fromLTWH(0, s * 0.74, s, s * 0.26),
            Paint()..color = const Color(0xFF7A5A3A),
          )
          ..drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(s * 0.54, s * 0.5, s * 0.26, s * 0.24),
              Radius.circular(s * 0.04),
            ),
            Paint()..color = const Color(0xFFC98A4B),
          );
        paintSeed(canvas, Offset(s * 0.3, s * 0.36), s * 0.1);
        canvas.drawCircle(
          Offset(s * 0.3, s * 0.62),
          s * 0.1,
          Paint()..color = const Color(0xFF3F9E6B),
        );
      case ZadGame.zadoSort:
        for (var r = 0; r < 2; r++) {
          for (var c = 0; c < 2; c++) {
            final lvl = r == c ? 0.0 : 0.5;
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(
                  s * (0.2 + c * 0.32),
                  s * (0.2 + r * 0.32),
                  s * 0.28,
                  s * 0.28,
                ),
                Radius.circular(s * 0.06),
              ),
              Paint()
                ..color = Color.lerp(
                  const Color(0xFF3F9E6B),
                  const Color(0xFFF2B632),
                  lvl,
                )!,
            );
          }
        }
      case ZadGame.starCatch:
        paintStar(canvas, Offset(s * 0.5, s * 0.4), s * 0.24);
        paintStar(canvas, Offset(s * 0.22, s * 0.22), s * 0.09);
        paintStar(canvas, Offset(s * 0.8, s * 0.7), s * 0.09);
    }
  }

  @override
  bool shouldRepaint(_EmblemPainter old) => old.game != game;
}
