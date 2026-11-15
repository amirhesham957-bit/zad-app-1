/// Idle motion for Home's icons and calls to action (owner, 15/11: «انميشن
/// الايكونات»): a short move played after a first delay and then once every
/// few seconds — a nudge, not a loop that never rests.
///
/// Every piece here stops when the system asks for no animation
/// (`MediaQuery.disableAnimationsOf`) and when [ZadIdleMotion.loops] is false,
/// which `test/flutter_test_config.dart` sets so `pumpAndSettle` never waits
/// on a timer that re-arms itself.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:zad/core/design/tokens/zad_motion.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';

/// The switch shared by every idle animation.
abstract final class ZadIdleMotion {
  /// Whether idle animations run at all. Tests turn it off.
  static bool loops = true;
}

/// What the icon does when it plays.
enum ZadIdleKind {
  /// Lifts a little and settles (the pantry box).
  lift,

  /// A short side-to-side wiggle (the cart, the gift).
  wiggle,

  /// A small bob up and down (the pill).
  bob,

  /// One full turn (the subscriptions' arrows).
  turn,
}

/// Plays [builder] with a 0..1 progress once after [first], then every
/// [every]. Nothing runs while motion is off.
class ZadIdlePlayer extends StatefulWidget {
  /// Creates the player.
  const new({
    required this.builder,
    this.first = const Duration(milliseconds: 700),
    this.every = const Duration(seconds: 7),
    this.play = const Duration(milliseconds: 900),
    super.key,
  });

  /// Draws the child at progress `t` (0 at rest, 1 at the end of a play).
  final Widget Function(BuildContext context, double t) builder;

  /// The wait before the first play.
  final Duration first;

  /// The gap between the end of one play and the next.
  final Duration every;

  /// How long one play lasts.
  final Duration play;

  @override
  State<ZadIdlePlayer> createState() => _ZadIdlePlayerState();
}

class _ZadIdlePlayerState extends State<ZadIdlePlayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.play,
  );
  Timer? _timer;
  bool _active = false;

  void _schedule(Duration after) {
    _timer?.cancel();
    _timer = Timer(after, () {
      if (!mounted || !_active) return;
      unawaited(
        _c.forward(from: 0).then((_) {
          if (mounted && _active) _schedule(widget.every);
        }),
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final on = ZadIdleMotion.loops && !MediaQuery.disableAnimationsOf(context);
    if (on == _active) return;
    _active = on;
    if (on) {
      _schedule(widget.first);
    } else {
      _timer?.cancel();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, _) => widget.builder(context, _c.value),
  );
}

/// [child] moves the way [kind] says, on a schedule. [urgent] adds a soft glow
/// of [glow] behind it on every play.
class ZadIdle extends StatelessWidget {
  /// Creates it. [stagger] (0, 1, 2, …) offsets the first play and the gap so
  /// neighbours never move together.
  const new({
    required this.kind,
    required this.child,
    this.stagger = 0,
    this.urgent = false,
    this.glow,
    super.key,
  });

  /// The move.
  final ZadIdleKind kind;

  /// The icon.
  final Widget child;

  /// This icon's place among its neighbours.
  final int stagger;

  /// Whether to glow as well.
  final bool urgent;

  /// The glow's colour.
  final Color? glow;

  @override
  Widget build(BuildContext context) => ZadIdlePlayer(
    first: Duration(milliseconds: 600 + stagger * 650),
    every: Duration(milliseconds: 6000 + stagger * 700),
    builder: (context, t) {
      final wave = math.sin(t * math.pi);
      final Widget moved = switch (kind) {
        ZadIdleKind.lift => Transform.translate(
          offset: Offset(0, -ZadSpacing.xs * wave),
          child: child,
        ),
        ZadIdleKind.wiggle => Transform.rotate(
          angle: math.sin(t * math.pi * 4) * 0.22 * (1 - t),
          child: child,
        ),
        ZadIdleKind.bob => Transform.translate(
          offset: Offset(0, -3 * math.sin(t * math.pi * 2)),
          child: child,
        ),
        ZadIdleKind.turn => Transform.rotate(
          angle: ZadCurves.standard.transform(t) * math.pi * 2,
          child: child,
        ),
      };
      if (!urgent || glow == null) return moved;
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ZadSpacing.sm + 2),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: glow!.withValues(alpha: 0.38 * wave),
              blurRadius: 10 * wave,
              spreadRadius: 2 * wave,
            ),
          ],
        ),
        child: moved,
      );
    },
  );
}

/// A light sweep across [child] (the rewarded ad, «اشترك»), clipped to
/// [radius]. It never takes a tap.
class ZadShine extends StatelessWidget {
  /// Creates it.
  const new({
    required this.child,
    this.radius = 24,
    this.every = const Duration(seconds: 5),
    this.first = const Duration(milliseconds: 1200),
    super.key,
  });

  /// What is shone on.
  final Widget child;

  /// The clip's corner radius.
  final double radius;

  /// The gap between sweeps.
  final Duration every;

  /// The wait before the first sweep.
  final Duration first;

  @override
  Widget build(BuildContext context) => ZadIdlePlayer(
    first: first,
    every: every,
    play: ZadDuration.shimmer,
    builder: (context, t) => Stack(
      children: <Widget>[
        child,
        if (t > 0 && t < 1)
          Positioned.fill(
            child: IgnorePointer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: FractionallySizedBox(
                  alignment: Alignment(-1.6 + 3.2 * t, 0),
                  widthFactor: 0.28,
                  child: Transform(
                    transform: Matrix4.skewX(-0.35),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[
                            Colors.white.withValues(alpha: 0),
                            Colors.white.withValues(alpha: 0.45),
                            Colors.white.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
