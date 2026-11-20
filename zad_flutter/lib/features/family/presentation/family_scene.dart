/// The family world's scene: a house with a heart over its roof, one window
/// lit for every member (up to three) and the members standing in front of
/// it. With no family the house is dark and nobody is home yet.
library;

import 'package:flutter/material.dart';
import 'package:zad/core/design/tokens/zad_world_colors.dart';
import 'package:zad/shared/worlds/world_scene.dart';

// Illustrative one-off colours (a scene, not a shared component).
const Color _wall = Color(0xFFFCE7F3);
const Color _wallShade = Color(0xFFF3C6E0);
const Color _roofDark = Color(0xFF8A2670);
const Color _lit = Color(0xFFFFE08A);
const Color _dark = Color(0xFFD9B9CE);
const List<Color> _people = <Color>[
  Color(0xFF2F7BD8),
  Color(0xFFE08A1E),
  Color(0xFF37C98E),
  Color(0xFF8B5CF6),
  Color(0xFFD95726),
];

/// The most members the scene stands in front of the house.
const int kFamilySceneMaxPeople = 5;

/// Paints the house. [members] is how many people are in the family.
class FamilyWorldScene extends CustomPainter {
  /// Creates the painter.
  new(this.loop, {required this.members}) : super(repaint: loop);

  /// The scaffold's loop.
  final Animation<double> loop;

  /// How many people are in the family (0 when there is none yet).
  final int members;

  @override
  void paint(Canvas canvas, Size size) {
    const world = ZadWorldColors.family;
    paintWorldGround(canvas, world);
    final t = loop.value;
    final home = members > 0;

    // The walls.
    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(246, 104, 140, 100),
      const Radius.circular(10),
    );
    canvas
      ..drawRRect(body, Paint()..color = _wall)
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(246, 184, 140, 20),
          const Radius.circular(10),
        ),
        Paint()..color = _wallShade,
      );
    // The roof.
    final roof = Path()
      ..moveTo(232, 110)
      ..lineTo(316, 48)
      ..lineTo(400, 110)
      ..close();
    canvas
      ..drawPath(roof, Paint()..color = world)
      ..drawPath(
        roof,
        Paint()
          ..color = _roofDark
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeJoin = StrokeJoin.round,
      )
      // The door.
      ..drawRRect(
        RRect.fromRectAndCorners(
          const Rect.fromLTWH(300, 150, 32, 54),
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
        ),
        Paint()..color = world.withValues(alpha: 0.85),
      );
    // A window lit for each member, up to three.
    const windows = <Rect>[
      Rect.fromLTWH(258, 122, 30, 30),
      Rect.fromLTWH(344, 122, 30, 30),
      Rect.fromLTWH(300, 84, 32, 26),
    ];
    for (var i = 0; i < windows.length; i++) {
      final on = i < members;
      final glow = on ? 0.85 + 0.15 * worldTwinkle(t, phase: i * 0.21) : 1.0;
      canvas
        ..drawRRect(
          RRect.fromRectAndRadius(windows[i], const Radius.circular(6)),
          Paint()..color = (on ? _lit : _dark).withValues(alpha: glow),
        )
        ..drawLine(
          windows[i].topCenter,
          windows[i].bottomCenter,
          Paint()
            ..color = _wall
            ..strokeWidth = 2,
        );
    }
    // The heart over the roof, beating a little when someone is home.
    final bob = home ? worldBob(t) : 0.0;
    _heart(
      canvas,
      Offset(316, 30 + bob),
      11,
      world.withValues(alpha: home ? 1 : 0.35),
    );
    // The members in front, shortest to tallest, a small bounce each.
    final shown = members.clamp(0, kFamilySceneMaxPeople);
    for (var i = 0; i < shown; i++) {
      final x = 222 + i * 40.0;
      final h = i.isEven ? 44.0 : 34.0;
      final hop = worldBob(t, amplitude: 2, phase: i * 0.17).abs();
      _person(canvas, Offset(x, 206 - hop), h, _people[i]);
    }
  }

  void _person(Canvas canvas, Offset foot, double h, Color color) {
    final w = h * 0.5;
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(foot.dx - w / 2, foot.dy - h * 0.62, w, h * 0.62),
          Radius.circular(w / 2),
        ),
        Paint()..color = color,
      )
      ..drawCircle(
        Offset(foot.dx, foot.dy - h * 0.78),
        h * 0.2,
        Paint()..color = const Color(0xFFFFD9BD),
      );
  }

  void _heart(Canvas canvas, Offset c, double r, Color color) {
    final path = Path()
      ..moveTo(c.dx, c.dy + r)
      ..cubicTo(
        c.dx - r * 2,
        c.dy - r * 0.2,
        c.dx - r * 0.9,
        c.dy - r * 1.4,
        c.dx,
        c.dy - r * 0.45,
      )
      ..cubicTo(
        c.dx + r * 0.9,
        c.dy - r * 1.4,
        c.dx + r * 2,
        c.dy - r * 0.2,
        c.dx,
        c.dy + r,
      )
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(FamilyWorldScene old) => old.members != members;
}
