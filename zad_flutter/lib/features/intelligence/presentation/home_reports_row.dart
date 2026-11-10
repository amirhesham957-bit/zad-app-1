/// The two reports under the wallet card: the month's PDF («تصدير التقرير
/// الشهري», the brain screen's export) and the strategic dossier («التقرير
/// الاستراتيجي», Kotlin's `ZadExecutiveDossierSheet`). Neither calls a model —
/// both are computed on the phone from what is already cached.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/design/components/zad_card.dart';
import 'package:zad/core/design/components/zad_icon_chip.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/features/intelligence/presentation/executive_dossier_sheet.dart';
import 'package:zad/features/intelligence/presentation/export_report_button.dart'
    show showBrainReport;

/// The row.
class HomeReportsRow extends ConsumerStatefulWidget {
  /// Creates the row.
  const new({
    required this.spent,
    required this.spendable,
    required this.daysLeft,
    required this.currency,
    super.key,
  });

  /// Spent in the cycle, as the wallet card shows it.
  final double spent;

  /// What can be spent; null without a budget.
  final double? spendable;

  /// Days left in the cycle.
  final int daysLeft;

  /// The account's currency.
  final String currency;

  @override
  ConsumerState<HomeReportsRow> createState() => _HomeReportsRowState();
}

class _HomeReportsRowState extends ConsumerState<HomeReportsRow> {
  bool _exporting = false;

  Future<void> _exportMonthly() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      await showBrainReport(context, ref);
    } on Object catch (e) {
      debugPrint('PDF export failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('مقدرتش أجهّز التقرير دلوقتي')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _openDossier() => unawaited(
    showExecutiveDossierSheet(
      context,
      executiveDossierOf(
        ref,
        spent: widget.spent,
        spendable: widget.spendable,
        daysLeft: widget.daysLeft,
        currency: widget.currency,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Expanded(
        child: _ReportButton(
          label: 'تصدير التقرير الشهري',
          icon: Icons.ios_share,
          busy: _exporting,
          onTap: () => unawaited(_exportMonthly()),
        ),
      ),
      const SizedBox(width: ZadSpacing.md),
      Expanded(
        child: _ReportButton(
          label: 'التقرير الاستراتيجي',
          icon: Icons.workspace_premium_outlined,
          onTap: _openDossier,
        ),
      ),
    ],
  );
}

class _ReportButton extends StatelessWidget {
  const new({
    required this.label,
    required this.icon,
    required this.onTap,
    this.busy = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) => ZadCard(
    onTap: busy ? null : onTap,
    padding: const EdgeInsets.symmetric(
      horizontal: ZadSpacing.md,
      vertical: ZadSpacing.sm,
    ),
    child: Row(
      children: <Widget>[
        if (busy)
          const SizedBox.square(
            dimension: 32,
            child: Padding(
              padding: EdgeInsets.all(ZadSpacing.sm),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          ZadIconChip(icon: icon, tint: ZadColors.green700, size: 32),
        const SizedBox(width: ZadSpacing.sm),
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: ZadType.labelLarge.copyWith(color: ZadColors.ink),
          ),
        ),
      ],
    ),
  );
}
