/// The coverage counter under the budget (ZAD_PLAN ٣.٤): Zad says how much of
/// the spending it is seeing, and what would let it see more.
///
/// No money app tells you how blind it is. Saying so is what makes the other
/// numbers on home believable, and turns feeding Zad into a goal.
library;

import 'package:flutter/material.dart';
import 'package:zad/core/design/components/zad_card.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/shared/budget/domain/spend_coverage.dart';

/// One line and a hint, tappable.
class CoverageNote extends StatelessWidget {
  /// Creates the note.
  const new({required this.coverage, required this.onTap, super.key});

  /// The reading.
  final SpendCoverage coverage;

  /// Opens what lets Zad see more («اقفل يومك», which links the bank too).
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (title, hint) = coverage.isBlind
        ? (context.l10n.coverageBlind, context.l10n.coverageBlindHint)
        : coverage.isFull
        ? (context.l10n.coverageFull, context.l10n.coverageFullHint)
        : (
            context.l10n.coveragePartial(coverage.label),
            context.l10n.coveragePartialHint,
          );
    return ZadCard(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Icon(
            coverage.isFull ? ZadIcons.selected : ZadIcons.bank,
            size: 20,
            color: coverage.isFull ? ZadColors.green600 : ZadColors.spentDot,
          ),
          const SizedBox(width: ZadSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: ZadType.titleSmall.copyWith(color: ZadColors.ink),
                ),
                const SizedBox(height: ZadSpacing.xs),
                Text(
                  hint,
                  style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
