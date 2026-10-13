/// رفيق زاد drawn as a painted plush toy rather than a glass orb (owner,
/// 2026-10-13: "2D, but clean — like a Procreate drawing"). Plain Canvas
/// work, no shader and no asset, so it runs wherever the orb ran.
///
/// A soft mochi silhouette (round top, wider settled base), lit like a
/// painting: a base wash from light to shade, a core shadow turning away
/// from the light, a warm bounce under the chin, a blurred highlight, a rim
/// of light on the lit edge, a fine grain, and a thin coloured line round it.
/// The face is a toy's: dark glossy eyes with two catch-lights, blush, and a
/// mouth that opens with the voice.
///
/// `CompanionOrb` calls these inside its own squash transform, at its own
/// centre and radius, so the crest, the outfit and the season's look still
/// sit where they always did.
library;

// One statement per painted layer reads closer to the order they stack in.
// ignore_for_file: cascade_invocations

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:zad/shared/orb/domain/companion_state.dart';

const Color _ink = Color(0xFF161A22);
const Color _inkLift = Color(0xFF39414F);
const Color _mouth = Color(0xFF5B1D2B);
const Color _tongue = Color(0xFFFF7C93);
const Color _blush = Color(0xFFFF8FA8);
const Color _warm = Color(0xFFFFE2C2);

/// The painted companion's layers.
abstract final class PlushPainting {
  /// The silhouette: a round crown, the widest point a little below the
  /// middle, and a flattened base — a body that sits, not a ball that rolls.
  static Path silhouette(Offset c, double r) {
    final top = c.dy - r;
    final base = c.dy + r * 0.95;
    final waist = c.dy + r * 0.2;
    final w = r * 1.04;
    return Path()
      ..moveTo(c.dx, top)
      ..cubicTo(c.dx + r * 0.56, top, c.dx + w, c.dy - r * 0.4, c.dx + w, waist)
      ..cubicTo(c.dx + w, c.dy + r * 0.74, c.dx + r * 0.7, base, c.dx, base)
      ..cubicTo(
        c.dx - r * 0.7,
        base,
        c.dx - w,
        c.dy + r * 0.74,
        c.dx - w,
        waist,
      )
      ..cubicTo(c.dx - w, c.dy - r * 0.4, c.dx - r * 0.56, top, c.dx, top)
      ..close();
  }

