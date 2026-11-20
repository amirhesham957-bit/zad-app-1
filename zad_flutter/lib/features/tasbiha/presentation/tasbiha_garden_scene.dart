/// The tasbih world's scene: a garden under a day or night sky. The tree on
/// the right grows a stage every 99 counts, and a flower blooms along the
/// ground for every 33.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:zad/core/design/tokens/zad_world_colors.dart';
import 'package:zad/shared/worlds/world_scene.dart';

// Illustrative one-off colours (a scene, not a shared component).
const Color _dayTop = Color(0xFF9ED9F5);
const Color _dayBottom = Color(0xFFE9F7EC);
const Color _nightTop = Color(0xFF14213D);
const Color _nightBottom = Color(0xFF3E5C76);
const Color _hillBack = Color(0xFF8FD18F);
const Color _hillFront = Color(0xFF5FB86F);
const Color _hillBackNight = Color(0xFF2F6B52);
const Color _hillFrontNight = Color(0xFF245A44);
const Color _trunk = Color(0xFF8B5E3C);
const Color _leaf = Color(0xFF2E8B4A);
const Color _leafLight = Color(0xFF4CAF50);
const List<Color> _petals = <Color>[
  Color(0xFFF28AAE),
  Color(0xFFF5B93A),
  Color(0xFFC9B8FF),
];

/// How many flowers the ground has room for.
const int kTasbihaMaxFlowers = 10;

/// Paints the garden.
class TasbihaGardenScene extends CustomPainter {
  /// Creates the painter. [bloom] is 0..1 while the newest flower opens (1
  /// at rest); [pulse] is 0..1 right after a tap (1 at rest).
  new(
    this.loop, {
    required this.level,
    required this.flowers,
    required this.night,
    required this.bloom,
    required this.pulse,
    this.accent = const Color(0xFFE53935),
  }) : super(repaint: Listenable.merge(<Listenable>[loop, bloom, pulse]));

  /// The scaffold's loop.
  final Animation<double> loop;

  /// The tree's stage, 1..5.
  final int level;

  /// Flowers earned (every 33 counts); the ground draws the latest ones.
  final int flowers;

  /// Night sky.
  final bool night;

  /// The newest flower opening.
  final Animation<double> bloom;

  /// The tap's little hop.
  final Animation<double> pulse;

