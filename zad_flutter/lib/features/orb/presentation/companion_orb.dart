/// Kotlin's `CompanionOrb`, still frame, happy face: the ground shadow, halo,
/// lit sphere, bounce light, glass sheen, rim, the ^ ^ eyes, and the
/// accessory — same layers, same proportions (radius = 0.62 of half the box,
/// so the halo and shadow fit inside it).
library;

// One statement per numbered layer reads closer to Kotlin's draw order than
// a single cascade spanning them.
// ignore_for_file: cascade_invocations

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:zad/features/orb/domain/orb_accessory.dart';

const Color _sky = Color(0xFF7CFFB2);
const Color _deep = Color(0xFF00B26A);
const Color _bowPink = Color(0xFFFF6FA5);
const Color _bowPinkDeep = Color(0xFFD9467E);
const Color _glassesFrame = Color(0xFF2B2B3A);
const Color _crownGold = Color(0xFFFFC53D);
const Color _crownGoldDeep = Color(0xFFE09A12);
const Color _crownGem = Color(0xFFE5484D);
const Color _flowerPetal = Color(0xFFFFFFFF);
const Color _flowerCenter = Color(0xFFFFC53D);

/// A still, happy orb wearing [accessory].
class CompanionOrb extends StatelessWidget {
  /// Creates the orb.
  const new({required this.accessory, this.size = 96, super.key});

  /// What it wears.
  final OrbAccessory accessory;

  /// The box it is drawn in.
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _OrbPainter(accessory)),
  );
}

class _OrbPainter extends CustomPainter {
  new(this.accessory);

  final OrbAccessory accessory;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 * 0.62;

    // 1. Ground shadow.
    final shadowW = r * 1.35;
    final shadowRect = Rect.fromLTWH(
      c.dx - shadowW / 2,
      c.dy + r * 1.02,
      shadowW,
      r * 0.22,
    );
    canvas.drawOval(
      shadowRect,
      Paint()
        ..shader =
            RadialGradient(
              colors: <Color>[
                _deep.withValues(alpha: 0.22),
                _deep.withValues(alpha: 0),
              ],
            ).createShader(
              Rect.fromCircle(
                center: Offset(c.dx, c.dy + r * 1.12),
                radius: shadowW / 2,
              ),
            ),
    );

