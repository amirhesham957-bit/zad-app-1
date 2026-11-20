/// The home world's scene: a sky that follows the hour in the account's
/// market zone (dawn, morning, noon, sunset, night with a moon and stars),
/// hills, and the house. The companion stands in it, drawn by the scaffold.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:zad/core/design/tokens/zad_world_colors.dart';
import 'package:zad/shared/orb/domain/companion_state.dart';
import 'package:zad/shared/worlds/world_scene.dart';

/// The part of the day the sky shows.
enum HomeDayPhase {
  /// 05:00 up to 08:00.
  dawn,

  /// 08:00 up to 12:00.
  morning,

  /// 12:00 up to 16:00.
  noon,

  /// 16:00 up to 19:00 — the sunset.
  evening,

  /// 19:00 up to 05:00.
  night;

  /// The companion's pose in this part of the day.
  CompanionState get pose => switch (this) {
    dawn || evening => CompanionState.idle,
    morning || noon => CompanionState.happy,
    night => CompanionState.sleepy,
  };
}

/// The phase of the day for a civil [hour] (0-23) in the account's zone.
HomeDayPhase homeDayPhaseOf(int hour) {
  if (hour >= 5 && hour < 8) return HomeDayPhase.dawn;
  if (hour >= 8 && hour < 12) return HomeDayPhase.morning;
  if (hour >= 12 && hour < 16) return HomeDayPhase.noon;
  if (hour >= 16 && hour < 19) return HomeDayPhase.evening;
  return HomeDayPhase.night;
}

/// Paints the sky and the house for [phase].
class HomeWorldScene extends CustomPainter {
  /// Creates the painter.
  new(this.loop, {required this.phase}) : super(repaint: loop);

  /// The scaffold's loop.
  final Animation<double> loop;

  /// Which sky.
  final HomeDayPhase phase;

  static const Map<HomeDayPhase, List<Color>> _sky =
      <HomeDayPhase, List<Color>>{
        HomeDayPhase.dawn: <Color>[Color(0xFF8FB8E8), Color(0xFFFFD6B0)],
        HomeDayPhase.morning: <Color>[Color(0xFF7CC3F2), Color(0xFFDDF1FB)],
        HomeDayPhase.noon: <Color>[Color(0xFF4FA9EC), Color(0xFFC6E8FA)],
        HomeDayPhase.evening: <Color>[Color(0xFF5B5FA8), Color(0xFFFFB27A)],
        HomeDayPhase.night: <Color>[Color(0xFF0B1B3A), Color(0xFF27407A)],
      };

  bool get _dark => phase == HomeDayPhase.night;

  @override
  void paint(Canvas canvas, Size size) {
    final t = loop.value;
    final sky = _sky[phase]!;
    const full = Rect.fromLTWH(0, 0, 430, 230);
    canvas
      ..save()
      ..clipRRect(RRect.fromRectAndRadius(full, const Radius.circular(28)))
      ..drawRect(
        full,
        Paint()
          ..shader = ui.Gradient.linear(Offset.zero, const Offset(0, 230), sky),
      );

    if (_dark) _stars(canvas, t);
    _body(canvas, t);
    _clouds(canvas, t);
    _hills(canvas);
    _house(canvas, t);
    canvas.restore();
  }

  void _stars(Canvas canvas, double t) {
    for (final (i, o) in const <Offset>[
      Offset(30, 28),
      Offset(96, 70),
      Offset(160, 24),
      Offset(214, 58),
      Offset(262, 22),
      Offset(396, 108),
      Offset(404, 30),
      Offset(188, 104),
      Offset(60, 120),
    ].indexed) {
      canvas.drawCircle(
        o,
        1.4 + 1.4 * worldTwinkle(t, phase: i * 0.17),
        Paint()..color = Colors.white.withValues(alpha: 0.85),
      );
    }
  }

