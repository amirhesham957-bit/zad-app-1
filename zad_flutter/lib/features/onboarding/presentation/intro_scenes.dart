/// The four painted scenes of the introduction, in a fixed 430×420 design
/// space (the approved HTML preview's `scene(i)`): fridge, house, assistant
/// spokes, budget bars. Zado is not painted here — the stage lays the real
/// `CompanionOrb` over the scene.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';

/// The size every scene is drawn in; the stage scales it to fit.
const Size kIntroSceneSize = Size(430, 420);

/// How long the budget bars take, last one included (stagger 120ms each).
const Duration kIntroGrowDuration = Duration(milliseconds: 1560);

/// The length of the repeating loop that drives floats and the spin. 28s
/// holds whole cycles of the 4s float, the 5.6s float and the 14s spin.
const Duration kIntroLoopDuration = Duration(seconds: 28);

const String _coinText = '٤٢'; // l10n: data
const String _riyalGlyph = 'ر'; // l10n: data
const Color _ink = Color(0xFFDCE6E0);
const Color _forest = Color(0xFF1B4332);
const Color _mint = Color(0xFF6EE7B7);

/// Paints scene [page]. [loop] is 0..1 over [kIntroLoopDuration]; [grow] is
/// 0..1 over [kIntroGrowDuration].
class IntroScenePainter extends CustomPainter {
  /// Creates the painter.
  new({required this.page, required this.loop, required this.grow})
    : super(repaint: Listenable.merge(<Listenable>[loop, grow]));

  /// Which scene, 0..3.
  final int page;

  /// The repeating loop.
  final Animation<double> loop;

  /// The one-shot growth of the budget bars.
  final Animation<double> grow;

  double get _floatA => math.sin(2 * math.pi * 7 * loop.value) * 6;
  double get _floatB => math.sin(2 * math.pi * 5 * loop.value + 1) * 6;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(215, 372), width: 340, height: 44),
      Paint()..color = const Color(0xFFDCEFE4),
    );
    switch (page) {
      case 0:
        _pantry(canvas);
      case 1:
        _family(canvas);
      case 2:
        _assistant(canvas);
      default:
        _budget(canvas);
    }
  }

  void _rr(
    Canvas c,
    double x,
    double y,
    double w,
    double h,
    double r,
    Color f,
  ) => c.drawRRect(
    RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)),
    Paint()..color = f,
  );

  void _text(Canvas c, String s, Offset at, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontFamily: kZadArabicFont,
          fontSize: size,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
      textDirection: TextDirection.rtl,
    )..layout();
    tp.paint(c, at - Offset(tp.width / 2, tp.height / 2));
  }

  Paint _stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  void _pantry(Canvas c) {
    c
      ..save()
      ..translate(0, _floatA);
    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(230, 96, 120, 250),
      const Radius.circular(18),
    );
    c
      ..drawRRect(body, Paint()..color = Colors.white)
      ..drawRRect(body, _stroke(_ink, 3))
      ..drawLine(
        const Offset(230, 190),
        const Offset(350, 190),
        _stroke(_ink, 3),
      );
    _rr(c, 244, 118, 26, 54, 6, const Color(0xFFE6F4EC));
    _rr(c, 278, 128, 22, 44, 5, const Color(0xFFFFE8B8));
    _rr(c, 306, 110, 30, 62, 6, const Color(0xFFFDEBE3));
    _rr(c, 248, 208, 36, 40, 6, const Color(0xFFF2B91E));
    c.drawCircle(
      const Offset(312, 230),
      18,
      Paint()..color = const Color(0xFFE5473C),
    );
    _rr(c, 250, 270, 84, 56, 8, const Color(0xFFE6F4EC));
    c
      ..restore()
      ..save()
      ..translate(0, _floatB)
      ..drawCircle(
        const Offset(110, 96),
        20,
        Paint()..color = const Color(0xFFFFE08A),
      );
    _text(c, _coinText, const Offset(110, 96), 18, const Color(0xFF9A6410));
    c.restore();
  }

  void _family(Canvas c) {
    final house = Path()
      ..moveTo(90, 200)
      ..lineTo(215, 110)
      ..lineTo(340, 200)
      ..lineTo(340, 350)
      ..lineTo(90, 350)
      ..close();
    final roof = Path()
      ..moveTo(70, 210)
      ..lineTo(215, 100)
      ..lineTo(360, 210);
    c
      ..drawPath(house, Paint()..color = Colors.white)
      ..drawPath(house, _stroke(_ink, 3))
      ..drawPath(roof, _stroke(_forest, 10));
    const warm = Color(0xFFFFD27A);
    _rr(c, 120, 230, 60, 46, 8, warm);
    _rr(c, 250, 230, 60, 46, 8, warm);
    _rr(c, 120, 290, 60, 46, 8, const Color(0xFFE6F4EC));
    _rr(c, 250, 290, 60, 46, 8, warm);
    c
      ..drawCircle(
        const Offset(150, 252),
        10,
        Paint()..color = const Color(0xFFC2416B),
      )
      ..drawCircle(
        const Offset(280, 252),
        10,
        Paint()..color = const Color(0xFF2F7BD8),
      )
      ..drawCircle(
        const Offset(280, 312),
        8,
        Paint()..color = const Color(0xFFC68216),
      );
  }

  void _assistant(Canvas c) {
    c
      ..save()
      ..translate(215, 210)
      ..rotate(loop.value * 2 * math.pi * 2);
    for (var a = 0; a < 360; a += 60) {
      final r = a * math.pi / 180;
      final p = Offset(140 * math.cos(r), 140 * math.sin(r));
      c
        ..drawLine(Offset.zero, p, _stroke(_mint.withValues(alpha: 0.6), 2))
        ..drawCircle(p, 14, Paint()..color = Colors.white)
        ..drawCircle(p, 14, _stroke(_mint, 3));
    }
    c
      ..restore()
      ..drawCircle(
        const Offset(215, 210),
        96,
        Paint()..color = _mint.withValues(alpha: 0.15),
      );
  }

  void _budget(Canvas c) {
    const heights = <double>[60, 110, 160, 210];
    for (var k = 0; k < heights.length; k++) {
      final t = ((grow.value * 1560 - k * 120) / 1200).clamp(0.0, 1.0);
      final h = heights[k] * Curves.easeOutBack.transform(t);
      _rr(
        c,
        230.0 + k * 34,
        350 - h,
        24,
        h,
        8,
        k == 3 ? _forest : const Color(0xFF9ED9BC),
      );
    }
    c
      ..save()
      ..translate(0, _floatA)
      ..drawCircle(
        const Offset(190, 140),
        26,
        Paint()
          ..shader =
              const RadialGradient(
                center: Alignment(-0.3, -0.4),
                colors: <Color>[Color(0xFFFFE08A), Color(0xFFC68216)],
              ).createShader(
                Rect.fromCircle(center: const Offset(190, 140), radius: 26),
              ),
      );
    _text(c, _riyalGlyph, const Offset(190, 140), 20, const Color(0xFF7A4E06));
    c.restore();
  }

  @override
  bool shouldRepaint(IntroScenePainter old) => old.page != page;
}
