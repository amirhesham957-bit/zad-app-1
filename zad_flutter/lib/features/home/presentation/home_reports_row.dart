/// The two reports under the wallet card: the month's PDF («تصدير التقرير
/// الشهري», the brain screen's export) and the strategic dossier («التقرير
/// الاستراتيجي», Kotlin's `ZadExecutiveDossierSheet`). Neither calls a model —
/// both are computed on the phone from what is already cached.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/intelligence/presentation/executive_dossier_sheet.dart';
import 'package:zad/features/intelligence/presentation/export_report_button.dart'
    show shareBrainReportPdf;

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
      await shareBrainReportPdf(ref);
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
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      foregroundColor: ZadColors.green700,
      backgroundColor: ZadColors.mint50,
      minimumSize: const Size.fromHeight(48),
      padding: const EdgeInsets.symmetric(horizontal: ZadSpacing.md),
      side: BorderSide(color: ZadColors.green600.withValues(alpha: 0.3)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ZadRadii.card),
      ),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (busy)
          const SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          Icon(icon, size: 18),
        const SizedBox(width: ZadSpacing.sm),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ZadType.labelLarge.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );
}
