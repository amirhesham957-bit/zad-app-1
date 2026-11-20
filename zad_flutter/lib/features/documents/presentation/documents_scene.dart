/// The documents world's scene: a drawer of folders that breathe. The front
/// folder turns red when something is expired or about to be.
library;

import 'package:flutter/material.dart';
import 'package:zad/core/design/tokens/zad_world_colors.dart';
import 'package:zad/shared/worlds/world_scene.dart';

// Illustrative one-off colours (a scene, not a shared component).
const Color _mustard = Color(0xFFC68216);
const Color _green = Color(0xFF0F9B76);
const Color _red = Color(0xFFE5473C);

/// Paints the folders. [urgent] turns the front one red.
class DocumentsWorldScene extends CustomPainter {
  /// Creates the painter.
  new(this.loop, {required this.urgent}) : super(repaint: loop);

  /// The scaffold's loop.
  final Animation<double> loop;

  /// Whether a document is expired or about to be.
  final bool urgent;

  @override
  void paint(Canvas canvas, Size size) {
    paintWorldGround(canvas, ZadWorldColors.documents);
    final front = urgent ? _red : _green;
    final colors = <Color>[ZadWorldColors.documents, _mustard, front];
    const tilt = <double>[-0.21, -0.07, 0.1];
    for (var i = 0; i < 3; i++) {
      final bob = worldBob(loop.value, amplitude: 3, phase: i * 0.3);
      final left = 230.0 + i * 8;
      final top = 50.0 + i * 12 + bob;
      final c = colors[i];
      canvas
        ..save()
        ..translate(300, 120)
        ..rotate(tilt[i])
        ..translate(-300, -120)
        ..drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(left, top - 10, 56, 24),
            const Radius.circular(6),
          ),
          Paint()..color = c,
        )
        ..drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(left, top, 140, 110),
            const Radius.circular(12),
          ),
          Paint()..color = c,
        )
        ..drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(left + 16, top + 26, 90, 8),
            const Radius.circular(4),
          ),
          Paint()..color = Colors.white.withValues(alpha: 0.6),
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(DocumentsWorldScene old) => old.urgent != urgent;
}
