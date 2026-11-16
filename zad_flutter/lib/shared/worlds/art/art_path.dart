/// A small SVG path-data reader: the commands the art kit uses (M L H V C S
/// Q A Z, absolute and relative) become a Flutter [Path].
library;

import 'dart:ui';

final RegExp _token = RegExp(
  r'[MmLlHhVvCcSsQqAaZz]|-?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?',
);

/// Reads the `d` attribute [d] into a [Path].
Path parseSvgPath(String d) {
  final path = Path();
  final t = _token.allMatches(d).map((m) => m.group(0)!).toList();
  var i = 0;
  var cmd = '';
  var x = 0.0;
  var y = 0.0;
  var sx = 0.0;
  var sy = 0.0;
  // The last control point, for S.
  var cx = 0.0;
  var cy = 0.0;
  var lastWasCurve = false;

  bool isCmd(String s) => RegExp('[A-Za-z]').hasMatch(s);
  double n() => double.parse(t[i++]);

  while (i < t.length) {
    if (isCmd(t[i])) cmd = t[i++];
    final rel = cmd == cmd.toLowerCase();
    final ox = rel ? x : 0.0;
    final oy = rel ? y : 0.0;
    var curve = false;
    switch (cmd.toUpperCase()) {
      case 'M':
        x = n() + ox;
        y = n() + oy;
        sx = x;
        sy = y;
        path.moveTo(x, y);
        // Further pairs after a move are line-tos.
        cmd = rel ? 'l' : 'L';
      case 'L':
        x = n() + ox;
        y = n() + oy;
        path.lineTo(x, y);
      case 'H':
        x = n() + ox;
        path.lineTo(x, y);
      case 'V':
        y = n() + oy;
        path.lineTo(x, y);
      case 'C':
        final x1 = n() + ox;
        final y1 = n() + oy;
        final x2 = n() + ox;
        final y2 = n() + oy;
        x = n() + ox;
        y = n() + oy;
        path.cubicTo(x1, y1, x2, y2, x, y);
        cx = x2;
        cy = y2;
        curve = true;
      case 'S':
        final x1 = lastWasCurve ? 2 * x - cx : x;
        final y1 = lastWasCurve ? 2 * y - cy : y;
        final x2 = n() + ox;
        final y2 = n() + oy;
        x = n() + ox;
        y = n() + oy;
        path.cubicTo(x1, y1, x2, y2, x, y);
        cx = x2;
        cy = y2;
        curve = true;
      case 'Q':
        final x1 = n() + ox;
        final y1 = n() + oy;
        x = n() + ox;
        y = n() + oy;
        path.quadraticBezierTo(x1, y1, x, y);
      case 'A':
        final rx = n();
        final ry = n();
        final rot = n();
        final large = n() != 0;
        final sweep = n() != 0;
        x = n() + ox;
        y = n() + oy;
        if (rx == 0 || ry == 0) {
          path.lineTo(x, y);
        } else {
          path.arcToPoint(
            Offset(x, y),
            radius: Radius.elliptical(rx, ry),
            rotation: rot,
            largeArc: large,
            clockwise: sweep,
          );
        }
      case 'Z':
        path.close();
        x = sx;
        y = sy;
      default:
        throw FormatException('Unsupported path command $cmd in "$d"');
    }
    lastWasCurve = curve;
  }
  return path;
}
