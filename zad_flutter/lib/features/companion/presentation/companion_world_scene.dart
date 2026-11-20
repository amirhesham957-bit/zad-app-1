/// The companion world's scene: a garden window painted in the colours of the
/// background the customer wears (morning, night, stars...), two flowers
/// growing out of a mound of soil and a few drops of rain. The drops fall
/// while the companion is awake and rest when it sleeps.
library;

import 'package:flutter/material.dart';
import 'package:zad/core/design/tokens/zad_world_colors.dart';
import 'package:zad/shared/companion/domain/companion_catalog.dart';
import 'package:zad/shared/worlds/world_scene.dart';

// Illustrative one-off colours (a scene, not a shared component).
const Color _soil = Color(0xFF8A5A2B);
const Color _stem = Color(0xFF2E8B4A);
const Color _drop = Color(0xFF7CB7FF);
const List<Color> _petals = <Color>[Color(0xFFF28AAE), Color(0xFFF5B93A)];

/// Paints the garden.
class CompanionWorldScene extends CustomPainter {
  /// Creates the painter.
  new(this.loop, {required this.background, required this.awake})
    : super(repaint: loop);

  /// The scaffold's loop.
  final Animation<double> loop;

  /// The background being worn.
  final CompanionBackground background;

  /// Asleep: no rain, the flowers still.
  final bool awake;

  @override
  void paint(Canvas canvas, Size size) {
    final t = loop.value;
    final window = RRect.fromRectAndRadius(
      const Rect.fromLTWH(16, 4, 398, 218),
      const Radius.circular(28),
    );
    canvas
      ..save()
      ..clipRRect(window)
      ..drawRRect(
        window,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: background.colors,
          ).createShader(window.outerRect),
      );
    if (background.dark) {
      final star = Paint()..color = const Color(0xFFFFFFFF);
      for (var i = 0; i < 9; i++) {
        final tw = 0.35 + 0.65 * worldTwinkle(t, phase: i * 0.13);
        star.color = Color.fromRGBO(255, 255, 255, tw);
        canvas.drawCircle(
          Offset(40 + (i * 47) % 360, 20 + (i * 29) % 90),
          i.isEven ? 2.2 : 1.6,
          star,
        );
      }
    }
    // The grass hill and the soil.
    canvas
      ..drawOval(
        const Rect.fromLTWH(-40, 176, 510, 120),
        Paint()..color = ZadWorldColors.companion.withValues(alpha: 0.55),
      )
      ..drawOval(
        Rect.fromCenter(center: const Offset(215, 200), width: 190, height: 30),
        Paint()..color = _soil,
      );
    // Two flowers sway on either side of the companion.
    for (final (i, x) in <double>[118, 312].indexed) {
      final sway = awake ? worldBob(t, amplitude: 3, phase: i * 0.3) : 0.0;
      final top = Offset(x + sway, 128);
      canvas
        ..drawLine(
          Offset(x, 200),
          top,
          Paint()
            ..color = _stem
            ..strokeWidth = 6
            ..strokeCap = StrokeCap.round,
        )
        ..drawCircle(top, 15, Paint()..color = _petals[i])
        ..drawCircle(top, 5, Paint()..color = const Color(0xFFFFF3D6));
    }
    if (awake) {
      for (var i = 0; i < 3; i++) {
        final f = worldFall(t, phase: i * 0.33);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(190 + i * 24, 18 + f * 170),
            width: 7,
            height: 11,
          ),
          Paint()..color = _drop.withValues(alpha: 1 - f * 0.6),
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(CompanionWorldScene old) =>
      old.background != background || old.awake != awake;
}
