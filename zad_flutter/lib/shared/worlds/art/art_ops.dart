/// The parsed form of a drawing: gradients, and one [ArtOp] per element.
library;

import 'package:flutter/widgets.dart';

/// One rotate(angle cx cy) of the SVG transform chain.
typedef ArtRotation = ({double deg, double cx, double cy});

/// A gradient definition from `<defs>`.
class ArtGradient {
  /// Creates one.
  new({
    required this.radial,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.colors,
    required this.stops,
  });

  /// Radial (centre x1,y1) rather than linear.
  final bool radial;

  /// Bounding-box fractions.
  final double x1;

  /// See [x1].
  final double y1;

  /// See [x1].
  final double x2;

  /// See [x1].
  final double y2;

  /// Stop colours.
  final List<Color> colors;

  /// Stop offsets, 0..1.
  final List<double> stops;
}

/// One drawn element, with inherited style resolved.
class ArtOp {
  /// Creates one.
  new({
    required this.path,
    required this.rotations,
    this.fill,
    this.gradient,
    this.stroke,
    this.strokeWidth = 1,
    this.cap = StrokeCap.butt,
    this.join = StrokeJoin.miter,
    this.opacity = 1,
    this.text,
    this.textStyle,
    this.textAnchorMiddle = false,
    this.textOrigin = Offset.zero,
  });

  /// The outline (empty for text).
  final Path path;

  /// Outermost first.
  final List<ArtRotation> rotations;

  /// Flat fill, if any.
  final Color? fill;

  /// Gradient fill, if any.
  final ArtGradient? gradient;

  /// Stroke colour, if any.
  final Color? stroke;

  /// Stroke width.
  final double strokeWidth;

  /// Stroke cap.
  final StrokeCap cap;

  /// Stroke join.
  final StrokeJoin join;

  /// Element opacity.
  final double opacity;

  /// For `<text>`: what it says.
  final String? text;

  /// For `<text>`: how.
  final TextStyle? textStyle;

  /// For `<text>`: `text-anchor="middle"`.
  final bool textAnchorMiddle;

  /// For `<text>`: x and the baseline y.
  final Offset textOrigin;
}
