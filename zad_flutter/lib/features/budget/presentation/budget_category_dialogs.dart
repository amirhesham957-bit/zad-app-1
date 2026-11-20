/// The two dialogs behind a category's budget row: its monthly ceiling
/// (Kotlin's `CategoryBudgetEditDialog`) and the smart analysis asked by a
/// tap (`CategoryInsightDialog`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/core/money/money.dart';
import 'package:zad/shared/budget/application/category_budgets_controller.dart';
import 'package:zad/shared/budget/data/category_budgets_store.dart';
import 'package:zad/shared/scan/domain/scanned_receipt.dart';
import 'package:zad/shared/transactions/domain/transaction.dart';

String _money(double v) => NumberFormat('#,##0.##', 'en').format(v);

/// Kotlin's `CategoryBudgetEditDialog`: a category (chosen when new) and its
/// monthly ceiling. Saving zero clears it.
Future<void> editBudgetCategory(
  BuildContext context,
  WidgetRef ref, {
  String? category,
}) async {
  final result = await showDialog<(String, double)>(
    context: context,
    builder: (_) => _CategoryDialog(
      category: category,
      current: category == null
          ? 0
          : ref.read(categoryBudgetsProvider)[category] ?? 0,
    ),
  );
  if (result == null) return;
  await ref.read(categoryBudgetsProvider.notifier).set(result.$1, result.$2);
}

class _CategoryDialog extends StatefulWidget {
  const new({required this.category, required this.current});

  final String? category;
  final double current;

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late String _category = widget.category ?? kStandardCategories.first;
  late final TextEditingController _amount = TextEditingController(
    text: widget.current > 0 ? widget.current.toStringAsFixed(0) : '',
  );

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.category == null
          ? context.l10n.financesSetCategoryBudget
          : context.l10n.financesEditCategoryBudget(widget.category!),
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (widget.category == null) ...<Widget>[
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: InputDecoration(
              labelText: context.l10n.financesCategory,
            ),
            items: <DropdownMenuItem<String>>[
              for (final c in kStandardCategories)
                DropdownMenuItem<String>(value: c, child: Text(c)),
            ],
            onChanged: (c) => setState(() => _category = c ?? _category),
          ),
          const SizedBox(height: ZadSpacing.md),
        ],
        TextField(
          controller: _amount,
          keyboardType: TextInputType.number,
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(
            labelText: context.l10n.financesMonthlyBudget,
          ),
        ),
      ],
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(context.l10n.commonCancel),
      ),
      TextButton(
        onPressed: () =>
            Navigator.of(context)
                .pop((_category, parseMoneyInput(_amount.text) ?? 0.0)),
        child: Text(context.l10n.commonSave),
      ),
    ],
  );
}

/// Kotlin's `CategoryInsightDialog`: one `behavior_analysis` call, asked by
/// the tap, over the category's last fifteen rows.
Future<void> showCategoryInsight(
  BuildContext context,
  WidgetRef ref,
  String category,
  List<ZadTransaction> rows,
) async {
  final userId = ref.read(signedInUserIdProvider)();
  if (userId == null) return;
  final text = rows
      .where((t) => t.category == category)
      .take(15)
      .map((t) => '${t.title}:${t.amount}')
      .join(', ');
  final future = ref
      .read(behaviorAnalysisRemoteProvider)
      .analyze(userId: userId, category: category, transactions: text);
  await showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(c.l10n.financesInsightTitle(category)),
      content: FutureBuilder<BehaviorAnalysis>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return Row(
              children: <Widget>[
                const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Text(context.l10n.financesAnalysing),
              ],
            );
          }
          final a = snap.data;
          if (a == null || a.insight.isEmpty) {
            return Text(context.l10n.financesInsightEmpty);
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(a.insight),
              const SizedBox(height: ZadSpacing.sm),
              Text(
                a.trendLabel(context.l10n),
                style: ZadType.labelMedium.copyWith(
                  color: ZadColors.forestEmerald,
                ),
              ),
              if (a.predictedNext > 0)
                Text(
                  context.l10n.financesPredictedNext(_money(a.predictedNext)),
                  style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
                ),
              if (a.tip.isNotEmpty) ...<Widget>[
                const SizedBox(height: ZadSpacing.sm),
                Text(a.tip, style: ZadType.bodySmall),
              ],
            ],
          );
        },
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(c).pop(),
          child: Text(c.l10n.commonClose),
        ),
      ],
    ),
  );
}
