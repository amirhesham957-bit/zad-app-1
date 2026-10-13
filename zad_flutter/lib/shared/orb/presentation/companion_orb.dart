/// Kotlin's `CompanionOrb` (ui/components/CompanionOrb.kt), whole: the
/// breathing, the liquid phase, the thinking swirl, the moving sheen, the
/// random blinks, the tap glow and squeeze, the alert shake, the squash while
/// speaking, the celebration sparkles, the seven moods' colours cross-fading
/// over 500ms, the moods' eyes (capsules, ^ ^, frowning lids), and the
/// accessory — same layers, same numbers. On an occasion it also wears the
/// season's look (`orb_occasion.dart`): a lantern, balloons or a scarf.
///
/// With a companion (رفيق زاد, `companion_catalog.dart`) it is that
/// character: its colours under the mood's, its build, its crest, its stage
/// (a shell, then hands, feet, an aura, a gold halo), its outfit, and its
/// sleep. Without one — signed out, offline, tests — it is the classic orb.
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
import 'package:zad/shared/companion/application/companion_controller.dart';
import 'package:zad/shared/companion/domain/companion_catalog.dart';
import 'package:zad/shared/orb/application/orb_accessory_controller.dart';
import 'package:zad/shared/orb/application/orb_occasion_controller.dart';
import 'package:zad/shared/orb/domain/companion_state.dart';
import 'package:zad/shared/orb/domain/orb_accessory.dart';
import 'package:zad/shared/orb/domain/orb_occasion.dart';
import 'package:zad/shared/orb/presentation/plush_painting.dart';

const Color _bowPink = Color(0xFFFF6FA5);
const Color _bowPinkDeep = Color(0xFFD9467E);
const Color _glassesFrame = Color(0xFF2B2B3A);
const Color _crownGold = Color(0xFFFFC53D);
const Color _crownGoldDeep = Color(0xFFE09A12);
const Color _crownGem = Color(0xFFE5484D);
const Color _flowerPetal = Color(0xFFFFFFFF);
const Color _flowerCenter = Color(0xFFFFC53D);
const Color _heartYellow = Color(0xFFFFF176);
const Color _lanternGlass = Color(0xFFFFE08A);
const Color _lanternGlow = Color(0x80FFB300);
const Color _string = Color(0x99485A6B);
const Color _shell = Color(0xFFFFF4E2);
const Color _shellEdge = Color(0xFFE8D6B8);
const Color _leaf = Color(0xFF45BF68);
const Color _leafDeep = Color(0xFF2E8B4A);
const Color _ink = Color(0xFF14181F);
const Color _sleepBlue = Color(0xFF8FA2FF);

/// The orb.
class CompanionOrb extends ConsumerStatefulWidget {
  /// Creates the orb.
  const new({
    this.state = CompanionState.happy,
    this.accessory,
    this.occasion,
    this.look,
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

  /// The season's look; null reads today's occasion.
  final OrbOccasion? occasion;

  /// The companion to draw; null reads the customer's own, and with none at
  /// all the orb is the classic one.
  final CompanionLook? look;

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
    final occasion =
        widget.occasion ?? ref.watch<OrbOccasion>(orbOccasionProvider);
    final look = widget.look ?? ref.watch(companionLookProvider);
    _asleep = look?.asleep ?? false;
    final painter = _OrbPainter(
      frame: this,
      state: widget.state,
      accessory: accessory,
      occasion: occasion,
      look: look,
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
      orb = Semantics(
        label: look == null
            ? widget.state.description
            : look.asleep
            ? '${look.persona.name} نايم'
            : '${look.persona.name}: ${widget.state.description}',
        child: orb,
      );
    }
    if (widget.onTap == null) return orb;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _tap,
      child: ScaleTransition(scale: _tapScale, child: orb),
    );
  }

  // ── what the painter reads each frame ──

  bool _asleep = false;

  double get _ms => _elapsed.value.inMicroseconds / 1000;

  /// 0.98 → 1.05, 2600ms each way, FastOutSlowIn — 4400ms and shallower
  /// asleep.
  double get breath => !widget.animated
      ? 1
      : _asleep
      ? 0.985 + 0.045 * _pingPong(_ms, 4400, Curves.easeInOut)
      : 0.98 + 0.07 * _pingPong(_ms, 2600, Curves.fastOutSlowIn);

  /// Seconds since the orb started, for loops of their own (the Zs).
  double get seconds => _ms / 1000;

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
    required this.occasion,
    required this.look,
    required this.animated,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final _CompanionOrbState frame;
  final CompanionState state;
  final OrbAccessory accessory;
  final OrbOccasion occasion;
  final CompanionLook? look;
  final bool animated;

