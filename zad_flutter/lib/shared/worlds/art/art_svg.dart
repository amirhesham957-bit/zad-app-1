/// Reads the SVG subset the art kit is written in (path, rect, circle,
/// ellipse, line, text, g with rotate, linear and radial gradients) into a
/// list of paint-ready [ArtOp]s, once per drawing.
library;

import 'package:flutter/widgets.dart';
import 'package:zad/shared/worlds/art/art_ops.dart';
import 'package:zad/shared/worlds/art/art_path.dart';
import 'package:zad/shared/worlds/art/zad_art_colors.dart';

final RegExp _tag = RegExp('<(/?)([A-Za-z]+)([^>]*?)(/?)>');
final RegExp _attr = RegExp(r'([\w-]+)="([^"]*)"');

/// Parses [svg] (a drawing body); `{tint}` resolves to [tint].
List<ArtOp> parseArt(String svg, {Color? tint}) {
  Color? colour(String? v) {
    if (v == null || v == 'none') return null;
    if (v.startsWith('{')) {
      final n = v.substring(1, v.length - 1);
      return n == 'tint' ? (tint ?? ZadArtColors.leaf) : ZadArtColors.named[n];
    }
    if (v.startsWith('#')) {
      var h = v.substring(1);
      if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
      return Color(0xFF000000 | int.parse(h, radix: 16));
    }
    return null;
  }

  final gradients = <String, ArtGradient>{};
  final ops = <ArtOp>[];
  // Style stack for <g>.
  final styles = <Map<String, String>>[<String, String>{}];
  final rot = <List<ArtRotation>>[<ArtRotation>[]];
  String? openGrad;
  final gradMeta = <String, String>{};
  final gradColors = <Color>[];
  final gradStops = <double>[];
  var gradRadial = false;

  double f(Map<String, String> a, String k, [double d = 0]) =>
      double.tryParse(a[k] ?? '') ?? d;
  double frac(String? v, double d) {
    if (v == null) return d;
    return v.endsWith('%')
        ? double.parse(v.replaceAll('%', '')) / 100
        : double.parse(v);
  }

  ArtRotation? rotationOf(String? t) {
    if (t == null) return null;
    final m = RegExp(r'rotate\(([^)]*)\)').firstMatch(t);
    if (m == null) return null;
    final p = m.group(1)!.trim().split(RegExp('[ ,]+')).map(double.parse);
    final l = p.toList();
    return (
      deg: l[0],
      cx: l.length > 2 ? l[1] : 0,
      cy: l.length > 2 ? l[2] : 0,
    );
  }

  for (final m in _tag.allMatches(svg)) {
    final closing = m.group(1) == '/';
    final name = m.group(2)!;
    final selfClosed = m.group(4) == '/';
    final a = <String, String>{
      for (final x in _attr.allMatches(m.group(3)!)) x.group(1)!: x.group(2)!,
    };
    if (closing) {
      if (name == 'g') {
        styles.removeLast();
        rot.removeLast();
      } else if (name == 'linearGradient' || name == 'radialGradient') {
        gradients[openGrad!] = ArtGradient(
          radial: gradRadial,
          x1: frac(gradMeta['x1'], gradRadial ? 0.5 : 0),
          y1: frac(gradMeta['y1'], gradRadial ? 0.5 : 0),
          x2: frac(gradMeta['x2'], 1),
          y2: frac(gradMeta['y2'], 1),
          colors: List<Color>.of(gradColors),
          stops: List<double>.of(gradStops),
        );
        openGrad = null;
      }
      continue;
    }
    if (name == 'defs') continue;
    if (name == 'linearGradient' || name == 'radialGradient') {
      openGrad = a['id'];
      gradRadial = name == 'radialGradient';
      gradMeta
        ..clear()
        ..addAll(
          gradRadial
              ? <String, String>{'x1': a['cx'] ?? '50%', 'y1': a['cy'] ?? '50%'}
              : a,
        );
      gradColors.clear();
      gradStops.clear();
      continue;
    }
    if (name == 'stop') {
      gradColors.add(colour(a['stop-color']) ?? const Color(0xFF000000));
      gradStops.add(frac(a['offset'], 0));
      continue;
    }
    // Inherited style.
    final style = <String, String>{...styles.last};
    for (final k in const <String>[
      'fill',
      'stroke',
      'stroke-width',
      'stroke-linecap',
      'stroke-linejoin',
    ]) {
      if (a.containsKey(k)) style[k] = a[k]!;
    }
    final r = rotationOf(a['transform']);
    final rotations = <ArtRotation>[...rot.last, ?r];
    if (name == 'g') {
      if (!selfClosed) {
        styles.add(style);
        rot.add(rotations);
      }
      continue;
    }
    final op = _shape(
      name,
      a,
      style,
      rotations,
      colour,
      gradients,
      f,
      svg,
      m.end,
    );
    if (op != null) ops.add(op);
  }
  return ops;
}