  void _body(Canvas canvas, double t) {
    if (_dark) {
      const c = Offset(346, 62);
      canvas
        ..drawCircle(
          c,
          46,
          Paint()..color = const Color(0xFFFFF3C4).withValues(alpha: 0.12),
        )
        ..drawCircle(c, 24, Paint()..color = const Color(0xFFFFF3C4))
        ..drawCircle(c + const Offset(11, -6), 21, Paint()..color = sky0());
      return;
    }
    final (c, r, color) = switch (phase) {
      HomeDayPhase.dawn => (
        const Offset(360, 150),
        24.0,
        const Color(0xFFFFC46B),
      ),
      HomeDayPhase.morning => (
        const Offset(352, 88),
        26.0,
        const Color(0xFFFFD34D),
      ),
      HomeDayPhase.noon => (
        const Offset(300, 40),
        28.0,
        const Color(0xFFFFE066),
      ),
      HomeDayPhase.evening => (
        const Offset(366, 140),
        32.0,
        const Color(0xFFFF8A3D),
      ),
      HomeDayPhase.night => (Offset.zero, 0.0, Colors.white),
    };
    final pulse = 1 + 0.05 * math.sin(t * 2 * math.pi);
    canvas
      ..drawCircle(
        c,
        r * 1.9 * pulse,
        Paint()..color = color.withValues(alpha: 0.22),
      )
      ..drawCircle(c, r, Paint()..color = color);
  }

  /// The night sky's top colour, which the moon's bite is cut with.
  Color sky0() {
    final night = _sky[HomeDayPhase.night]!;
    return Color.lerp(night[0], night[1], 0.2)!;
  }

  void _clouds(Canvas canvas, double t) {
    final tint = switch (phase) {
      HomeDayPhase.night => Colors.white.withValues(alpha: 0.10),
      HomeDayPhase.evening => const Color(0xFFFFE3D0).withValues(alpha: 0.7),
      _ => Colors.white.withValues(alpha: 0.85),
    };
    void cloud(double x, double y, double s) {
      final p = Paint()..color = tint;
      canvas
        ..drawOval(
          Rect.fromCenter(center: Offset(x, y), width: 62 * s, height: 22 * s),
          p,
        )
        ..drawCircle(Offset(x - 12 * s, y - 8 * s), 12 * s, p)
        ..drawCircle(Offset(x + 6 * s, y - 12 * s), 15 * s, p);
    }

    cloud(210 + 14 * math.sin(t * 2 * math.pi), 52, 1);
    cloud(110 - 10 * math.sin(t * 2 * math.pi), 96, 0.7);
  }

  void _hills(Canvas canvas) {
    final base = _dark ? const Color(0xFF0B2A20) : const Color(0xFF2D6A4F);
    final front = _dark ? const Color(0xFF071C16) : ZadWorldColors.home;
    canvas
      ..drawPath(
        Path()
          ..moveTo(0, 170)
          ..quadraticBezierTo(110, 140, 230, 176)
          ..quadraticBezierTo(330, 148, 430, 172)
          ..lineTo(430, 230)
          ..lineTo(0, 230)
          ..close(),
        Paint()..color = base,
      )
      ..drawPath(
        Path()
          ..moveTo(0, 196)
          ..quadraticBezierTo(140, 178, 260, 200)
          ..quadraticBezierTo(360, 184, 430, 198)
          ..lineTo(430, 230)
          ..lineTo(0, 230)
          ..close(),
        Paint()..color = front,
      );
  }

  void _house(Canvas canvas, double t) {
    final lit = phase == HomeDayPhase.evening || phase == HomeDayPhase.night;
    final wall = _dark ? const Color(0xFFD9DEE8) : Colors.white;
    const roof = Color(0xFFD95726);
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(232, 148, 84, 56),
          const Radius.circular(6),
        ),
        Paint()..color = wall,
      )
      ..drawPath(
        Path()
          ..moveTo(224, 152)
          ..lineTo(274, 114)
          ..lineTo(324, 152)
          ..close(),
        Paint()..color = roof,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(262, 170, 22, 34),
          const Radius.circular(5),
        ),
        Paint()..color = ZadWorldColors.home,
      );
    final glow = lit ? 0.75 + 0.25 * worldTwinkle(t) : 1.0;
    final windowColor = lit
        ? Color.lerp(
            const Color(0xFFFFC857),
            const Color(0xFFFFE9A8),
            glow - 0.75,
          )!
        : const Color(0xFFBFE3F7);
    for (final x in <double>[240, 294]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 160, 16, 16),
          const Radius.circular(3),
        ),
        Paint()..color = windowColor,
      );
    }
  }

  @override
  bool shouldRepaint(HomeWorldScene old) => old.phase != phase;
}