  static Shader _radial(List<Color> colors, Offset center, double radius) =>
      RadialGradient(colors: colors)
          .createShader(Rect.fromCircle(center: center, radius: radius));

  @override
  void paint(Canvas canvas, Size size) {
    final look = this.look;
    final persona = look?.persona;
    final asleep = look?.asleep ?? false;
    // A character keeps its own colour; the mood tints it, so a mood still
    // reads at a glance. Asleep, everything dims toward the night.
    var sky = persona == null
        ? frame.sky
        : Color.lerp(persona.body, frame.sky, 0.12)!;
    var deep = persona == null
        ? frame.deep
        : Color.lerp(persona.deep, frame.deep, 0.12)!;
    if (asleep) {
      sky = Color.lerp(sky, const Color(0xFF7C86B8), 0.25)!;
      deep = Color.lerp(deep, const Color(0xFF2B2F55), 0.25)!;
    }
    final level = frame.level;
    final phase = frame.blobPhase;
    final glow = frame.glow;
    final stage = look?.stage;

    final canvasCenter = size.center(Offset.zero);
    final baseRadius = size.shortestSide / 2 * 0.62 * (stage?.scale ?? 1);
    final radius = baseRadius * frame.breath * (1 + 0.08 * level);

    final lift = switch (state) {
      CompanionState.speaking => -radius * 0.07 * level,
      CompanionState.listening => -radius * 0.03,
      CompanionState.celebrating ||
      CompanionState.happy => -radius * 0.04 * math.sin(phase * 2),
      _ => 0.0,
    };
    final center = canvasCenter + Offset(frame.shake * radius * 0.07, lift);
    final squashX =
        (1 + (state == CompanionState.speaking ? 0.05 * level : 0.0)) *
        (persona?.width ?? 1);
    final squashY =
        (1 - (state == CompanionState.speaking ? 0.04 * level : 0.0)) *
        (persona?.height ?? 1);

    // 1. Ground shadow — thinner as the body lifts.
    if (persona != null) {
      PlushPainting.contactShadow(
        canvas,
        Offset(canvasCenter.dx, canvasCenter.dy + radius * 1.0),
        radius,
        lift,
        deep,
      );
    }
    final shadowW = radius * 1.35 * (1 + lift / (radius * 2));
    if (persona == null) {
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
    }

    // 2. Halo, breathing with the voice and flashing on a tap.
    final halo = radius * (1.42 + 0.28 * level + 0.2 * glow);
    // A character is a toy, not a lamp: its halo only answers the voice and
    // a tap.
    final haloAlpha = persona == null
        ? 1.0
        : 0.25 + 0.75 * math.max(level, glow);
    canvas.drawCircle(
      center,
      halo,
      Paint()
        ..shader = _radial(
          <Color>[
            sky.withValues(
              alpha:
                  math.min(0.85, 0.30 + 0.30 * level + 0.25 * glow) * haloAlpha,
            ),
            sky.withValues(alpha: 0.10 * haloAlpha),
            sky.withValues(alpha: 0),
          ],
          center,
          halo,
        ),
    );

    // 2b. رفيق and حكيم: a second, slower light in the character's colour.
    if (stage != null && stage.index >= CompanionStage.companion.index) {
      final aura = radius * (1.7 + 0.08 * math.sin(phase));
      canvas.drawCircle(
        center,
        aura,
        Paint()
          ..shader = _radial(
            <Color>[
              (persona?.body ?? sky).withValues(alpha: 0.22),
              (persona?.body ?? sky).withValues(alpha: 0),
            ],
            center,
            aura,
          ),
      );
    }

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(squashX, squashY);
    canvas.translate(-center.dx, -center.dy);

    if (persona != null) {
      _plush(canvas, center, radius, sky, deep, persona, stage, asleep, level);
      canvas.restore();
      _companionExtras(canvas, center, radius, phase, stage, asleep);
      return;
    }

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
    // 5b. فانوس glows from inside.
    if (persona?.glows ?? false) {
      canvas.drawCircle(
        center + Offset(0, radius * 0.2),
        radius * 0.8,
        Paint()
          ..shader = _radial(
            <Color>[
              const Color(0xFFFFD27A).withValues(alpha: 0.45),
              Colors.transparent,
            ],
            center + Offset(0, radius * 0.2),
            radius * 0.8,
          ),
      );
    }
    canvas.restore();

    // 5d. بذرة: still half in its shell.
    if (stage == CompanionStage.seed) _eggShell(canvas, center, radius);

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

    // 8. Eyes — shut and smiling asleep, bigger in the shell.
    if (asleep) {
      _sleepingEyes(canvas, center, radius);
    } else {
      _eyes(
        canvas,
        center,
        radius * (stage == CompanionStage.seed ? 1.15 : 1),
        frame.eyeOpen,
        level,
        phase,
      );
    }

    // 8a. The character's crest, unless a hat covers the head.
    if (persona != null && !look!.outfit.coversHead) {
      _crest(canvas, center, radius, phase, persona.crest);
    }

    // 8b. Accessory, inside the squash so it bounces with the body.
    _accessory(canvas, center, radius);

    // 8b2. What the companion wears.
    if (look != null) _outfit(canvas, center, radius, phase, look.outfit);

    // 8c. The season's look, also inside the squash.
    _occasionLook(canvas, center, radius, phase);
    canvas.restore();

    // 8d. حكيم: a gold halo above, three stars circling slowly.
    if (stage == CompanionStage.sage) _sageHalo(canvas, center, radius, phase);

    // 8e. Asleep: Zs drifting up and away.
    if (asleep && animated) _zs(canvas, center, radius, frame.seconds);

    // 9. Celebration: four gold sparkles circling.
    _celebration(canvas, center, radius, phase);
  }

