/// Paints a parsed drawing into a square, scaling its 64x64 design box.
library;

import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:zad/shared/worlds/art/art_ops.dart';
import 'package:zad/shared/worlds/art/art_svg.dart';

const double _box = 64;

final Map<String, List<ArtOp>> _cache = <String, List<ArtOp>>{};

/// The drawing [id] (kind plus name) from [svg], parsed once per tint.
List<ArtOp> opsFor(String id, String svg, Color? tint) => _cache.putIfAbsent(
  '$id/${tint?.toARGB32()}',
  () => parseArt(svg, tint: tint),
);

/// The painter behind `ZadArt`.
class ArtPainter extends CustomPainter {
  /// Creates one.
  new({required this.id, required this.svg, this.tint});

  /// Cache key: kind and name.
  final String id;

  /// The drawing body.
  final String svg;

  /// Value of the `{tint}` token.
  final Color? tint;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / _box;
    canvas
      ..save()
      ..scale(scale);
    for (final op in opsFor(id, svg, tint)) {
      _paintOp(canvas, op);
    }
    canvas.restore();
  }

  void _paintOp(Canvas canvas, ArtOp op) {
    canvas.save();
    for (final r in op.rotations) {
      canvas
        ..translate(r.cx, r.cy)
        ..rotate(r.deg * 3.141592653589793 / 180)
        ..translate(-r.cx, -r.cy);
    }
    final text = op.text;
    if (text != null) {
      _paintText(canvas, op, text);
    } else {
      final fill = op.fill;
      final gradient = op.gradient;
      if (fill != null || gradient != null) {
        final paint = Paint()..isAntiAlias = true;
        if (gradient != null) {
          paint.shader = _shader(gradient, op.path.getBounds(), op.opacity);
        } else {
          paint.color = fill!.withValues(alpha: fill.a * op.opacity);
        }
        canvas.drawPath(op.path, paint);
      }
      final stroke = op.stroke;
      if (stroke != null) {
        canvas.drawPath(
          op.path,
          Paint()
            ..isAntiAlias = true
            ..style = PaintingStyle.stroke
            ..color = stroke.withValues(alpha: stroke.a * op.opacity)
            ..strokeWidth = op.strokeWidth
            ..strokeCap = op.cap
            ..strokeJoin = op.join,
        );
      }
    }
    canvas.restore();
  }

  ui.Shader _shader(ArtGradient g, Rect b, double opacity) {
    final colors = <Color>[
      for (final c in g.colors) c.withValues(alpha: c.a * opacity),
    ];
    if (g.radial) {
      return ui.Gradient.radial(
        Offset(b.left + g.x1 * b.width, b.top + g.y1 * b.height),
        b.width / 2,
        colors,
        g.stops,
      );
    }
    return ui.Gradient.linear(
      Offset(b.left + g.x1 * b.width, b.top + g.y1 * b.height),
      Offset(b.left + g.x2 * b.width, b.top + g.y2 * b.height),
      colors,
      g.stops,
    );
  }

  void _paintText(Canvas canvas, ArtOp op, String text) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: op.textStyle),
      textDirection: ui.TextDirection.rtl,
    )..layout();
    final baseline = tp.computeDistanceToActualBaseline(
      TextBaseline.alphabetic,
    );
    final dx = op.textAnchorMiddle ? -tp.width / 2 : 0.0;
    tp
      ..paint(canvas, op.textOrigin + Offset(dx, -baseline))
      ..dispose();
  }

  @override
  bool shouldRepaint(ArtPainter old) =>
      old.id != id || old.svg != svg || old.tint != tint;
}