    // 2. Halo.
    final halo = r * 1.42;
    canvas.drawCircle(
      c,
      halo,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            _sky.withValues(alpha: 0.30),
            _sky.withValues(alpha: 0.10),
            _sky.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: halo)),
    );

    // 3. Body, lit from the top-left.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader =
            RadialGradient(
              colors: <Color>[
                Color.lerp(_sky, Colors.white, 0.42)!,
                _sky,
                Color.lerp(_sky, _deep, 0.55)!,
                _deep,
              ],
            ).createShader(
              Rect.fromCircle(
                center: c - Offset(r * 0.32, r * 0.38),
                radius: r * 1.55,
              ),
            ),
    );

    // 4. Bounce light, bottom-right, clipped to the body.
    canvas
      ..save()
      ..clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));
    final bounce = c + Offset(r * 0.42, r * 0.62);
    canvas
      ..drawCircle(
        bounce,
        r * 0.62,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              Color.lerp(_sky, Colors.white, 0.25)!.withValues(alpha: 0.45),
              Colors.transparent,
            ],
          ).createShader(Rect.fromCircle(center: bounce, radius: r * 0.62)),
      )
      ..restore();

    // 6. Glass sheen, an oval tilted -32°.
    final spec = c - Offset(r * 0.40, r * 0.46);
    canvas
      ..save()
      ..translate(spec.dx, spec.dy)
      ..rotate(-32 * math.pi / 180)
      ..drawOval(
        Rect.fromCenter(center: Offset.zero, width: r * 0.68, height: r * 0.38),
        Paint()
          ..shader =
              RadialGradient(
                colors: <Color>[
                  Colors.white.withValues(alpha: 0.62 + 0.25 * 0.3),
                  Colors.white.withValues(alpha: 0),
                ],
              ).createShader(
                Rect.fromCircle(center: Offset.zero, radius: r * 0.34),
              ),
      )
      ..restore();

    // 7. Fresnel rim.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Colors.white.withValues(alpha: 0.55),
            Colors.white.withValues(alpha: 0.08),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    // 8. Happy eyes, ^ ^.
    final eyeY = c.dy - r * 0.06;
    final eyeW = r * 0.22 * 1.5;
    for (final dx in <double>[-r * 0.36, r * 0.36]) {
      _happyArc(canvas, Offset(c.dx + dx, eyeY), eyeW, r * 0.16, r * 0.085);
    }

    // 8b. The accessory.
    _accessory(canvas, c, r);
  }

  void _happyArc(Canvas canvas, Offset at, double w, double h, double stroke) {
    final path = Path()
      ..moveTo(at.dx - w / 2, at.dy + h / 2)
      ..quadraticBezierTo(at.dx, at.dy - h, at.dx + w / 2, at.dy + h / 2);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  void _accessory(Canvas canvas, Offset c, double r) {
    switch (accessory) {
      case OrbAccessory.none:
        return;
      case OrbAccessory.bow:
        final knot = c + Offset(r * 0.48, -r * 0.80);
        for (final dir in <double>[-1, 1]) {
          canvas
            ..save()
            ..translate(knot.dx, knot.dy)
            ..rotate(dir * 28 * math.pi / 180)
            ..drawOval(
              Rect.fromLTWH(
                dir < 0 ? -r * 0.56 : 0,
                -r * 0.19,
                r * 0.56,
                r * 0.38,
              ),
              Paint()..color = _bowPink,
            )
            ..restore();
        }
        canvas.drawCircle(knot, r * 0.12, Paint()..color = _bowPinkDeep);
      case OrbAccessory.glasses:
        final y = c.dy - r * 0.06;
        final lens = r * 0.2;
        final left = Offset(c.dx - r * 0.36, y);
        final right = Offset(c.dx + r * 0.36, y);
        final glass = Paint()..color = Colors.white.withValues(alpha: 0.18);
        final frame = Paint()
          ..color = _glassesFrame
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.055;
        canvas
          ..drawCircle(left, lens, glass)
          ..drawCircle(right, lens, glass)
          ..drawCircle(left, lens, frame)
          ..drawCircle(right, lens, frame)
          ..drawLine(
            left + Offset(lens, 0),
            right - Offset(lens, 0),
            Paint()
              ..color = _glassesFrame
              ..strokeWidth = r * 0.05,
          );
      case OrbAccessory.flower:
        final f = c + Offset(-r * 0.55, -r * 0.72);
        for (var i = 0; i < 5; i++) {
          final a = (i * 72 - 90) * math.pi / 180;
          canvas.drawCircle(
            f + Offset(math.cos(a) * r * 0.13, math.sin(a) * r * 0.13),
            r * 0.11,
            Paint()..color = _flowerPetal,
          );
        }
        canvas.drawCircle(f, r * 0.08, Paint()..color = _flowerCenter);
      case OrbAccessory.crown:
        final base = c.dy - r * 0.80;
        final w = r * 0.86;
        final h = r * 0.50;
        final left = c.dx - w / 2;
        final path = Path()
          ..moveTo(left, base)
          ..lineTo(left, base - h * 0.6)
          ..lineTo(left + w * 0.25, base - h * 0.25)
          ..lineTo(left + w * 0.5, base - h)
          ..lineTo(left + w * 0.75, base - h * 0.25)
          ..lineTo(left + w, base - h * 0.6)
          ..lineTo(left + w, base)
          ..close();
        canvas
          ..drawPath(
            path,
            Paint()
              ..shader = const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[_crownGold, _crownGoldDeep],
              ).createShader(Rect.fromLTRB(left, base - h, left + w, base)),
          )
          ..drawCircle(
            Offset(c.dx, base - h * 0.32),
            r * 0.08,
            Paint()..color = _crownGem,
          );
    }
  }

  @override
  bool shouldRepaint(_OrbPainter old) => old.accessory != accessory;
}