  void _celebration(Canvas canvas, Offset center, double radius, double phase) {
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

  void _occasionLook(Canvas canvas, Offset c, double r, double phase) {
    switch (occasion.look) {
      case OrbOccasionLook.none:
        return;
      case OrbOccasionLook.lantern:
        // Held out at the right on a short stick, swaying ±8° with the
        // liquid phase, its glass lit from inside.
        final hand = c + Offset(r * 0.92, r * 0.02);
        final hook = c + Offset(r * 1.26, -r * 0.18);
        canvas
          ..drawLine(
            hand,
            hook,
            Paint()
              ..color = _crownGoldDeep
              ..strokeWidth = r * 0.06
              ..strokeCap = StrokeCap.round,
          )
          ..save()
          ..translate(hook.dx, hook.dy)
          ..rotate(8 * math.pi / 180 * math.sin(phase));
        final w = r * 0.44;
        final h = r * 0.50;
        final top = r * 0.14;
        final frameGold = Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[_crownGold, _crownGoldDeep],
          ).createShader(Rect.fromLTWH(-w / 2, 0, w, top + h + r * 0.14));
        final cap = Path()
          ..moveTo(0, 0)
          ..lineTo(w * 0.40, top)
          ..lineTo(-w * 0.40, top)
          ..close();
        final glass = Path()
          ..moveTo(-w * 0.40, top)
          ..lineTo(w * 0.40, top)
          ..lineTo(w / 2, top + h * 0.5)
          ..lineTo(w * 0.30, top + h)
          ..lineTo(-w * 0.30, top + h)
          ..lineTo(-w / 2, top + h * 0.5)
          ..close();
        final tip = Path()
          ..moveTo(-w * 0.30, top + h)
          ..lineTo(w * 0.30, top + h)
          ..lineTo(0, top + h + r * 0.14)
          ..close();
        final rib = Paint()
          ..color = _crownGoldDeep
          ..strokeWidth = r * 0.03;
        canvas
          ..drawCircle(
            Offset(0, top + h * 0.5),
            r * 0.42,
            Paint()..color = _lanternGlow,
          )
          ..drawPath(
            glass,
            Paint()
              ..shader =
                  const RadialGradient(
                    colors: <Color>[_lanternGlass, _crownGold],
                  ).createShader(
                    Rect.fromCircle(
                      center: Offset(0, top + h * 0.5),
                      radius: w * 0.6,
                    ),
                  ),
          )
          ..drawPath(
            glass,
            Paint()
              ..color = _crownGoldDeep
              ..style = PaintingStyle.stroke
              ..strokeWidth = r * 0.04,
          )
          ..drawLine(Offset(-w * 0.17, top), Offset(-w * 0.12, top + h), rib)
          ..drawLine(Offset(w * 0.17, top), Offset(w * 0.12, top + h), rib)
          ..drawPath(cap, frameGold)
          ..drawPath(tip, frameGold)
          ..drawCircle(Offset.zero, r * 0.035, Paint()..color = _crownGoldDeep)
          ..restore();
      case OrbOccasionLook.balloons:
        // Three balloons above the left hand, each bobbing on its own beat.
        final hand = c + Offset(-r * 0.90, r * 0.30);
        final colors = <Color>[
          occasion.primary ?? _bowPink,
          occasion.secondary ?? _flowerCenter,
          _crownGold,
        ];
        const spots = <Offset>[
          Offset(-1.18, -0.62),
          Offset(-0.86, -0.92),
          Offset(-1.36, -0.98),
        ];
        for (var i = 0; i < 3; i++) {
          final bob = r * 0.05 * math.sin(phase + i * 2.1);
          final b = c + Offset(spots[i].dx * r, spots[i].dy * r + bob);
          final bottom = b + Offset(0, r * 0.22);
          canvas
            ..drawLine(
              hand,
              bottom,
              Paint()
                ..color = _string
                ..strokeWidth = r * 0.02,
            )
            ..drawOval(
              Rect.fromCenter(center: b, width: r * 0.36, height: r * 0.44),
              Paint()..color = colors[i],
            )
            ..drawPath(
              Path()
                ..moveTo(bottom.dx, bottom.dy - r * 0.01)
                ..lineTo(bottom.dx - r * 0.04, bottom.dy + r * 0.05)
                ..lineTo(bottom.dx + r * 0.04, bottom.dy + r * 0.05)
                ..close(),
              Paint()..color = colors[i],
            )
            ..drawOval(
              Rect.fromCenter(
                center: b + Offset(-r * 0.06, -r * 0.09),
                width: r * 0.08,
                height: r * 0.12,
              ),
              Paint()..color = Colors.white.withValues(alpha: 0.45),
            );
        }
      case OrbOccasionLook.scarf:
        // A band wrapped round the lower body in the occasion's colours —
        // clipped to the body so it reads as cloth, not as a mouth — and
        // its end hanging off the right, swinging a little.
        final primary = occasion.primary ?? _crownGem;
        final secondary = occasion.secondary ?? Colors.white;
        final upper = c.dy + r * 0.42;
        final lower = c.dy + r * 0.74;
        final band = Path()
          ..moveTo(c.dx - r * 1.1, upper - r * 0.06)
          ..quadraticBezierTo(
            c.dx,
            upper + r * 0.14,
            c.dx + r * 1.1,
            upper - r * 0.06,
          )
          ..lineTo(c.dx + r * 1.1, lower - r * 0.06)
          ..quadraticBezierTo(
            c.dx,
            lower + r * 0.14,
            c.dx - r * 1.1,
            lower - r * 0.06,
          )
          ..close();
        final stripe = Path()
          ..moveTo(c.dx - r * 1.1, upper + r * 0.07)
          ..quadraticBezierTo(
            c.dx,
            upper + r * 0.27,
            c.dx + r * 1.1,
            upper + r * 0.07,
          )
          ..lineTo(c.dx + r * 1.1, upper + r * 0.13)
          ..quadraticBezierTo(
            c.dx,
            upper + r * 0.33,
            c.dx - r * 1.1,
            upper + r * 0.13,
          )
          ..close();
        canvas
          ..save()
          ..clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)))
          ..drawPath(band, Paint()..color = primary)
          ..drawPath(stripe, Paint()..color = secondary)
          ..restore();
        final knot = c + Offset(r * 0.62, r * 0.60);
        canvas
          ..save()
          ..translate(knot.dx, knot.dy)
          ..rotate((-18 + 6 * math.sin(phase)) * math.pi / 180)
          ..drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(-r * 0.12, 0, r * 0.24, r * 0.56),
              Radius.circular(r * 0.06),
            ),
            Paint()..color = primary,
          )
          ..drawRect(
            Rect.fromLTWH(-r * 0.12, r * 0.18, r * 0.24, r * 0.06),
            Paint()..color = secondary,
          )
          ..drawRect(
            Rect.fromLTWH(-r * 0.12, r * 0.40, r * 0.24, r * 0.06),
            Paint()..color = secondary,
          )
          ..restore();
    }
  }

  // ── the companion's layers ──

  /// The painted character (`plush_painting.dart`), inside the squash: feet
  /// behind, the body, hands in front, then its face and everything it
  /// wears — the crest, the outfit and the season sit where the orb's did.
  void _plush(
    Canvas canvas,
    Offset center,
    double radius,
    Color sky,
    Color deep,
    CompanionPersona persona,
    CompanionStage? stage,
    bool asleep,
    double level,
  ) {
    final phase = frame.blobPhase;
    final stageIndex = stage?.index ?? CompanionStage.companion.index;
    final limbBody = Color.lerp(sky, deep, 0.08)!;

    // Feet from صغيّر, peeking out under the body.
    if (stageIndex >= CompanionStage.little.index) {
      for (final side in <double>[-1, 1]) {
        PlushPainting.limb(
          canvas,
          Rect.fromCenter(
            center: center + Offset(side * radius * 0.42, radius * 0.94),
            width: radius * 0.46,
            height: radius * 0.26,
          ),
          body: limbBody,
          deep: deep,
        );
      }
    }

    PlushPainting.paintBody(
      canvas,
      center,
      radius,
      body: sky,
      deep: deep,
      sheen: frame.sheen,
      seed: persona.index + 7,
      glows: persona.glows,
    );

    // Thinking: a soft light turning slowly inside.
    if (state == CompanionState.focused) {
      final a = frame.rotation * math.pi / 180;
      canvas.save();
      canvas.clipPath(PlushPainting.silhouette(center, radius));
      canvas.drawCircle(
        center +
            Offset(math.cos(a) * radius * 0.45, math.sin(a) * radius * 0.45),
        radius * 0.5,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.22)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.2),
      );
      canvas.restore();
    }

    // Hands from بُرعم: a slow sway, a wave when happy.
    if (stageIndex >= CompanionStage.sprout.index) {
      final cheer =
          state == CompanionState.happy || state == CompanionState.celebrating;
      for (final side in <double>[-1, 1]) {
        final swing = cheer
            ? 0.5 + 0.35 * math.sin(phase * 4 + (side > 0 ? 0 : math.pi))
            : 0.12 * math.sin(phase + side);
        canvas.save();
        canvas.translate(
          center.dx + side * radius * 0.94,
          center.dy + radius * 0.22,
        );
        canvas.rotate(-side * (0.35 + swing));
        PlushPainting.limb(
          canvas,
          Rect.fromCenter(
            center: Offset(0, radius * 0.12),
            width: radius * 0.26,
            height: radius * 0.4,
          ),
          body: limbBody,
          deep: deep,
        );
        canvas.restore();
      }
    }

    // مشمش is fluffy: a soft rim of fuzz.
    if (persona.crest == PersonaCrest.leaf) {
      PlushPainting.fluff(canvas, center, radius, sky, persona.index);
    }

    // بذرة: still half in its shell — the face sits a little higher.
    final seed = stage == CompanionStage.seed;
    if (seed) _eggShell(canvas, center, radius);
    final face = seed ? center - Offset(0, radius * 0.12) : center;
    final faceR = radius * (seed ? 1.1 : 1);

    if (!asleep) PlushPainting.cheeks(canvas, face, faceR);
    PlushPainting.eyes(
      canvas,
      face,
      faceR,
      state: state,
      open: frame.eyeOpen,
      look: _glance(radius, phase),
      level: level,
      asleep: asleep,
    );
    if (!seed || asleep) {
      PlushPainting.mouth(
        canvas,
        face,
        faceR,
        state: state,
        level: level,
        asleep: asleep,
      );
    }

    if (!look!.outfit.coversHead) {
      _crest(canvas, center, radius, phase, persona.crest);
    }
    _accessory(canvas, center, radius);
    _outfit(canvas, center, radius, phase, look!.outfit);
    _occasionLook(canvas, center, radius, phase);
  }

  /// What floats outside the squash: the sage's halo, the Zs, the sparkles.
  void _companionExtras(
    Canvas canvas,
    Offset center,
    double radius,
    double phase,
    CompanionStage? stage,
    bool asleep,
  ) {
    if (stage == CompanionStage.sage) _sageHalo(canvas, center, radius, phase);
    if (asleep && animated) _zs(canvas, center, radius, frame.seconds);
    _celebration(canvas, center, radius, phase);
  }

  /// Where the eyes look for the mood — the same glances as the orb's.
  Offset _glance(double radius, double phase) => switch (state) {
    CompanionState.idle => Offset(radius * 0.05 * math.sin(phase * 0.5), 0),
    CompanionState.listening => Offset(0, -radius * 0.04),
    CompanionState.focused => Offset(
      radius * 0.08 * math.cos(phase),
      -radius * 0.10,
    ),
    _ => Offset.zero,
  };

  void _eggShell(Canvas canvas, Offset c, double r) {
    // The lower shell, its rim broken into a zigzag.
    final top = c.dy + r * 0.18;
    final rect = Rect.fromCircle(center: c, radius: r * 1.06);
    const teeth = 9;
    final rim = Path()..moveTo(c.dx - r * 1.05, top);
    for (var i = 1; i <= teeth * 2; i++) {
      final x = c.dx - r * 1.05 + i * (r * 2.1) / (teeth * 2);
      rim.lineTo(x, i.isOdd ? top - r * 0.14 : top);
    }
    final shell = Path()
      ..addPath(rim, Offset.zero)
      ..lineTo(c.dx + r * 1.06, c.dy + r * 1.1)
      ..lineTo(c.dx - r * 1.06, c.dy + r * 1.1)
      ..close();
    canvas
      ..save()
      ..clipPath(Path()..addOval(rect))
      ..drawPath(
        shell,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[_shell, _shellEdge],
          ).createShader(rect),
      )
      ..drawPath(
        rim,
        Paint()
          ..color = _shellEdge
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.03,
      )
      ..restore();
  }

  void _sleepingEyes(Canvas canvas, Offset c, double r) {
    final y = c.dy - r * 0.02;
    for (final side in <double>[-1, 1]) {
      final x = c.dx + side * r * 0.36;
      canvas.drawPath(
        Path()
          ..moveTo(x - r * 0.15, y)
          ..quadraticBezierTo(x, y + r * 0.12, x + r * 0.15, y),
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.07
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _zs(Canvas canvas, Offset c, double r, double seconds) {
    for (var i = 0; i < 3; i++) {
      final t = (seconds / 2.4 + i / 3) % 1;
      final at = c + Offset(r * (0.7 + 0.35 * t), -r * (0.6 + 0.9 * t));
      final s = r * (0.16 + 0.12 * t);
      final p = Paint()
        ..color = _sleepBlue.withValues(alpha: (1 - t) * 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.05
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(
        Path()
          ..moveTo(at.dx - s / 2, at.dy - s / 2)
          ..lineTo(at.dx + s / 2, at.dy - s / 2)
          ..lineTo(at.dx - s / 2, at.dy + s / 2)
          ..lineTo(at.dx + s / 2, at.dy + s / 2),
        p,
      );
    }
  }

  void _sageHalo(Canvas canvas, Offset c, double r, double phase) {
    final haloCenter = c - Offset(0, r * 1.22 + r * 0.04 * math.sin(phase));
    canvas.drawOval(
      Rect.fromCenter(center: haloCenter, width: r * 0.95, height: r * 0.26),
      Paint()
        ..color = _crownGold
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.07,
    );
    for (var i = 0; i < 3; i++) {
      final a = phase * 0.7 + i * 2 * math.pi / 3;
      _sparkle(
        canvas,
        c + Offset(math.cos(a) * r * 1.45, math.sin(a) * r * 0.55 - r * 0.2),
        r * 0.1,
        _crownGold,
      );
    }
  }

  void _crest(
    Canvas canvas,
    Offset c,
    double r,
    double phase,
    PersonaCrest crest,
  ) {
    final top = Offset(c.dx, c.dy - r * 0.97);
    final sway = 0.12 * math.sin(phase);
    switch (crest) {
      case PersonaCrest.sprout:
      case PersonaCrest.leaf:
        canvas
          ..save()
          ..translate(top.dx, top.dy)
          ..rotate(sway)
          ..drawLine(
            Offset.zero,
            Offset(0, -r * 0.22),
            Paint()
              ..color = _leafDeep
              ..strokeWidth = r * 0.06
              ..strokeCap = StrokeCap.round,
          );
        final sides = crest == PersonaCrest.sprout
            ? const <double>[-1, 1]
            : const <double>[1];
        for (final side in sides) {
          canvas
            ..save()
            ..translate(side * r * 0.15, -r * 0.24)
            ..rotate(side * 0.45)
            ..drawOval(
              Rect.fromCenter(
                center: Offset.zero,
                width: r * 0.34,
                height: r * 0.14,
              ),
              Paint()..color = _leaf,
            )
            ..restore();
        }
        canvas.restore();
      case PersonaCrest.syrup:
        // A glossy syrup top with pistachio crumbs.
        final cap = Path()
          ..addArc(
            Rect.fromCircle(center: c, radius: r * 1.01),
            math.pi * 1.12,
            math.pi * 0.76,
          );
        canvas.drawPath(
          cap,
          Paint()
            ..color = const Color(0xFFC77D1A).withValues(alpha: 0.9)
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.12
            ..strokeCap = StrokeCap.round,
        );
        for (var i = 0; i < 5; i++) {
          final a = math.pi * (1.22 + i * 0.14);
          canvas.drawCircle(
            c + Offset(math.cos(a) * r * 0.9, math.sin(a) * r * 0.9),
            r * 0.045,
            Paint()..color = const Color(0xFF7CB342),
          );
        }
      case PersonaCrest.jasmine:
        final f = c + Offset(-r * 0.58, -r * 0.74);
        for (var i = 0; i < 5; i++) {
          final a = (i * 72 - 90) * math.pi / 180 + sway;
          canvas.drawOval(
            Rect.fromCenter(
              center:
                  f + Offset(math.cos(a) * r * 0.12, math.sin(a) * r * 0.12),
              width: r * 0.17,
              height: r * 0.17,
            ),
            Paint()..color = Colors.white,
          );
        }
        canvas.drawCircle(f, r * 0.07, Paint()..color = _flowerCenter);
      case PersonaCrest.pepper:
        canvas
          ..save()
          ..translate(top.dx, top.dy + r * 0.04)
          ..rotate(sway)
          ..drawOval(
            Rect.fromCenter(
              center: Offset.zero,
              width: r * 0.42,
              height: r * 0.13,
            ),
            Paint()..color = _leafDeep,
          )
          ..drawPath(
            Path()
              ..moveTo(0, 0)
              ..quadraticBezierTo(r * 0.02, -r * 0.24, r * 0.18, -r * 0.26),
            Paint()
              ..color = _leaf
              ..style = PaintingStyle.stroke
              ..strokeWidth = r * 0.07
              ..strokeCap = StrokeCap.round,
          )
          ..restore();
      case PersonaCrest.beret:
        canvas
          ..save()
          ..translate(top.dx + r * 0.12, top.dy + r * 0.02)
          ..rotate(-0.22)
          ..drawOval(
            Rect.fromCenter(
              center: Offset.zero,
              width: r * 1.0,
              height: r * 0.3,
            ),
            Paint()..color = const Color(0xFF2A1C4D),
          )
          ..drawCircle(
            Offset(-r * 0.02, -r * 0.16),
            r * 0.05,
            Paint()..color = const Color(0xFF2A1C4D),
          )
          ..restore();
      case PersonaCrest.crescent:
        final at = top - Offset(0, r * 0.32 + r * 0.04 * math.sin(phase));
        final moon = Path()
          ..addOval(Rect.fromCircle(center: at, radius: r * 0.17));
        final bite = Path()
          ..addOval(
            Rect.fromCircle(
              center: at + Offset(r * 0.08, -r * 0.04),
              radius: r * 0.15,
            ),
          );
        canvas.drawPath(
          Path.combine(PathOperation.difference, moon, bite),
          Paint()..color = _crownGold,
        );
      case PersonaCrest.sugar:
        canvas
          ..save()
          ..clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)))
          ..drawRect(
            Rect.fromLTRB(c.dx - r, c.dy - r, c.dx + r, c.dy - r * 0.55),
            Paint()..color = Colors.white.withValues(alpha: 0.85),
          );
        for (var i = 0; i < 9; i++) {
          canvas.drawCircle(
            Offset(
              c.dx - r * 0.7 + i * r * 0.18,
              c.dy - r * 0.55 + (i.isEven ? r * 0.04 : r * 0.08),
            ),
            r * 0.05,
            Paint()..color = Colors.white.withValues(alpha: 0.85),
          );
        }
        canvas.restore();
    }
  }

  void _outfit(
    Canvas canvas,
    Offset c,
    double r,
    double phase,
    CompanionOutfit outfit,
  ) {
    switch (outfit) {
      case CompanionOutfit.none:
        return;
      case CompanionOutfit.sunglasses:
        final y = c.dy - r * 0.06;
        final lens = Paint()..color = _ink;
        for (final side in <double>[-1, 1]) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset(c.dx + side * r * 0.36, y),
                width: r * 0.42,
                height: r * 0.3,
              ),
              Radius.circular(r * 0.12),
            ),
            lens,
          );
        }
        canvas
          ..drawLine(
            Offset(c.dx - r * 0.15, y - r * 0.05),
            Offset(c.dx + r * 0.15, y - r * 0.05),
            Paint()
              ..color = _ink
              ..strokeWidth = r * 0.05,
          )
          ..drawLine(
            Offset(c.dx - r * 0.46, y - r * 0.08),
            Offset(c.dx - r * 0.34, y - r * 0.02),
            Paint()
              ..color = Colors.white.withValues(alpha: 0.5)
              ..strokeWidth = r * 0.035,
          );
      case CompanionOutfit.winterHat:
        final rect = Rect.fromCircle(center: c, radius: r * 1.03);
        canvas
          ..drawArc(
            rect,
            math.pi * 1.08,
            math.pi * 0.84,
            false,
            Paint()..color = const Color(0xFFE86B6B),
          )
          ..drawPath(
            Path()
              ..addArc(rect, math.pi * 1.08, math.pi * 0.84)
              ..close(),
            Paint()..color = const Color(0xFFE86B6B),
          )
          ..drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset(c.dx, c.dy - r * 0.62),
                width: r * 1.62,
                height: r * 0.22,
              ),
              Radius.circular(r * 0.11),
            ),
            Paint()..color = const Color(0xFFC94F4F),
          )
          ..drawCircle(
            Offset(c.dx, c.dy - r * 1.08 + r * 0.03 * math.sin(phase * 2)),
            r * 0.16,
            Paint()..color = Colors.white,
          );
      case CompanionOutfit.chefHat:
        final white = Paint()..color = Colors.white;
        final base = c.dy - r * 0.78;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(c.dx, base),
              width: r * 0.92,
              height: r * 0.24,
            ),
            Radius.circular(r * 0.05),
          ),
          white,
        );
        for (final dx in <double>[-0.28, 0, 0.28]) {
          canvas.drawCircle(
            Offset(c.dx + dx * r, base - r * (dx == 0 ? 0.36 : 0.26)),
            r * 0.26,
            white,
          );
        }
        canvas.drawLine(
          Offset(c.dx - r * 0.42, base + r * 0.04),
          Offset(c.dx + r * 0.42, base + r * 0.04),
          Paint()
            ..color = const Color(0xFFE0E0E0)
            ..strokeWidth = r * 0.03,
        );
      case CompanionOutfit.shemagh:
        final cloth = Path()
          ..moveTo(c.dx - r * 1.08, c.dy + r * 0.1)
          ..quadraticBezierTo(
            c.dx - r * 1.1,
            c.dy - r * 1.25,
            c.dx,
            c.dy - r * 1.12,
          )
          ..quadraticBezierTo(
            c.dx + r * 1.1,
            c.dy - r * 1.25,
            c.dx + r * 1.08,
            c.dy + r * 0.1,
          )
          ..lineTo(c.dx + r * 0.86, c.dy - r * 0.5)
          ..quadraticBezierTo(
            c.dx,
            c.dy - r * 0.78,
            c.dx - r * 0.86,
            c.dy - r * 0.5,
          )
          ..close();
        canvas.drawPath(cloth, Paint()..color = const Color(0xFFFBF8F2));
        canvas
          ..save()
          ..clipPath(cloth);
        final red = Paint()
          ..color = const Color(0xFFC8102E).withValues(alpha: 0.55)
          ..strokeWidth = r * 0.025;
        for (var i = -6; i <= 6; i += 2) {
          canvas
            ..drawLine(
              Offset(c.dx + i * r * 0.18, c.dy - r * 1.3),
              Offset(c.dx + i * r * 0.18 + r * 0.6, c.dy + r * 0.2),
              red,
            )
            ..drawLine(
              Offset(c.dx + i * r * 0.18, c.dy - r * 1.3),
              Offset(c.dx + i * r * 0.18 - r * 0.6, c.dy + r * 0.2),
              red,
            );
        }
        canvas.restore();
        final agal = Paint()
          ..color = _ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.07;
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(c.dx, c.dy - r * 0.84),
            width: r * 1.5,
            height: r * 0.36,
          ),
          math.pi,
          math.pi,
          false,
          agal,
        );
      case CompanionOutfit.gradCap:
        final cap = Paint()..color = const Color(0xFF15171C);
        final y = c.dy - r * 0.92;
        canvas
          ..drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset(c.dx, y + r * 0.1),
                width: r * 0.86,
                height: r * 0.26,
              ),
              Radius.circular(r * 0.06),
            ),
            cap,
          )
          ..drawPath(
            Path()
              ..moveTo(c.dx - r * 0.8, y - r * 0.04)
              ..lineTo(c.dx, y - r * 0.3)
              ..lineTo(c.dx + r * 0.8, y - r * 0.04)
              ..lineTo(c.dx, y + r * 0.2)
              ..close(),
            cap,
          );
        final swing = 0.15 * math.sin(phase * 2);
        canvas
          ..save()
          ..translate(c.dx + r * 0.62, y - r * 0.02)
          ..rotate(swing)
          ..drawLine(
            Offset.zero,
            Offset(0, r * 0.4),
            Paint()
              ..color = _crownGold
              ..strokeWidth = r * 0.03,
          )
          ..drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset(0, r * 0.44),
                width: r * 0.08,
                height: r * 0.14,
              ),
              Radius.circular(r * 0.03),
            ),
            Paint()..color = _crownGold,
          )
          ..restore()
          ..drawCircle(
            Offset(c.dx, y - r * 0.05),
            r * 0.04,
            Paint()..color = _crownGold,
          );
    }
  }

  @override
  bool shouldRepaint(_OrbPainter old) =>
      old.state != state ||
      old.accessory != accessory ||
      old.occasion != occasion ||
      old.look != look ||
      old.animated != animated;
}
