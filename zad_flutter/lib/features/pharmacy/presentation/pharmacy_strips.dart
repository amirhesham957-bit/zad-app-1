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
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/pharmacy/presentation/pharmacy_logic.dart';
import 'package:zad/shared/pharmacy/domain/dose_slot.dart';

/// The colour a dose's state is read by.
Color doseStateColor(DoseState state) => switch (state) {
  DoseState.taken => ZadColors.green600,
  DoseState.due => ZadColors.mustardOchre,
  DoseState.missed => ZadColors.terracottaRust,
  DoseState.upcoming => ZadWorldColors.pharmacy,
};

const Color _violet2 = Color(0xFF6B5FC7);

/// What a screen reader says for a dose's state.
String doseStateWords(ZadL10n l, DoseState state) => switch (state) {
  DoseState.taken => l.phDoseTaken,
  DoseState.due => l.phDoseDue,
  DoseState.missed => l.phDoseMissed,
  DoseState.upcoming => l.phDoseUpcoming,
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
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Wrap(
      spacing: ZadSpacing.md,
      runSpacing: ZadSpacing.sm,
      children: <Widget>[
        for (final s in slots)
          Semantics(
            label: '${doseClock(s, zone)} ${doseStateWords(l, _state(s))}',
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
}

class _Pill extends StatelessWidget {
  const new({required this.state});

  final DoseState state;

  @override
  Widget build(BuildContext context) {
    final c = doseStateColor(state);
    final taken = state == DoseState.taken;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Taken is the strong violet of the preview's dose tile.
        gradient: taken
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[_violet2, ZadWorldColors.pharmacy],
              )
            : null,
        color: switch (state) {
          DoseState.missed => c,
          DoseState.taken => null,
          _ => Colors.white,
        },
        border: Border.all(
          color: c,
          width: state == DoseState.upcoming ? 2 : 3,
        ),
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
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFFECEDF2), Color(0xFFD6D8E0)],
          ),
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
                          gradient: i < lit
                              ? const RadialGradient(
                                  center: Alignment(-0.3, -0.4),
                                  colors: <Color>[
                                    Colors.white,
                                    Color(0xFFC9C6EC),
                                    Color(0xFFA9A4DB),
                                  ],
                                  stops: <double>[0, 0.7, 1],
                                )
                              : null,
                          color: i < lit ? null : const Color(0xFFB3B5BE),
                          boxShadow: i < lit
                              ? const <BoxShadow>[
                                  BoxShadow(
                                    color: Color(0x404A3F94),
                                    blurRadius: 3,
                                    offset: Offset(0, 2),
                                  ),
                                ]
                              : null,
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
