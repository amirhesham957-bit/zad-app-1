/// The statement world's «فلوسك داخلة منين وخارجة فين»: this month's money in
/// and money out by category, bars in the world's colours.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:zad/core/design/components/zad_empty_state.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/statement/domain/statement_months.dart';
import 'package:zad/shared/worlds/world_card.dart';

// Illustrative one-off colours: the worlds' own, so a category reads as the
// world it belongs to.
const Color _in = Color(0xFF0F9B76);
const List<Color> _bars = <Color>[
  Color(0xFFE5473C),
  Color(0xFF2F7BD8),
  Color(0xFF37C98E),
  Color(0xFFE08A1E),
  Color(0xFF8B5CF6),
  Color(0xFFC68216),
];

/// How many categories the card lists.
const int kBreakdownRows = 6;

/// The card.
class StatementBreakdown extends StatelessWidget {
  /// Creates the card.
  const new({required this.month, super.key});

  /// This month's money in and out.
  final MonthBreakdown month;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final rows = month.spent.take(kBreakdownRows).toList();
    if (month.income <= 0 && rows.isEmpty) {
      return ZadEmptyState(
        icon: ZadIcons.budget,
        title: l.statementWorldEmptyTitle,
        message: l.statementWorldEmptyBody,
      );
    }
    final biggest = <double>[
      month.income,
      for (final r in rows) r.$2,
    ].reduce((a, b) => a > b ? a : b);
    return ZadWorldCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l.statementWorldBreakdownTitle,
            style: ZadType.titleSmall.copyWith(color: ZadColors.ink),
          ),
          _Bar(l.statementWorldIn, month.income, biggest, _in),
          for (var i = 0; i < rows.length; i++)
            _Bar(rows[i].$1, rows[i].$2, biggest, _bars[i % _bars.length]),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const new(this.label, this.amount, this.biggest, this.color);

  final String label;
  final double amount;
  final double biggest;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: ZadSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: Text(label, style: ZadType.labelLarge)),
            Text(
              NumberFormat('#,##0', 'en').format(amount),
              style: ZadType.figure(15).copyWith(color: ZadColors.ink),
            ),
          ],
        ),
        const SizedBox(height: ZadSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(ZadRadii.pill),
          child: LinearProgressIndicator(
            value: biggest > 0 ? (amount / biggest).clamp(0.0, 1.0) : 0,
            minHeight: 10,
            color: color,
            backgroundColor: ZadColors.outlineVariant,
          ),
        ),
      ],
    ),
  );
}
