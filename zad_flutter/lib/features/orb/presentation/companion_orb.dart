/// Kotlin's `CompanionOrb` (ui/components/CompanionOrb.kt), whole: the
/// breathing, the liquid phase, the thinking swirl, the moving sheen, the
/// random blinks, the tap glow and squeeze, the alert shake, the squash while
/// speaking, the celebration sparkles, the seven moods' colours cross-fading
/// over 500ms, the moods' eyes (capsules, ^ ^, frowning lids), and the
/// accessory — same layers, same numbers.
///
/// One ticker drives every loop and only the painter listens to it, so a
/// running orb repaints its own layer each frame and rebuilds nothing.
library;

// One statement per numbered layer reads closer to Kotlin's draw order than
// a single cascade spanning them.
// ignore_for_file: cascade_invocations

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/features/orb/application/orb_accessory_controller.dart';
import 'package:zad/features/orb/domain/companion_state.dart';
import 'package:zad/features/orb/domain/orb_accessory.dart';

const Color _bowPink = Color(0xFFFF6FA5);
const Color _bowPinkDeep = Color(0xFFD9467E);
const Color _glassesFrame = Color(0xFF2B2B3A);
const Color _crownGold = Color(0xFFFFC53D);
const Color _crownGoldDeep = Color(0xFFE09A12);
const Color _crownGem = Color(0xFFE5484D);
const Color _flowerPetal = Color(0xFFFFFFFF);
const Color _flowerCenter = Color(0xFFFFC53D);
const Color _heartYellow = Color(0xFFFFF176);

/// The orb.
class CompanionOrb extends ConsumerStatefulWidget {
  /// Creates the orb.
  const new({
    this.state = CompanionState.happy,
    this.accessory,
    this.size = 96,
    this.animated = true,
    this.blinkTrigger = 0,
    this.glowTrigger = 0,
    this.audioLevel,
    this.onTap,
    super.key,
  });

  /// Its mood.
  final CompanionState state;

  /// What it wears; null reads the customer's saved choice.
  final OrbAccessory? accessory;

  /// The box it is drawn in.
  final double size;

  /// Every continuous motion — breath, liquid phase, blinking. Off for a
  /// copy repeated down a list, as Kotlin turns it off in chat bubbles.
  final bool animated;

  /// A change (not the value) blinks twice at once.
  final int blinkTrigger;

  /// A change (not the value) flashes the halo for 450ms.
  final int glowTrigger;

  /// Loudness 0..1 while listening or speaking. A listenable, not a value,
  /// for Kotlin's reason: it changes once per mic buffer, and only the
  /// painter should hear about it.
  final ValueListenable<double>? audioLevel;

  /// A tap: squeeze, two blinks and the halo, then this.
  final VoidCallback? onTap;

  @override
  ConsumerState<CompanionOrb> createState() => _CompanionOrbState();
}

