/// The art kit as widgets: `ZadArt.product(ZadProductArt.milk, size: 40)`,
/// `ZadArt.icon(ZadIconArt.pantry, size: 24)`. Every picture the app shows
/// of a thing is drawn here, in one light (top-left), never an emoji.
library;

import 'package:flutter/widgets.dart';
import 'package:zad/shared/worlds/art/art_data_icons_1.dart';
import 'package:zad/shared/worlds/art/art_data_icons_2.dart';
import 'package:zad/shared/worlds/art/art_data_icons_3.dart';
import 'package:zad/shared/worlds/art/art_data_products.dart';
import 'package:zad/shared/worlds/art/art_painter.dart';
import 'package:zad/shared/worlds/art/zad_art_kinds.dart';

/// The SVG body of an icon.
String zadIconSvg(ZadIconArt art) =>
    zadIconSvg1[art] ?? zadIconSvg2[art] ?? zadIconSvg3[art]!;

/// A drawing, [size] square. Silent for screen readers unless the caller
/// passes a [semanticLabel].
class ZadArt extends StatelessWidget {
  /// A product drawing.
  new product(
    ZadProductArt art, {
    required this.size,
    this.semanticLabel,
    this.tint,
    super.key,
  }) : _svg = zadProductSvg[art]!,
       _id = 'p:${art.name}';

  /// An icon drawing.
  new icon(ZadIconArt art, {required this.size, this.semanticLabel, super.key})
    : _svg = zadIconSvg(art),
      tint = null,
      _id = 'i:${art.name}';

  /// The generic carton, tinted (the fallback for a product with no drawing).
  new box({
    required Color this.tint,
    required this.size,
    this.semanticLabel,
    super.key,
  }) : _svg = zadProductSvg[ZadProductArt.box]!,
       _id = 'p:box';

  /// The side of the square it is drawn in.
  final double size;

  /// What a screen reader says; null keeps the picture out of semantics.
  final String? semanticLabel;

  /// Colour for the `{tint}` token of drawings that have one.
  final Color? tint;

  final String _svg;
  final String _id;

  @override
  Widget build(BuildContext context) {
    final paint = CustomPaint(
      size: Size.square(size),
      painter: ArtPainter(id: _id, svg: _svg, tint: tint),
    );
    final label = semanticLabel;
    return SizedBox.square(
      dimension: size,
      child: label == null
          ? ExcludeSemantics(child: paint)
          : Semantics(label: label, image: true, child: paint),
    );
  }
}
