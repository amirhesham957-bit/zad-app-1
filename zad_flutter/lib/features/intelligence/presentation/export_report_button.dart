/// Kotlin's `ExportReportButton`: «تصدير التقرير الشهري» on the brain
/// screen — builds the month's report on the phone, writes Kotlin's PDF, and
/// hands it to the share sheet as «تقرير زاد المالي».
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:share_plus/share_plus.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/core/period/account_time_zone.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/budget/application/budget_controller.dart';
import 'package:zad/features/budget/presentation/finances_screen.dart'
    show categoryBudgetsProvider;
import 'package:zad/features/intelligence/data/report_pdf.dart';
import 'package:zad/features/intelligence/domain/brain_report.dart';
import 'package:zad/features/inventory/application/pantry_controller.dart';
import 'package:zad/features/inventory/data/consumption_learner.dart';
import 'package:zad/features/scan/domain/scanned_receipt.dart'
    show kStandardCategories;
import 'package:zad/features/settings/application/settings_controller.dart';
import 'package:zad/features/subscriptions/application/subscriptions_controller.dart';
import 'package:zad/features/transactions/application/transactions_controller.dart';

/// The button.
class ExportReportButton extends ConsumerStatefulWidget {
  /// Creates the button.
  const new({super.key});

  @override
  ConsumerState<ExportReportButton> createState() => _ExportState();
}

class _ExportState extends ConsumerState<ExportReportButton> {
  bool _building = false;

  Future<void> _export() async {
    if (_building) return;
    setState(() => _building = true);
    try {
      final zone = tz.getLocation(ref.read(accountTimeZoneProvider));
      final now = tz.TZDateTime.from(ref.read(nowProvider)().toUtc(), zone);
      final today = DateTime.utc(now.year, now.month, now.day);
      final currency =
          ref.read(budgetControllerProvider).snapshot?.currency ?? '';
      String money(double v) =>
          '${NumberFormat('#,##0.##', 'en').format(v)} $currency'.trim();
      final learner = ref.read(consumptionLearnerProvider);
      final report = buildBrainReport(
        transactions: ref.read(transactionsControllerProvider).rows,
        subscriptions: ref.read(subscriptionsControllerProvider).items,
        pantryNames: <String>[
          for (final i in ref.read(pantryControllerProvider).items) i.itemName,
        ],
        categoryBudgets: ref.read(categoryBudgetsProvider),
        standardCategories: kStandardCategories,
        budget:
            ref.read(settingsControllerProvider).settings?.monthlyLimit ?? 0,
        today: today,
        local: (t) => tz.TZDateTime.from(t.toUtc(), zone),
        predictDaysLeft: learner.predictDaysLeft,
        money: money,
      );
      final file = await buildReportPdf(
        buildExportText(report, today: today, money: money),
        today: today,
      );
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(file.path, mimeType: 'application/pdf')],
          subject: 'تقرير زاد المالي',
          title: 'مشاركة تقرير زاد',
        ),
      );
    } on Object catch (e) {
      debugPrint('PDF export failed: $e');
    } finally {
      if (mounted) setState(() => _building = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primaryContainer,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => unawaited(_export()),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (_building)
                SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: scheme.onPrimaryContainer,
                  ),
                )
              else
                Icon(
                  Icons.ios_share,
                  size: 20,
                  color: scheme.onPrimaryContainer,
                ),
              const SizedBox(width: 8),
              Text(
                'تصدير التقرير الشهري',
                style: ZadType.titleSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