class _CompanionOrbState extends ConsumerState<CompanionOrb>
    with TickerProviderStateMixin {
  // ── the clock for every loop ──
  late final Ticker _ticker = createTicker(_onTick);
  final ValueNotifier<Duration> _elapsed = ValueNotifier<Duration>(
    Duration.zero,
  );

  // ── colours: tween(500) between moods ──
  late final AnimationController _colorT = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
    value: 1,
  );
  late Color _fromSky = widget.state.sky;
  late Color _fromDeep = widget.state.deep;

  // ── blinking: tween(85, FastOutSlowIn) toward the eye's target ──
  late final AnimationController _eye = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 85),
    value: 1,
  );
  Timer? _blinkLoop;
  int _blinkRun = 0;

  // ── the tap's halo: tween(450, FastOutSlowIn) ──
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  int _glowRun = 0;

  // ── the tap's squeeze: ZadSprings.Press ──
  late final AnimationController _tapScale = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );
  static const SpringDescription _press = SpringDescription(
    mass: 1,
    stiffness: 600,
    // 2 · 0.55 · √600
    damping: 26.944387170614,
  );

  // ── the alert's shake ──
  late final AnimationController _shake = AnimationController.unbounded(
    vsync: this,
  );
  int _shakeRun = 0;

  int _tapPulse = 0;

  @override
  void initState() {
    super.initState();
    if (widget.animated) {
      _ticker.start();
      _scheduleBlink();
    }
    if (widget.state == CompanionState.alert) unawaited(_runShake());
  }

  @override
  void didUpdateWidget(CompanionOrb old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) {
      final t = Curves.linear.transform(_colorT.value);
      _fromSky = Color.lerp(_fromSky, old.state.sky, t)!;
      _fromDeep = Color.lerp(_fromDeep, old.state.deep, t)!;
      _colorT.value = 0;
      _colorT.forward();
      if (widget.state == CompanionState.alert) {
        unawaited(_runShake());
      } else {
        _shakeRun++;
        _shake.value = 0;
      }
    }
    if (old.animated != widget.animated) {
      if (widget.animated) {
        if (!_ticker.isActive) _ticker.start();
        _scheduleBlink();
      } else {
        _ticker.stop();
        _blinkLoop?.cancel();
        _elapsed.value = Duration.zero;
      }
    }
    if (old.blinkTrigger != widget.blinkTrigger && widget.blinkTrigger != 0) {
      unawaited(_doubleBlink());
    }
    if (old.glowTrigger != widget.glowTrigger && widget.glowTrigger != 0) {
      unawaited(_flashGlow());
    }
  }

  @override
  void dispose() {
    _blinkLoop?.cancel();
    _ticker.dispose();
    _elapsed.dispose();
    _colorT.dispose();
    _eye.dispose();
    _glow.dispose();
    _tapScale.dispose();
    _shake.dispose();
    super.dispose();
  }

  // A ticker callback, handed to createTicker — not a setter.
  // ignore: use_setters_to_change_properties
  void _onTick(Duration elapsed) {
    _elapsed.value = elapsed;
  }

  Future<void> _eyeTo(double target) => _eye.animateTo(
    target,
    duration: const Duration(milliseconds: 85),
    curve: Curves.fastOutSlowIn,
  );

  Future<void> _wait(int ms) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  /// Kotlin: `delay(Random.nextLong(2400, 5200))`, shut to 8%, 100ms, open.
  void _scheduleBlink() {
    _blinkLoop?.cancel();
    final ms = 2400 + math.Random().nextInt(5200 - 2400);
    _blinkLoop = Timer(Duration(milliseconds: ms), () async {
      if (!mounted || !widget.animated) return;
      unawaited(_eyeTo(0.08));
      await _wait(100);
      if (!mounted) return;
      unawaited(_eyeTo(1));
      _scheduleBlink();
    });
  }

  /// Two quick blinks: 90 shut, 70 open, 90 shut, open.
  Future<void> _doubleBlink() async {
    final run = ++_blinkRun;
    unawaited(_eyeTo(0.08));
    await _wait(90);
    if (!mounted || run != _blinkRun) return;
    unawaited(_eyeTo(1));
    await _wait(70);
    if (!mounted || run != _blinkRun) return;
    unawaited(_eyeTo(0.08));
    await _wait(90);
    if (!mounted || run != _blinkRun) return;
    unawaited(_eyeTo(1));
  }

  /// The halo to 1 and back after 120ms; the squeeze follows the target.
  Future<void> _flashGlow() async {
    final run = ++_glowRun;
    _springTap(0.92);
    _glow.animateTo(
      1,
      duration: const Duration(milliseconds: 450),
      curve: Curves.fastOutSlowIn,
    );
    await _wait(120);
    if (!mounted || run != _glowRun) return;
    _springTap(1);
    _glow.animateTo(
      0,
      duration: const Duration(milliseconds: 450),
      curve: Curves.fastOutSlowIn,
    );
  }

  void _springTap(double target) => _tapScale.animateWith(
    SpringSimulation(_press, _tapScale.value, target, _tapScale.velocity),
  );

  /// Three 55ms swings each way, then 80ms home — "upset", once, not a
  /// siren. Compose's `tween` eases FastOutSlowIn.
  Future<void> _runShake() async {
    if (!widget.animated) return;
    final run = ++_shakeRun;
    Future<bool> to(double v, int ms) async {
      await _shake.animateTo(
        v,
        duration: Duration(milliseconds: ms),
        curve: Curves.fastOutSlowIn,
      );
      return mounted && run == _shakeRun;
    }

    for (var i = 0; i < 3; i++) {
      if (!await to(1, 55)) return;
      if (!await to(-1, 55)) return;
    }
    await to(0, 80);
  }

  void _tap() {
    _tapPulse = DateTime.now().millisecondsSinceEpoch;
    unawaited(_doubleBlink());
    unawaited(_flashGlow());
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(orbAccessoryProvider);
    final accessory = widget.accessory ?? saved;
    final painter = _OrbPainter(
      frame: this,
      state: widget.state,
      accessory: accessory,
      animated: widget.animated,
      repaint: Listenable.merge(<Listenable?>[
        _elapsed,
        _colorT,
        _eye,
        _glow,
        _shake,
        widget.audioLevel,
      ]),
    );
    Widget orb = RepaintBoundary(
      child: CustomPaint(size: Size.square(widget.size), painter: painter),
    );
    if (widget.animated) {
      orb = Semantics(label: widget.state.description, child: orb);
    }
    if (widget.onTap == null) return orb;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _tap,
      child: ScaleTransition(scale: _tapScale, child: orb),
    );
  }

  // ── what the painter reads each frame ──

  double get _ms => _elapsed.value.inMicroseconds / 1000;

  /// 0.98 → 1.05, 2600ms each way, FastOutSlowIn.
  double get breath => widget.animated
      ? 0.98 + 0.07 * _pingPong(_ms, 2600, Curves.fastOutSlowIn)
      : 1;

  /// 0 → 2π every 6000ms, linear.
  double get blobPhase =>
      widget.animated ? (_ms % 6000) / 6000 * 2 * math.pi : 0;

  /// 0 → 360° every 10000ms, linear.
  double get rotation => widget.animated ? (_ms % 10000) / 10000 * 360 : 0;

  /// 0.15 → 0.55, 3200ms each way, FastOutSlowIn.
  double get sheen => widget.animated
      ? 0.15 + 0.40 * _pingPong(_ms, 3200, Curves.fastOutSlowIn)
      : 0.3;

  Color get sky => Color.lerp(_fromSky, widget.state.sky, _colorT.value)!;

  Color get deep => Color.lerp(_fromDeep, widget.state.deep, _colorT.value)!;

  double get eyeOpen => _eye.value;

  double get glow => _glow.value;

  double get shake => _shake.value;

  double get level => (widget.audioLevel?.value ?? 0).clamp(0.0, 1.0);

  // Kept so a tap is observable the way Kotlin's tapPulse is.
  int get tapPulse => _tapPulse;

  static double _pingPong(double ms, int period, Curve curve) {
    final cycle = (ms / period).floor();
    final t = (ms % period) / period;
    final v = cycle.isEven ? t : 1 - t;
    return curve.transform(v);
  }
}

