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
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/features/intelligence/data/report_pdf.dart';
import 'package:zad/features/intelligence/domain/brain_report.dart';
import 'package:zad/shared/budget/application/budget_controller.dart';
import 'package:zad/shared/budget/application/category_budgets_controller.dart';
import 'package:zad/shared/inventory/application/pantry_controller.dart';
import 'package:zad/shared/inventory/data/consumption_learner.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/scan/domain/scanned_receipt.dart'
    show kStandardCategories;
import 'package:zad/shared/settings/application/settings_controller.dart';
import 'package:zad/shared/subscriptions/application/subscriptions_controller.dart';
import 'package:zad/shared/transactions/application/transactions_controller.dart';

/// The month's report, built on the phone from what is cached: the figures
/// and the text the PDF carries.
({BrainReport report, String text, DateTime today}) _buildReport(
  WidgetRef ref,
) {
  final zone = tz.getLocation(ref.read(accountTimeZoneProvider));
  final now = tz.TZDateTime.from(ref.read(nowProvider)().toUtc(), zone);
  final today = DateTime.utc(now.year, now.month, now.day);
  final currency = ref.read(budgetControllerProvider).snapshot?.currency ?? '';
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
    budget: ref.read(settingsControllerProvider).settings?.monthlyLimit ?? 0,
    today: today,
    local: (t) => tz.TZDateTime.from(t.toUtc(), zone),
    predictDaysLeft: learner.predictDaysLeft,
    money: money,
  );
  return (
    report: report,
    text: buildExportText(report, today: today, money: money),
    today: today,
  );
}

/// Builds the month's report, writes Kotlin's PDF and hands it to the share
/// sheet — for the family, or anyone.
Future<void> shareBrainReportPdf(WidgetRef ref) async {
  final built = _buildReport(ref);
  final file = await buildReportPdf(built.text, today: built.today);
  await SharePlus.instance.share(
    ShareParams(
      files: <XFile>[XFile(file.path, mimeType: 'application/pdf')],
      subject: 'تقرير زاد المالي',
      title: 'مشاركة تقرير زاد',
    ),
  );
}

/// The report inside the app: reading it no longer needs the share sheet
/// (owner, 2026-10-01: «لازم أعمل شير عشان يطلع تقرير»). Sharing is a
/// button on it.
Future<void> showBrainReport(BuildContext context, WidgetRef ref) {
  final built = _buildReport(ref);
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => _ReportScreen(report: built.report, text: built.text),
    ),
  );
}

class _ReportScreen extends ConsumerStatefulWidget {
  const new({required this.report, required this.text});

  final BrainReport report;
  final String text;

  @override
  ConsumerState<_ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<_ReportScreen> {
  bool _sharing = false;

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      await shareBrainReportPdf(ref);
    } on Object catch (e) {
      debugPrint('PDF share failed: $e');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final r = widget.report;
    final lines = widget.text
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('تقرير زاد الشهري')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _sharing ? null : () => unawaited(_share()),
        icon: const Icon(Icons.ios_share),
        label: const Text('شارك مع العيلة'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: <Widget>[
                  SizedBox.square(
                    dimension: 72,
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        CircularProgressIndicator(
                          value: r.healthScore / 100,
                          strokeWidth: 7,
                          backgroundColor: scheme.surfaceContainerHighest,
                        ),
                        Text('${r.healthScore}', style: ZadType.titleLarge),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text('الصحة المالية', style: ZadType.labelLarge),
                        Text(r.healthLabel, style: ZadType.titleMedium),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                line,
                style: line.trimLeft().startsWith('•')
                    ? ZadType.bodyMedium
                    : ZadType.titleSmall.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}

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
      if (mounted) await showBrainReport(context, ref);
    } on Object catch (e) {
      debugPrint('report failed: $e');
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
                  Icons.description_outlined,
                  size: 20,
                  color: scheme.onPrimaryContainer,
                ),
              const SizedBox(width: 8),
              Text(
                'التقرير الشهري',
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