ArtOp? _shape(
  String name,
  Map<String, String> a,
  Map<String, String> style,
  List<ArtRotation> rotations,
  Color? Function(String?) colour,
  Map<String, ArtGradient> gradients,
  double Function(Map<String, String>, String, [double]) f,
  String svg,
  int after,
) {
  final path = Path();
  String? text;
  switch (name) {
    case 'path':
      path.addPath(parseSvgPath(a['d']!), Offset.zero);
    case 'rect':
      final rx = f(a, 'rx');
      final rect = Rect.fromLTWH(
        f(a, 'x'),
        f(a, 'y'),
        f(a, 'width'),
        f(a, 'height'),
      );
      path.addRRect(RRect.fromRectAndRadius(rect, Radius.circular(rx)));
    case 'circle':
      path.addOval(
        Rect.fromCircle(
          center: Offset(f(a, 'cx'), f(a, 'cy')),
          radius: f(a, 'r'),
        ),
      );
    case 'ellipse':
      path.addOval(
        Rect.fromCenter(
          center: Offset(f(a, 'cx'), f(a, 'cy')),
          width: f(a, 'rx') * 2,
          height: f(a, 'ry') * 2,
        ),
      );
    case 'line':
      path
        ..moveTo(f(a, 'x1'), f(a, 'y1'))
        ..lineTo(f(a, 'x2'), f(a, 'y2'));
    case 'text':
      final end = svg.indexOf('</text>', after);
      text = svg.substring(after, end);
    default:
      return null;
  }
  final fillRaw = style['fill'] ?? (name == 'line' ? 'none' : '#000000');
  final gradient = fillRaw.startsWith('url(#')
      ? gradients[fillRaw.substring(5, fillRaw.length - 1)]
      : null;
  final isText = text != null;
  return ArtOp(
    path: path,
    rotations: rotations,
    fill: gradient == null ? colour(fillRaw) : null,
    gradient: gradient,
    stroke: colour(style['stroke']),
    strokeWidth: double.tryParse(style['stroke-width'] ?? '') ?? 1,
    cap: style['stroke-linecap'] == 'round' ? StrokeCap.round : StrokeCap.butt,
    join: style['stroke-linejoin'] == 'round'
        ? StrokeJoin.round
        : StrokeJoin.miter,
    opacity: f(a, 'opacity', 1),
    text: text,
    textStyle: isText
        ? TextStyle(
            fontFamily: 'Cairo',
            fontSize: f(a, 'font-size', 16),
            fontWeight: a['font-weight'] == '900'
                ? FontWeight.w900
                : FontWeight.w400,
            color: colour(fillRaw) ?? const Color(0xFF000000),
          )
        : null,
    textAnchorMiddle: a['text-anchor'] == 'middle',
    textOrigin: Offset(f(a, 'x'), f(a, 'y')),
  );
}