class _OrbPainter extends CustomPainter {
  new({
    required this.frame,
    required this.state,
    required this.accessory,
    required this.animated,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final _CompanionOrbState frame;
  final CompanionState state;
  final OrbAccessory accessory;
  final bool animated;

  static Shader _radial(List<Color> colors, Offset center, double radius) =>
      RadialGradient(colors: colors)
          .createShader(Rect.fromCircle(center: center, radius: radius));

  @override
  void paint(Canvas canvas, Size size) {
    final sky = frame.sky;
    final deep = frame.deep;
    final level = frame.level;
    final phase = frame.blobPhase;
    final glow = frame.glow;

    final canvasCenter = size.center(Offset.zero);
    final baseRadius = size.shortestSide / 2 * 0.62;
    final radius = baseRadius * frame.breath * (1 + 0.08 * level);

    final lift = switch (state) {
      CompanionState.speaking => -radius * 0.07 * level,
      CompanionState.listening => -radius * 0.03,
      CompanionState.celebrating ||
      CompanionState.happy => -radius * 0.04 * math.sin(phase * 2),
      _ => 0.0,
    };
    final center = canvasCenter + Offset(frame.shake * radius * 0.07, lift);
    final squashX = 1 + (state == CompanionState.speaking ? 0.05 * level : 0.0);
    final squashY = 1 - (state == CompanionState.speaking ? 0.04 * level : 0.0);

    // 1. Ground shadow — thinner as the body lifts.
    final shadowW = radius * 1.35 * (1 + lift / (radius * 2));
    canvas.drawOval(
      Rect.fromLTWH(
        canvasCenter.dx - shadowW / 2,
        canvasCenter.dy + radius * 1.02,
        shadowW,
        radius * 0.22,
      ),
      Paint()
        ..shader = _radial(
          <Color>[deep.withValues(alpha: 0.22), deep.withValues(alpha: 0)],
          Offset(canvasCenter.dx, canvasCenter.dy + radius * 1.12),
          shadowW / 2,
        ),
    );

    // 2. Halo, breathing with the voice and flashing on a tap.
    final halo = radius * (1.42 + 0.28 * level + 0.2 * glow);
    canvas.drawCircle(
      center,
      halo,
      Paint()
        ..shader = _radial(
          <Color>[
            sky.withValues(
              alpha: math.min(0.85, 0.30 + 0.30 * level + 0.25 * glow),
            ),
            sky.withValues(alpha: 0.10),
            sky.withValues(alpha: 0),
          ],
          center,
          halo,
        ),
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(squashX, squashY);
    canvas.translate(-center.dx, -center.dy);

    // 3. Body, lit from the top-left.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = _radial(
          <Color>[
            Color.lerp(sky, Colors.white, 0.42)!,
            sky,
            Color.lerp(sky, deep, 0.55)!,
            deep,
          ],
          center - Offset(radius * 0.32, radius * 0.38),
          radius * 1.55,
        ),
    );

    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
    );
    // 4. Bounce light from the bottom-right.
    final bounce = center + Offset(radius * 0.42, radius * 0.62);
    canvas.drawCircle(
      bounce,
      radius * 0.62,
      Paint()
        ..shader = _radial(
          <Color>[
            Color.lerp(sky, Colors.white, 0.25)!.withValues(alpha: 0.45),
            Colors.transparent,
          ],
          bounce,
          radius * 0.62,
        ),
    );
    // 5. Thinking: a light turning slowly inside.
    if (state == CompanionState.focused) {
      final a = frame.rotation * math.pi / 180;
      final swirl =
          center +
          Offset(math.cos(a) * radius * 0.45, math.sin(a) * radius * 0.45);
      canvas.drawCircle(
        swirl,
        radius * 0.7,
        Paint()
          ..shader = _radial(
            <Color>[Colors.white.withValues(alpha: 0.30), Colors.transparent],
            swirl,
            radius * 0.7,
          ),
      );
    }
    canvas.restore();

    // 6. Glass sheen, an oval tilted -32°.
    final spec = center - Offset(radius * 0.40, radius * 0.46);
    canvas.save();
    canvas.translate(spec.dx, spec.dy);
    canvas.rotate(-32 * math.pi / 180);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: radius * 0.68,
        height: radius * 0.38,
      ),
      Paint()
        ..shader = _radial(
          <Color>[
            Colors.white.withValues(
              alpha: math.min(0.9, 0.62 + 0.25 * frame.sheen),
            ),
            Colors.white.withValues(alpha: 0),
          ],
          Offset.zero,
          radius * 0.34,
        ),
    );
    canvas.restore();

    // 7. Fresnel rim, 1.2dp.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Colors.white.withValues(alpha: 0.55),
            Colors.white.withValues(alpha: 0.08),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    // 8. Eyes.
    _eyes(canvas, center, radius, frame.eyeOpen, level, phase);

    // 8b. Accessory, inside the squash so it bounces with the body.
    _accessory(canvas, center, radius);
    canvas.restore();

    // 9. Celebration: four gold sparkles circling.
    if (state == CompanionState.celebrating) {
      for (var i = 0; i < 4; i++) {
        final a = (frame.rotation + i * 90) * math.pi / 180;
        final star =
            center +
            Offset(math.cos(a) * radius * 1.32, math.sin(a) * radius * 1.32);
        _sparkle(
          canvas,
          star,
          radius * (0.10 + 0.03 * math.sin(phase * 3 + i)),
          _heartYellow,
        );
      }
    }
  }

  void _eyes(
    Canvas canvas,
    Offset center,
    double radius,
    double open,
    double level,
    double phase,
  ) {
    final spacing = radius * 0.36;
    final width = radius * 0.22;
    final baseY = center.dy - radius * 0.06;
    final look = switch (state) {
      CompanionState.idle => Offset(radius * 0.05 * math.sin(phase * 0.5), 0),
      CompanionState.listening => Offset(0, -radius * 0.04),
      CompanionState.focused => Offset(
        radius * 0.08 * math.cos(phase),
        -radius * 0.10,
      ),
      _ => Offset.zero,
    };
    final left = Offset(center.dx - spacing, baseY) + look;
    final right = Offset(center.dx + spacing, baseY) + look;

    switch (state) {
      case CompanionState.happy:
      case CompanionState.celebrating:
        _happyArc(canvas, left, width * 1.5, radius * 0.16, radius * 0.085);
        _happyArc(canvas, right, width * 1.5, radius * 0.16, radius * 0.085);
      case CompanionState.alert:
        final h = radius * 0.40 * open;
        _angryEye(canvas, left, width, h, innerOnRight: true);
        _angryEye(canvas, right, width, h, innerOnRight: false);
      case CompanionState.idle:
      case CompanionState.listening:
      case CompanionState.focused:
      case CompanionState.speaking:
        final h =
            switch (state) {
              CompanionState.listening => radius * (0.46 + 0.10 * level),
              CompanionState.speaking => radius * (0.42 - 0.12 * level),
              CompanionState.focused => radius * 0.34,
              _ => radius * 0.42,
            } *
            open;
        _capsuleEye(canvas, left, width, h);
        _capsuleEye(canvas, right, width, h);
    }
  }

  void _capsuleEye(Canvas canvas, Offset c, double width, double height) {
    final h = math.max(height, width * 0.35);
    final topLeft = Offset(c.dx - width / 2, c.dy - h / 2);
    // The soft glow round the eye.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          topLeft.dx - width * 0.18,
          topLeft.dy - width * 0.18,
          width * 1.36,
          h + width * 0.36,
        ),
        Radius.circular(width * 0.68),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.22),
    );
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(topLeft.dx, topLeft.dy, width, h),
        topLeft: Radius.elliptical(width / 2, math.min(width / 2, h / 2)),
        topRight: Radius.elliptical(width / 2, math.min(width / 2, h / 2)),
        bottomLeft: Radius.elliptical(width / 2, math.min(width / 2, h / 2)),
        bottomRight: Radius.elliptical(width / 2, math.min(width / 2, h / 2)),
      ),
      Paint()..color = Colors.white,
    );
  }

  /// The capsule clipped under a slanted lid — a frown.
  void _angryEye(
    Canvas canvas,
    Offset c,
    double width,
    double height, {
    required bool innerOnRight,
  }) {
    final top = c.dy - height / 2;
    final outerX = innerOnRight ? c.dx - width * 1.2 : c.dx + width * 1.2;
    final innerX = innerOnRight ? c.dx + width * 1.2 : c.dx - width * 1.2;
    final belowLid = Path()
      ..moveTo(outerX, top + height * 0.02)
      ..lineTo(innerX, top + height * 0.46)
      ..lineTo(innerX, c.dy + height)
      ..lineTo(outerX, c.dy + height)
      ..close();
    canvas.save();
    canvas.clipPath(belowLid);
    _capsuleEye(canvas, c, width, height);
    canvas.restore();
  }

  void _happyArc(Canvas canvas, Offset at, double w, double h, double stroke) {
    final path = Path()
      ..moveTo(at.dx - w / 2, at.dy + h / 2)
      ..quadraticBezierTo(at.dx, at.dy - h, at.dx + w / 2, at.dy + h / 2);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  void _sparkle(Canvas canvas, Offset c, double s, Color color) {
    final path = Path()
      ..moveTo(c.dx, c.dy - s)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + s, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + s)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - s, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - s)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _accessory(Canvas canvas, Offset c, double r) {
    switch (accessory) {
      case OrbAccessory.none:
        return;
      case OrbAccessory.bow:
        final knot = c + Offset(r * 0.48, -r * 0.80);
        for (final dir in <double>[-1, 1]) {
          canvas
            ..save()
            ..translate(knot.dx, knot.dy)
            ..rotate(dir * 28 * math.pi / 180)
            ..drawOval(
              Rect.fromLTWH(
                dir < 0 ? -r * 0.56 : 0,
                -r * 0.19,
                r * 0.56,
                r * 0.38,
              ),
              Paint()..color = _bowPink,
            )
            ..restore();
        }
        canvas.drawCircle(knot, r * 0.12, Paint()..color = _bowPinkDeep);
      case OrbAccessory.glasses:
        final y = c.dy - r * 0.06;
        final lens = r * 0.2;
        final left = Offset(c.dx - r * 0.36, y);
        final right = Offset(c.dx + r * 0.36, y);
        final glass = Paint()..color = Colors.white.withValues(alpha: 0.18);
        final frameStroke = Paint()
          ..color = _glassesFrame
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.055;
        canvas
          ..drawCircle(left, lens, glass)
          ..drawCircle(right, lens, glass)
          ..drawCircle(left, lens, frameStroke)
          ..drawCircle(right, lens, frameStroke)
          ..drawLine(
            left + Offset(lens, 0),
            right - Offset(lens, 0),
            Paint()
              ..color = _glassesFrame
              ..strokeWidth = r * 0.05,
          );
      case OrbAccessory.flower:
        final f = c + Offset(-r * 0.55, -r * 0.72);
        for (var i = 0; i < 5; i++) {
          final a = (i * 72 - 90) * math.pi / 180;
          canvas.drawCircle(
            f + Offset(math.cos(a) * r * 0.13, math.sin(a) * r * 0.13),
            r * 0.11,
            Paint()..color = _flowerPetal,
          );
        }
        canvas.drawCircle(f, r * 0.08, Paint()..color = _flowerCenter);
      case OrbAccessory.crown:
        final base = c.dy - r * 0.80;
        final w = r * 0.86;
        final h = r * 0.50;
        final left = c.dx - w / 2;
        final path = Path()
          ..moveTo(left, base)
          ..lineTo(left, base - h * 0.6)
          ..lineTo(left + w * 0.25, base - h * 0.25)
          ..lineTo(left + w * 0.5, base - h)
          ..lineTo(left + w * 0.75, base - h * 0.25)
          ..lineTo(left + w, base - h * 0.6)
          ..lineTo(left + w, base)
          ..close();
        canvas
          ..drawPath(
            path,
            Paint()
              ..shader = const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[_crownGold, _crownGoldDeep],
              ).createShader(Rect.fromLTRB(left, base - h, left + w, base)),
          )
          ..drawCircle(
            Offset(c.dx, base - h * 0.32),
            r * 0.08,
            Paint()..color = _crownGem,
          );
    }
  }

  @override
  bool shouldRepaint(_OrbPainter old) =>
      old.state != state ||
      old.accessory != accessory ||
      old.animated != animated;
}