  /// Fruit colour (a golden or special tree tints it).
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final t = loop.value;
    const sky = Rect.fromLTWH(0, 0, 430, 230);
    canvas.drawRect(
      sky,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: night
              ? const <Color>[_nightTop, _nightBottom]
              : const <Color>[_dayTop, _dayBottom],
        ).createShader(sky),
    );
    night ? _stars(canvas, t) : _sun(canvas, t);
    _hills(canvas);
    paintWorldGround(canvas, ZadWorldColors.tasbih);
    _flowers(canvas, t);
    _tree(canvas, t);
  }

  void _sun(Canvas canvas, double t) {
    canvas.drawCircle(
      const Offset(380, 46),
      26,
      Paint()..color = const Color(0xFFFFE08A),
    );
    final drift = math.sin(t * 2 * math.pi) * 6;
    final cloud = Paint()..color = Colors.white.withValues(alpha: 0.9);
    canvas
      ..drawOval(
        Rect.fromCenter(center: Offset(250 + drift, 44), width: 70, height: 22),
        cloud,
      )
      ..drawOval(
        Rect.fromCenter(center: Offset(270 + drift, 34), width: 44, height: 22),
        cloud,
      );
  }

  void _stars(Canvas canvas, double t) {
    canvas
      ..drawCircle(
        const Offset(380, 46),
        22,
        Paint()..color = const Color(0xFFF1EEDC),
      )
      ..drawCircle(
        const Offset(388, 40),
        20,
        Paint()..color = _nightTop.withValues(alpha: 0.55),
      );
    const spots = <Offset>[
      Offset(40, 30),
      Offset(120, 60),
      Offset(210, 24),
      Offset(300, 70),
      Offset(340, 20),
      Offset(70, 96),
    ];
    for (final (i, p) in spots.indexed) {
      canvas.drawCircle(
        p,
        2,
        Paint()
          ..color = Colors.white.withValues(
            alpha: 0.35 + 0.65 * worldTwinkle(t, phase: i * 0.17),
          ),
      );
    }
  }

  void _hills(Canvas canvas) {
    final back = Path()
      ..moveTo(0, 168)
      ..quadraticBezierTo(110, 138, 215, 160)
      ..quadraticBezierTo(330, 182, 430, 152)
      ..lineTo(430, 230)
      ..lineTo(0, 230)
      ..close();
    final front = Path()
      ..moveTo(0, 190)
      ..quadraticBezierTo(140, 166, 260, 188)
      ..quadraticBezierTo(350, 202, 430, 184)
      ..lineTo(430, 230)
      ..lineTo(0, 230)
      ..close();
    canvas
      ..drawPath(back, Paint()..color = night ? _hillBackNight : _hillBack)
      ..drawPath(front, Paint()..color = night ? _hillFrontNight : _hillFront);
  }

  void _flowers(Canvas canvas, double t) {
    final shown = math.min(flowers, kTasbihaMaxFlowers);
    for (var i = 0; i < shown; i++) {
      final x = 24 + i * 40.0 + (i.isOdd ? 6 : 0);
      final y = 214.0 + (i.isOdd ? -4 : 2);
      // The newest one opens; the rest sway a little.
      final grow = i == shown - 1
          ? Curves.elasticOut.transform(bloom.value)
          : 1.0;
      final sway = math.sin((t + i * 0.13) * 2 * math.pi) * 1.5;
      final h = 18 * grow;
      canvas.drawLine(
        Offset(x, y),
        Offset(x + sway, y - h),
        Paint()
          ..color = _leaf
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
      final head = Offset(x + sway, y - h);
      final petal = Paint()..color = _petals[i % _petals.length];
      for (var k = 0; k < 5; k++) {
        final a = k * 2 * math.pi / 5;
        canvas.drawCircle(
          head + Offset(math.cos(a), math.sin(a)) * 6 * grow,
          4.5 * grow,
          petal,
        );
      }
      canvas.drawCircle(
        head,
        3.5 * grow,
        Paint()..color = const Color(0xFFFFF3B0),
      );
    }
  }

  void _tree(Canvas canvas, double t) {
    const base = Offset(318, 204);
    final hop =
        -6 *
        (1 - Curves.easeOut.transform(pulse.value)) *
        (pulse.value < 1 ? 1 : 0);
    final sway = math.sin(t * 2 * math.pi) * 2.5;
    canvas
      ..save()
      ..translate(base.dx, base.dy + hop);
    final trunk = Paint()
      ..color = _trunk
      ..strokeCap = StrokeCap.round;
    final lv = level.clamp(1, 5);
    if (lv == 1) {
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, -2), width: 34, height: 12),
        Paint()..color = _trunk.withValues(alpha: 0.7),
      );
      _leafPair(canvas, const Offset(0, -6), 9, sway);
    } else if (lv == 2) {
      canvas.drawLine(
        Offset.zero,
        Offset(sway * 0.4, -34),
        trunk..strokeWidth = 4.0,
      );
      _leafPair(canvas, Offset(sway * 0.4, -34), 15, sway);
    } else {
      final h = 40.0 + lv * 14;
      canvas.drawLine(
        Offset.zero,
        Offset(sway * 0.3, -h),
        trunk..strokeWidth = 6.0 + lv * 2,
      );
      final r = 18.0 + lv * 9;
      final top = Offset(sway, -h - r * 0.55);
      final canopy = Paint()..color = _leaf;
      final light = Paint()..color = _leafLight;
      canvas
        ..drawCircle(top + Offset(-r * 0.7, r * 0.35), r * 0.7, canopy)
        ..drawCircle(top + Offset(r * 0.7, r * 0.35), r * 0.7, canopy)
        ..drawCircle(top, r, canopy)
        ..drawCircle(top + Offset(-r * 0.25, -r * 0.3), r * 0.5, light);
      if (lv >= 5) {
        final fruit = Paint()..color = accent;
        const spots = <Offset>[
          Offset(-0.6, 0.2),
          Offset(0.4, -0.3),
          Offset(0.7, 0.5),
          Offset(-0.1, 0.6),
          Offset(-0.2, -0.5),
        ];
        for (final s in spots) {
          canvas.drawCircle(top + s * r, 5, fruit);
        }
      }
    }
    canvas.restore();
  }

  void _leafPair(Canvas canvas, Offset at, double len, double sway) {
    final p = Paint()..color = _leafLight;
    for (final dir in <double>[-1, 1]) {
      final tip = at + Offset(dir * len, -len * 0.6 + sway * 0.3);
      canvas.drawPath(
        Path()
          ..moveTo(at.dx, at.dy)
          ..quadraticBezierTo(
            at.dx + dir * len * 0.4,
            at.dy - len * 0.9,
            tip.dx,
            tip.dy,
          )
          ..quadraticBezierTo(
            at.dx + dir * len * 0.7,
            at.dy + len * 0.1,
            at.dx,
            at.dy,
          ),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(TasbihaGardenScene old) =>
      old.level != level ||
      old.flowers != flowers ||
      old.night != night ||
      old.accent != accent;
}