  /// The soft shadow the body sits on — narrower as it lifts.
  static void contactShadow(
    Canvas canvas,
    Offset ground,
    double r,
    double lift,
    Color deep,
  ) {
    final w = r * 1.5 * (1 + lift / (r * 2.4));
    canvas.drawOval(
      Rect.fromCenter(center: ground, width: w, height: r * 0.2),
      Paint()
        ..color = Color.lerp(deep, _ink, 0.5)!.withValues(alpha: 0.24)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.07),
    );
  }

  /// The body, painted. [seed] keeps each character's grain its own and
  /// still from frame to frame.
  static void paintBody(
    Canvas canvas,
    Offset c,
    double r, {
    required Color body,
    required Color deep,
    required double sheen,
    required int seed,
    bool glows = false,
  }) {
    final shape = silhouette(c, r);
    final bounds = Rect.fromCircle(center: c, radius: r * 1.06);

    // A base wash, light from above.
    canvas.drawPath(
      shape,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color.lerp(body, Colors.white, 0.22)!,
            body,
            Color.lerp(body, deep, 0.28)!,
          ],
          stops: const <double>[0, 0.5, 1],
        ).createShader(bounds),
    );

    canvas.save();
    canvas.clipPath(shape);

    // The core shadow: everything turning away from a light at the top-left.
    final light = c - Offset(r * 0.34, r * 0.46);
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            Colors.transparent,
            Colors.transparent,
            deep.withValues(alpha: 0.42),
            deep.withValues(alpha: 0.62),
          ],
          stops: const <double>[0, 0.48, 0.86, 1],
        ).createShader(Rect.fromCircle(center: light, radius: r * 1.75)),
    );

    // Warm light bounced up from the floor, under the chin.
    final bounce = c + Offset(r * 0.18, r * 1.02);
    canvas.drawOval(
      Rect.fromCenter(center: bounce, width: r * 1.5, height: r * 0.62),
      Paint()
        ..color = Color.lerp(body, _warm, 0.55)!.withValues(alpha: 0.42)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.14),
    );

    // فانوس glows from inside.
    if (glows) {
      canvas.drawCircle(
        c + Offset(0, r * 0.22),
        r * 0.62,
        Paint()
          ..color = const Color(0xFFFFD27A).withValues(alpha: 0.5)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.22),
      );
    }

    // Grain: a few hundred specks at a few percent, the felt of a toy.
    final rnd = math.Random(seed);
    final speck = Paint();
    for (var i = 0; i < 90; i++) {
      final a = rnd.nextDouble() * 2 * math.pi;
      final d = math.sqrt(rnd.nextDouble()) * r;
      final pale = rnd.nextBool();
      speck.color = (pale ? Colors.white : deep).withValues(
        alpha: pale ? 0.07 : 0.045,
      );
      canvas.drawCircle(
        c + Offset(math.cos(a) * d, math.sin(a) * d),
        r * (0.008 + rnd.nextDouble() * 0.01),
        speck,
      );
    }

    // The highlight: a broad soft one and a small bright core.
    final spot = c - Offset(r * 0.36, r * 0.5);
    canvas.drawOval(
      Rect.fromCenter(center: spot, width: r * 0.86, height: r * 0.56),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.30 + 0.16 * sheen)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.13),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: spot + Offset(-r * 0.04, -r * 0.04),
        width: r * 0.26,
        height: r * 0.16,
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.55 + 0.2 * sheen)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.035),
    );

    // Rim light along the lit edge only.
    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.09
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.03)
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Colors.white.withValues(alpha: 0.55),
            Colors.white.withValues(alpha: 0),
          ],
          stops: const <double>[0, 0.55],
        ).createShader(bounds),
    );
    canvas.restore();

    // The line: the body's own shade, thin — an illustration, not a sticker.
    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, r * 0.028)
        ..color = Color.lerp(deep, _ink, 0.25)!.withValues(alpha: 0.38),
    );
  }

  /// One soft limb — a hand or a foot — lit the same way as the body.
  static void limb(
    Canvas canvas,
    Rect oval, {
    required Color body,
    required Color deep,
  }) {
    final r = oval.shortestSide / 2;
    canvas.drawOval(
      oval,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.5),
          radius: 1.1,
          colors: <Color>[
            Color.lerp(body, Colors.white, 0.25)!,
            body,
            Color.lerp(body, deep, 0.45)!,
          ],
          stops: const <double>[0, 0.45, 1],
        ).createShader(oval),
    );
    canvas.drawOval(
      oval,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, r * 0.12)
        ..color = Color.lerp(deep, _ink, 0.25)!.withValues(alpha: 0.34),
    );
  }

  /// A fluffy coat (مشمش): a soft halo of the body's own light colour round
  /// the edge, and short tufts standing off it.
  static void fluff(Canvas canvas, Offset c, double r, Color body, int seed) {
    final shape = silhouette(c, r);
    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.1
        ..color = Color.lerp(body, Colors.white, 0.35)!.withValues(alpha: 0.5)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.04),
    );
    final rnd = math.Random(seed);
    final tuft = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(0.8, r * 0.04)
      ..color = Color.lerp(body, Colors.white, 0.28)!.withValues(alpha: 0.5)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.012);
    for (final m in shape.computeMetrics()) {
      const n = 46;
      for (var i = 0; i < n; i++) {
        final t = m.getTangentForOffset(m.length * (i + rnd.nextDouble()) / n);
        if (t == null) continue;
        // The outward normal of a clockwise path on screen.
        final out = Offset(t.vector.dy, -t.vector.dx);
        final len = r * (0.025 + rnd.nextDouble() * 0.025);
        final bend = (rnd.nextDouble() - 0.5) * 0.6;
        final tip = t.position + out * len + t.vector * (len * bend);
        canvas.drawLine(t.position - out * r * 0.02, tip, tuft);
      }
    }
  }

  /// Blush under the eyes.
  static void cheeks(Canvas canvas, Offset c, double r, {double warmth = 1}) {
    final paint = Paint()
      ..color = _blush.withValues(alpha: 0.5 * warmth)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.05);
    for (final side in <double>[-1, 1]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: c + Offset(side * r * 0.54, r * 0.26),
          width: r * 0.26,
          height: r * 0.15,
        ),
        paint,
      );
    }
  }

  /// The eyes for [state]. [open] is the blink (1 open, ~0 shut), [look]
  /// where they glance, [level] the voice.
  static void eyes(
    Canvas canvas,
    Offset c,
    double r, {
    required CompanionState state,
    required double open,
    required Offset look,
    required double level,
    bool asleep = false,
  }) {
    final spacing = r * 0.31;
    final y = c.dy + r * 0.02;
    for (final side in <double>[-1, 1]) {
      final at = Offset(c.dx + side * spacing, y) + look;
      if (asleep) {
        _arc(canvas, at, r * 0.2, r * 0.07, r * 0.055, down: true);
        continue;
      }
      switch (state) {
        case CompanionState.happy:
        case CompanionState.celebrating:
          _arc(canvas, at, r * 0.22, r * 0.11, r * 0.06, down: false);
        case CompanionState.alert:
        case CompanionState.idle:
        case CompanionState.listening:
        case CompanionState.focused:
        case CompanionState.speaking:
          final grow = switch (state) {
            CompanionState.listening => 1.08 + 0.08 * level,
            CompanionState.focused => 0.9,
            _ => 1.0,
          };
          _eye(canvas, at, r * 0.135 * grow, r * 0.175 * grow, open);
          if (state == CompanionState.alert) {
            // A raised, tilted brow — concern, not anger.
            final inner = Offset(at.dx - side * r * 0.1, at.dy - r * 0.27);
            final outer = Offset(at.dx + side * r * 0.12, at.dy - r * 0.21);
            canvas.drawLine(
              inner,
              outer,
              Paint()
                ..color = _ink
                ..strokeWidth = r * 0.05
                ..strokeCap = StrokeCap.round,
            );
          }
      }
    }
  }

  static void _eye(
    Canvas canvas,
    Offset at,
    double rx,
    double ry,
    double open,
  ) {
    final h = ry * open.clamp(0.0, 1.0);
    if (h < ry * 0.25) {
      // Shut: a soft line, curving down like a closed lid.
      _arc(canvas, at, rx * 2, ry * 0.25, rx * 0.4, down: true);
      return;
    }
    final rect = Rect.fromCenter(center: at, width: rx * 2, height: h * 2);
    canvas.drawOval(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[_ink, _ink, _inkLift],
          stops: <double>[0, 0.55, 1],
        ).createShader(rect),
    );
    final glint = Paint()..color = Colors.white;
    canvas.drawCircle(at + Offset(-rx * 0.3, -h * 0.42), rx * 0.42, glint);
    canvas.drawCircle(
      at + Offset(rx * 0.36, h * 0.38),
      rx * 0.18,
      glint..color = Colors.white.withValues(alpha: 0.8),
    );
  }

  static void _arc(
    Canvas canvas,
    Offset at,
    double w,
    double h,
    double stroke, {
    required bool down,
  }) {
    final dy = down ? h : -h;
    canvas.drawPath(
      Path()
        ..moveTo(at.dx - w / 2, at.dy)
        ..quadraticBezierTo(at.dx, at.dy + dy * 2, at.dx + w / 2, at.dy),
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  /// The mouth for [state]; while speaking it opens with [level].
  static void mouth(
    Canvas canvas,
    Offset c,
    double r, {
    required CompanionState state,
    required double level,
    bool asleep = false,
  }) {
    final at = c + Offset(0, r * 0.25);
    final line = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.045
      ..strokeCap = StrokeCap.round;
    if (asleep) {
      canvas.drawCircle(at, r * 0.035, Paint()..color = _mouth);
      return;
    }
    switch (state) {
      case CompanionState.happy:
      case CompanionState.celebrating:
        _openMouth(canvas, at, r * 0.24, r * 0.15, grin: true);
      case CompanionState.speaking:
        _openMouth(canvas, at, r * 0.16, r * (0.05 + 0.16 * level));
      case CompanionState.listening:
        _openMouth(canvas, at, r * 0.09, r * 0.08);
      case CompanionState.focused:
        canvas.drawPath(
          Path()
            ..moveTo(at.dx - r * 0.08, at.dy + r * 0.01)
            ..quadraticBezierTo(
              at.dx,
              at.dy - r * 0.03,
              at.dx + r * 0.08,
              at.dy,
            ),
          line,
        );
      case CompanionState.alert:
        canvas.drawLine(
          at + Offset(-r * 0.07, r * 0.01),
          at + Offset(r * 0.07, r * 0.01),
          line,
        );
      case CompanionState.idle:
        canvas.drawPath(
          Path()
            ..moveTo(at.dx - r * 0.09, at.dy - r * 0.02)
            ..quadraticBezierTo(
              at.dx,
              at.dy + r * 0.07,
              at.dx + r * 0.09,
              at.dy - r * 0.02,
            ),
          line,
        );
    }
  }

  static void _openMouth(
    Canvas canvas,
    Offset at,
    double w,
    double h, {
    bool grin = false,
  }) {
    final rect = grin
        ? Rect.fromLTWH(at.dx - w / 2, at.dy - h * 0.25, w, h)
        : Rect.fromCenter(center: at, width: w, height: h);
    final path = grin
        ? (Path()
            ..moveTo(rect.left, rect.top)
            ..lineTo(rect.right, rect.top)
            ..arcToPoint(
              Offset(rect.left, rect.top),
              radius: Radius.elliptical(w / 2, h),
            )
            ..close())
        : (Path()..addOval(rect));
    canvas.drawPath(path, Paint()..color = _mouth);
    canvas.save();
    canvas.clipPath(path);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(at.dx, rect.bottom),
        width: w * 0.7,
        height: rect.height * 0.8,
      ),
      Paint()..color = _tongue,
    );
    canvas.restore();
  }
}
