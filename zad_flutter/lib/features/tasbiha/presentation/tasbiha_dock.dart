/// The counting dock: a big bead in the bottom thumb zone, ringed by the
/// progress of the chosen cycle, with the reset and the cycle choice beside
/// it. One tap is one count.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_motion.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/design/tokens/zad_world_colors.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/shared/worlds/art/art.dart';

/// The cycle lengths the ring can count to.
const List<int> kTasbihaCycles = <int>[33, 100];

/// Height of the dock's own content (the safe area comes on top).
const double kTasbihaDockHeight = 176;

/// The dock.
class TasbihaDock extends StatefulWidget {
  /// Creates the dock.
  const new({
    required this.score,
    required this.cycle,
    required this.message,
    required this.onTap,
    required this.onReset,
    required this.onCycle,
    super.key,
  });

  /// The tree's count.
  final int score;

  /// The cycle the ring counts to.
  final int cycle;

  /// A short line above the bead (a flower bloomed, seeds earned), or null.
  final String? message;

  /// One count.
  final VoidCallback onTap;

  /// Back to zero.
  final VoidCallback onReset;

  /// A cycle length was chosen.
  final ValueChanged<int> onCycle;

  @override
  State<TasbihaDock> createState() => _TasbihaDockState();
}

class _TasbihaDockState extends State<TasbihaDock> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final inset = MediaQuery.viewPaddingOf(context).bottom;
    final fraction = widget.cycle <= 0
        ? 0.0
        : (widget.score % widget.cycle) / widget.cycle;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: ZadColors.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(ZadRadii.sheet),
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: ZadColors.shadowSpot,
              blurRadius: 16,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            ZadSpacing.gutter,
            ZadSpacing.sm,
            ZadSpacing.gutter,
            ZadSpacing.sm + inset,
          ),
          child: SizedBox(
            height: kTasbihaDockHeight - 2 * ZadSpacing.sm,
            child: Column(
              children: <Widget>[
                SizedBox(
                  height: 24,
                  child: AnimatedSwitcher(
                    duration: still ? Duration.zero : ZadDuration.enter,
                    child: widget.message == null
                        ? const SizedBox.shrink(key: ValueKey<String>('none'))
                        : Text(
                            widget.message!,
                            key: ValueKey<String>(widget.message!),
                            style: ZadType.labelMedium.copyWith(
                              color: ZadWorldColors.tasbih,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Expanded(
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(44, 44),
                              foregroundColor: ZadColors.terracottaRust,
                            ),
                            onPressed: widget.onReset,
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: Text(l.tasReset),
                          ),
                        ),
                      ),
                      _bead(l, still, fraction),
                      Expanded(
                        child: Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                l.tasCycle,
                                style: ZadType.labelSmall.copyWith(
                                  color: ZadColors.inkMuted,
                                ),
                              ),
                              const SizedBox(height: ZadSpacing.xs),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  for (final c in kTasbihaCycles)
                                    _CycleChip(
                                      label: '$c',
                                      selected: widget.cycle == c,
                                      onTap: () => widget.onCycle(c),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bead(ZadL10n l, bool still, double fraction) => Semantics(
    button: true,
    label: l.tasTapLabel,
    child: GestureDetector(
      key: const ValueKey<String>('tasbiha-bead'),
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down && !still ? 0.93 : 1,
        duration: still ? Duration.zero : ZadDuration.press,
        curve: ZadCurves.press,
        child: SizedBox.square(
          dimension: 124,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              TweenAnimationBuilder<double>(
                tween: Tween<double>(end: fraction),
                duration: still ? Duration.zero : ZadDuration.enter,
                curve: Curves.fastOutSlowIn,
                builder: (context, v, _) => CustomPaint(
                  size: const Size.square(124),
                  painter: _RingPainter(v),
                ),
              ),
              DecoratedBox(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: ZadWorldColors.tasbih,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Color(0x3345BF68),
                      blurRadius: 14,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: SizedBox.square(
                  dimension: 96,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      ZadArt.icon(ZadIconArt.beads, size: 34),
                      Text(
                        '${widget.score}',
                        style: ZadType.titleLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _CycleChip extends StatelessWidget {
  const new({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2),
    child: Material(
      color: selected ? ZadWorldColors.tasbih : ZadColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ZadRadii.chip),
        side: BorderSide(
          color: selected
              ? ZadWorldColors.tasbih
              : ZadColors.outline.withValues(alpha: 0.4),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          child: Center(
            widthFactor: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: ZadSpacing.sm),
              child: Text(
                label,
                style: ZadType.labelMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : ZadColors.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _RingPainter extends CustomPainter {
  const new(this.value);

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    const w = 8.0;
    final rect = (Offset.zero & size).deflate(w / 2);
    canvas
      ..drawArc(
        rect,
        0,
        2 * math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w
          ..color = ZadWorldColors.tasbih.withValues(alpha: 0.18),
      )
      ..drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * value,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w
          ..strokeCap = StrokeCap.round
          ..color = ZadWorldColors.tasbih,
      );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value;
}
