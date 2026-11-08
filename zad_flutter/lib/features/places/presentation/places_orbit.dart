/// «مدار أماكنك»: home in the middle and the shops the customer keeps going
/// back to around it, the most visited closest, and the same shops as cards.
///
/// Not a geographic map, and it says so on screen: `zad_place_visits` holds no
/// coordinates on purpose (home's position stays on the phone), so distance
/// here means how often, never how far.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:zad/core/design/components/zad_card.dart';
import 'package:zad/core/design/components/zad_pressable.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_motion.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/places/domain/my_places.dart';

const double _orbitHeight = 264;
const double _nodeSize = 48;

/// The orbit.
class PlacesOrbit extends StatefulWidget {
  /// Creates the orbit of [habits]; [onOpen] is a tap on a shop.
  const new({required this.habits, required this.onOpen, super.key});

  /// The shops, most visited first.
  final List<PlaceHabit> habits;

  /// A shop was tapped.
  final ValueChanged<PlaceHabit> onOpen;

  @override
  State<PlacesOrbit> createState() => _PlacesOrbitState();
}

class _PlacesOrbitState extends State<PlacesOrbit>
    with TickerProviderStateMixin {
  late final AnimationController _bloom = AnimationController(
    vsync: this,
    duration: ZadDuration.count,
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: ZadDuration.ambient,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Motion is decoration here; a phone set to reduce it gets a still orbit.
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
      _bloom.value = 1;
    } else {
      if (!_pulse.isAnimating) _pulse.repeat();
      if (_bloom.isDismissed) _bloom.forward();
    }
  }

  @override
  void dispose() {
    _bloom.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nodes = placeOrbit(widget.habits);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: _orbitHeight,
          child: LayoutBuilder(
            builder: (context, box) {
              final middle = Offset(box.maxWidth / 2, _orbitHeight / 2);
              final reach =
                  math.min(box.maxWidth, _orbitHeight) / 2 - _nodeSize * 0.75;
              return AnimatedBuilder(
                animation: _bloom,
                builder: (context, _) {
                  final open = ZadCurves.standard.transform(_bloom.value);
                  return Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: _RingsPainter(
                              pulse: _pulse,
                              middle: middle,
                              reach: reach * open,
                              still: MediaQuery.disableAnimationsOf(context),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: middle.dx - 28,
                        top: middle.dy - 28,
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: ZadColors.hero,
                          ),
                          child: Icon(
                            Icons.home_rounded,
                            color: Colors.white,
                            semanticLabel: context.l10n.placesOrbitHome,
                          ),
                        ),
                      ),
                      for (final n in nodes)
                        _node(
                          n,
                          middle +
                              Offset(math.cos(n.angle), math.sin(n.angle)) *
                                  (reach * n.distance * open),
                          open,
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: ZadSpacing.xs),
        Text(
          context.l10n.placesOrbitCaption,
          textAlign: TextAlign.center,
          style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
        ),
      ],
    );
  }

  Widget _node(PlaceOrbitNode n, Offset at, double open) => Positioned(
    left: at.dx - 44,
    top: at.dy - _nodeSize / 2,
    width: 88,
    child: Opacity(
      opacity: open.clamp(0, 1),
      child: ZadPressable(
        onPressed: () => widget.onOpen(n.habit),
        scale: 0.92,
        semanticLabel: context.l10n.placesOrbitNode(
          n.habit.name,
          n.habit.visits,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: _nodeSize,
              height: _nodeSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ZadColors.surface,
                border: Border.all(color: ZadColors.green700, width: 1.5),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: ZadColors.green700.withValues(alpha: 0.18),
                    blurRadius: ZadSpacing.md,
                  ),
                ],
              ),
              child: const Icon(
                ZadIcons.store,
                size: 20,
                color: ZadColors.green700,
              ),
            ),
            const SizedBox(height: ZadSpacing.xs),
            Text(
              n.habit.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: ZadType.labelSmall.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    ),
  );
}

class _RingsPainter extends CustomPainter {
  new({
    required this.pulse,
    required this.middle,
    required this.reach,
    required this.still,
  }) : super(repaint: pulse);

  final Animation<double> pulse;
  final Offset middle;
  final double reach;
  final bool still;

  @override
  void paint(Canvas canvas, Size size) {
    if (reach <= 0) return;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = ZadColors.outlineVariant;
    for (final f in <double>[0.45, 0.72, 1]) {
      canvas.drawCircle(middle, reach * f, ring);
    }
    if (still) return;
    // A soft wave leaving home.
    canvas.drawCircle(
      middle,
      reach * pulse.value,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = ZadColors.green700.withValues(
          alpha: 0.28 * (1 - pulse.value),
        ),
    );
  }

  @override
  bool shouldRepaint(_RingsPainter old) =>
      old.reach != reach || old.middle != middle || old.still != still;
}

/// The same shops as a row of cards.
class PlaceHabitCards extends StatelessWidget {
  /// Creates the row of [habits]; [onOpen] is a tap on a shop.
  const new({required this.habits, required this.onOpen, super.key});

  /// The shops, most visited first.
  final List<PlaceHabit> habits;

  /// A shop was tapped.
  final ValueChanged<PlaceHabit> onOpen;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 144,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: habits.length,
      separatorBuilder: (_, _) => const SizedBox(width: ZadSpacing.md),
      itemBuilder: (_, i) {
        final h = habits[i];
        return SizedBox(
          width: 168,
          child: ZadCard(
            onTap: () => onOpen(h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: ZadColors.green700.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(ZadRadii.chip),
                  ),
                  child: const Icon(
                    ZadIcons.store,
                    size: 22,
                    color: ZadColors.green700,
                  ),
                ),
                const Spacer(),
                Text(
                  h.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ZadType.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  h.usualWeekday == null
                      ? context.l10n.placesHabitVisits(h.visits)
                      : context.l10n.placesHabitVisitsOn(
                          h.visits,
                          weekdayLabel(h.usualWeekday!),
                        ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
