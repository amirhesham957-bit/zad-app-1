/// The two pill strips on a medicine's card: today's doses (taken, due, missed,
/// still to come) and the stock — one lit pill per unit left, as the
/// blister pack shows it.
library;

import 'package:flutter/material.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/design/tokens/zad_world_colors.dart';
import 'package:zad/features/pharmacy/presentation/pharmacy_logic.dart';
import 'package:zad/shared/pharmacy/domain/dose_slot.dart';

/// The colour a dose's state is read by.
Color doseStateColor(DoseState state) => switch (state) {
  DoseState.taken => ZadColors.green600,
  DoseState.due => ZadColors.mustardOchre,
  DoseState.missed => ZadColors.terracottaRust,
  DoseState.upcoming => ZadWorldColors.pharmacy,
};

/// What a screen reader says for a dose's state.
String doseStateWords(DoseState state) => switch (state) {
  DoseState.taken => 'اتاخدت',
  DoseState.due => 'وقتها دلوقتي',
  DoseState.missed => 'فاتت',
  DoseState.upcoming => 'جاية',
};

/// One pill per dose slot of the medicine today, with its clock beneath.
class TodayPillStrip extends StatelessWidget {
  /// Creates the strip.
  const new({
    required this.slots,
    required this.now,
    required this.zone,
    this.knowsPast = true,
    super.key,
  });

  /// Whether a dose that has passed untaken is known to be missed. False
  /// for a family member's strip: their dose records are not readable here,
  /// so a passed dose is not claimed as missed.
  final bool knowsPast;

  /// The medicine's slots, in order.
  final List<DoseSlot> slots;

  /// The present moment.
  final DateTime now;

  /// The account's zone.
  final String zone;

  DoseState _state(DoseSlot s) {
    final state = s.stateAt(now);
    return !knowsPast && (state == DoseState.missed || state == DoseState.due)
        ? DoseState.upcoming
        : state;
  }

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: ZadSpacing.md,
    runSpacing: ZadSpacing.sm,
    children: <Widget>[
      for (final s in slots)
        Semantics(
          label: '${doseClock(s, zone)} ${doseStateWords(_state(s))}',
          excludeSemantics: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _Pill(state: _state(s)),
              const SizedBox(height: ZadSpacing.xs),
              Text(
                doseClock(s, zone),
                style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
              ),
            ],
          ),
        ),
    ],
  );
}

class _Pill extends StatelessWidget {
  const new({required this.state});

  final DoseState state;

  @override
  Widget build(BuildContext context) {
    final c = doseStateColor(state);
    final filled = state == DoseState.taken || state == DoseState.missed;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? c : c.withValues(alpha: 0.12),
        border: Border.all(color: c, width: state == DoseState.due ? 3 : 1.5),
      ),
      child: SizedBox.square(
        dimension: 28,
        child: switch (state) {
          DoseState.taken => const Icon(
            ZadIcons.selected,
            size: 16,
            color: Colors.white,
          ),
          DoseState.missed => const Icon(
            Icons.close_rounded,
            size: 16,
            color: Colors.white,
          ),
          _ => null,
        },
      ),
    );
  }
}

/// The stock as a blister strip: a lit pill per unit left (at most [cap]),
/// the rest drawn as popped cells.
class StockStrip extends StatelessWidget {
  /// Creates the strip.
  const new({required this.remaining, this.cap = 10, super.key});

  /// Units left.
  final int remaining;

  /// How many cells the strip has.
  final int cap;

  @override
  Widget build(BuildContext context) {
    final lit = remaining.clamp(0, cap);
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFECEDF2),
          borderRadius: BorderRadius.circular(ZadRadii.chip),
        ),
        child: Padding(
          padding: const EdgeInsets.all(ZadSpacing.sm),
          child: Row(
            children: <Widget>[
              for (var i = 0; i < cap; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < lit
                              ? ZadWorldColors.pharmacy.withValues(alpha: 0.28)
                              : const Color(0xFFB3B5BE),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
