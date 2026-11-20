/// The budget world's scene: one jar per category, filled to what was spent;
/// a coin drops into the first jar each time a new transaction lands.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:zad/core/design/tokens/zad_world_colors.dart';
import 'package:zad/shared/worlds/world_scene.dart';

// Illustrative one-off colours (a scene, not a shared component).
const Color _glass = Color(0xFFEADCC3);
const Color _lid = Color(0xFF1B4332);
const Color _coinGold = Color(0xFFF5B93A);

/// One jar: how full (0..1) and its colour.
typedef BudgetJar = ({double fill, Color color});

/// How many jars the scene has room for.
const int kBudgetJars = 4;

/// Paints the jars. [coin] runs 0..1 while a coin falls; 0 is at rest.
class BudgetWorldScene extends CustomPainter {
  /// Creates the painter. Fewer than [kBudgetJars] jars leave empty ones, so
  /// the scene is never bare.
  new(this.loop, this.coin, this.jars)
    : super(repaint: Listenable.merge(<Listenable>[loop, coin]));

  /// The scaffold's loop.
  final Animation<double> loop;

  /// A new transaction landed.
  final Animation<double> coin;

  /// What each jar holds.
  final List<BudgetJar> jars;

  @override
  void paint(Canvas canvas, Size size) {
    paintWorldGround(canvas, ZadWorldColors.budget);
    const w = 46.0;
    const gap = 16.0;
    const left0 = 180.0;
    for (var i = 0; i < kBudgetJars; i++) {
      final jar = i < jars.length ? jars[i] : null;
      final x = left0 + i * (w + gap);
      _jar(canvas, x, jar?.fill ?? 0, jar?.color ?? _glass, i);
    }
    _coin(canvas, left0 + w / 2);
  }

  void _jar(Canvas canvas, double x, double fill, Color color, int i) {
    const top = 60.0;
    const h = 130.0;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, top, 46, h),
      const Radius.circular(14),
    );
    canvas.drawRRect(body, Paint()..color = Colors.white);
    final f = fill.clamp(0.0, 1.0);
    if (f > 0) {
      // The surface sways a hair; the jar that just got a coin ripples.
      final ripple = i == 0 && coin.value > 0.55
          ? math.sin(coin.value * math.pi * 6) * 2.5 * (1 - coin.value)
          : 0.0;
      final sway = worldBob(loop.value, amplitude: 1.2, phase: i * 0.2);
      const inner = h - 8;
      final level = (inner * f + sway + ripple).clamp(6.0, inner);
      canvas
        ..save()
        ..clipRRect(body)
        ..drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(x + 4, top + 4 + inner - level, 38, level),
            bottomLeft: const Radius.circular(10),
            bottomRight: const Radius.circular(10),
            topLeft: const Radius.circular(4),
            topRight: const Radius.circular(4),
          ),
          Paint()..color = color,
        )
        ..restore();
    }
    canvas
      ..drawRRect(
        body,
        Paint()
          ..color = _glass
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x + 6, top - 10, 34, 12),
          const Radius.circular(4),
        ),
        Paint()..color = _lid,
      );
  }

  void _coin(Canvas canvas, double cx) {
    final t = coin.value;
    if (t <= 0 || t >= 0.62) return;
    final k = Curves.easeIn.transform(t / 0.62);
    final y = -6 + 76 * k;
    // Turns edge-on as it falls.
    final squash = math.cos(t * math.pi * 8).abs().clamp(0.25, 1.0);
    canvas
      ..drawOval(
        Rect.fromCenter(center: Offset(cx, y), width: 20 * squash, height: 20),
        Paint()..color = _coinGold,
      )
      ..drawOval(
        Rect.fromCenter(center: Offset(cx, y), width: 12 * squash, height: 12),
        Paint()
          ..color = const Color(0xFFC68216)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
  }

  @override
  bool shouldRepaint(BudgetWorldScene old) => old.jars != jars;
}
