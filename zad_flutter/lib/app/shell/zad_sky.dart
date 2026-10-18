/// The sky behind the header (ZAD_PLAN ٢.٣): warm at dawn, plain by day, a
/// dusk glow in the evening and a few twinkling stars at night — read from the
/// hour in the account's market zone, never the phone's.
///
/// A tint over the header's own surface, never a new colour under the text:
/// the tokens at low opacity, so the words read the same at every hour. The
/// stars hold still under reduced motion and repaint on their own layer.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/core/design/tokens/zad_colors.dart';

/// The time of day the header shows.
enum SkyPhase {
  /// 05:00–07:59.
  dawn,

  /// 08:00–16:59.
  day,

  /// 17:00–19:59.
  dusk,

  /// 20:00–04:59.
  night,
}

/// The phase for an hour (0–23) in the account's zone.
SkyPhase skyPhaseFor(int hour) => switch (hour) {
  >= 5 && < 8 => SkyPhase.dawn,
  >= 8 && < 17 => SkyPhase.day,
  >= 17 && < 20 => SkyPhase.dusk,
  _ => SkyPhase.night,
};

/// The phase at [now] in the account's [zone]. Without the zone database (a
/// test, an unknown name) the day — the header as it always was.
SkyPhase skyPhaseAt(String zone, DateTime now) {
  try {
    return skyPhaseFor(tz.TZDateTime.from(now, tz.getLocation(zone)).hour);
  } on Object {
    return SkyPhase.day;
  }
}

/// The tint over the header for [phase], top to bottom; empty for the day.
List<Color> skyTint(SkyPhase phase) => switch (phase) {
  SkyPhase.dawn => <Color>[
    ZadColors.mustardOchre.withValues(alpha: 0.16),
    ZadColors.mustardOchre.withValues(alpha: 0.02),
  ],
  SkyPhase.day => const <Color>[],
  SkyPhase.dusk => <Color>[
    ZadColors.terracottaRust.withValues(alpha: 0.14),
    ZadColors.mustardOchre.withValues(alpha: 0.04),
  ],
  SkyPhase.night => <Color>[
    ZadColors.slate.withValues(alpha: 0.18),
    ZadColors.slate.withValues(alpha: 0.04),
  ],
};

/// The header's sky: [child] on its tint, with stars at night.
class ZadSky extends StatelessWidget {
  /// Creates the sky.
  const new({required this.phase, required this.child, super.key});

  /// The time of day.
  final SkyPhase phase;

  /// The header.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tint = skyTint(phase);
    if (tint.isEmpty) return child;
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: DecoratedBox(
            key: ValueKey<String>('sky-${phase.name}'),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: tint,
              ),
            ),
          ),
        ),
        if (phase == SkyPhase.night)
          Positioned.fill(
            child: RepaintBoundary(
              child: IgnorePointer(child: _Stars(still: still)),
            ),
          ),
        child,
      ],
    );
  }
}

class _Stars extends StatefulWidget {
  const new({required this.still});

  final bool still;

  @override
  State<_Stars> createState() => _StarsState();
}

class _StarsState extends State<_Stars> with SingleTickerProviderStateMixin {
  late final AnimationController _twinkle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  @override
  void initState() {
    super.initState();
    if (!widget.still) _twinkle.repeat();
  }

  @override
  void didUpdateWidget(_Stars old) {
    super.didUpdateWidget(old);
    if (widget.still) {
      _twinkle.stop();
    } else if (!_twinkle.isAnimating) {
      _twinkle.repeat();
    }
  }

  @override
  void dispose() {
    _twinkle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    key: const ValueKey<String>('sky-stars'),
    painter: _StarsPainter(_twinkle, ZadColors.slate),
  );
}

class _StarsPainter extends CustomPainter {
  new(this.t, this.color) : super(repaint: t);

  final Animation<double> t;
  final Color color;

  // Fixed spots, as fractions of the header: the same sky every night.
  static const List<(double, double, double)> _spots =
      <(double, double, double)>[
        (0.08, 0.22, 0.0),
        (0.21, 0.55, 0.3),
        (0.37, 0.18, 0.6),
        (0.52, 0.42, 0.15),
        (0.66, 0.20, 0.45),
        (0.79, 0.50, 0.75),
        (0.92, 0.28, 0.9),
      ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final (x, y, offset) in _spots) {
      final phase = (t.value + offset) % 1;
      final glow = 0.25 + 0.35 * (0.5 + 0.5 * math.sin(phase * 2 * math.pi));
      paint.color = color.withValues(alpha: glow);
      canvas.drawCircle(Offset(x * size.width, y * size.height), 1.4, paint);
    }
  }

  @override
  bool shouldRepaint(_StarsPainter old) => old.color != color;
}
