/// The category budgets: a header with «حدّد ميزانية», and one row per
/// category — a jar tinted by how full it is, spent against the ceiling, a
/// bar, the smart-analysis button and a tap to edit.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/design/components/zad_empty_state.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/budget/domain/category_budgets.dart';
import 'package:zad/features/budget/presentation/budget_available_card.dart';
import 'package:zad/features/budget/presentation/budget_category_dialogs.dart';
import 'package:zad/shared/transactions/domain/transaction.dart';
import 'package:zad/shared/worlds/art/art.dart';
import 'package:zad/shared/worlds/world_card.dart';

/// How a category line is doing.
enum BudgetTone {
  /// No ceiling set.
  none,

  /// Well inside its ceiling.
  calm,

  /// At 85% or more of it.
  near,

  /// Over it.
  over,
}

/// The tone of [line].
BudgetTone budgetTone(CategoryLine line) {
  final budget = line.budget;
  if (budget <= 0) return BudgetTone.none;
  if (line.spent > budget) return BudgetTone.over;
  return line.spent / budget * 100 >= 85 ? BudgetTone.near : BudgetTone.calm;
}

/// The app colour for [tone].
Color budgetToneColor(BudgetTone tone) => switch (tone) {
  BudgetTone.none => ZadColors.inkMuted.withValues(alpha: 0.4),
  BudgetTone.calm => ZadColors.forestEmerald,
  BudgetTone.near => ZadColors.mustardOchre,
  BudgetTone.over => ZadColors.terracottaRust,
};

/// The section.
class BudgetCategories extends ConsumerWidget {
  /// Creates the section.
  const new({
    required this.lines,
    required this.currency,
    required this.rows,
    super.key,
  });

  /// The categories with a ceiling or some spending.
  final List<CategoryLine> lines;

  /// The currency symbol.
  final String currency;

  /// The period's transactions, for the analysis.
  final List<ZadTransaction> rows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                l.financesCategoryBudgets,
                style: ZadType.titleMedium,
              ),
            ),
            TextButton.icon(
              onPressed: () => unawaited(editBudgetCategory(context, ref)),
              icon: const Icon(ZadIcons.add, size: 16),
              label: Text(l.financesSetCategory),
              style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
            ),
          ],
        ),
        const SizedBox(height: ZadSpacing.xs),
        if (lines.isEmpty)
          ZadEmptyState(
            icon: ZadIcons.budget,
            title: l.financesNoCategories,
            message: l.financesSetCategory,
          )
        else
          ZadWorldCard(
            child: Column(
              children: <Widget>[
                for (var i = 0; i < lines.length; i++) ...<Widget>[
                  if (i > 0) const Divider(height: ZadSpacing.lg),
                  _Row(
                    line: lines[i],
                    currency: currency,
                    onEdit: () => unawaited(
                      editBudgetCategory(
                        context,
                        ref,
                        category: lines[i].category,
                      ),
                    ),
                    onInsight: () => unawaited(
                      showCategoryInsight(
                        context,
                        ref,
                        lines[i].category,
                        rows,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const new({
    required this.line,
    required this.currency,
    required this.onEdit,
    required this.onInsight,
  });

  final CategoryLine line;
  final String currency;
  final VoidCallback onEdit;
  final VoidCallback onInsight;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final budget = line.budget;
    final spent = line.spent;
    final over = budget > 0 && spent > budget;
    final color = budgetToneColor(budgetTone(line));
    return Semantics(
      button: true,
      label: line.category,
      child: InkWell(
        onTap: onEdit,
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(ZadRadii.chip),
              ),
              child: ZadArt.icon(ZadIconArt.jar, size: 28),
            ),
            const SizedBox(width: ZadSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          line.category,
                          style: ZadType.labelLarge.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        budget > 0
                            ? '${budgetMoney(spent)} / '
                                  '${budgetMoney(budget)} $currency'
                            : l.financesNoLimit(
                                '${budgetMoney(spent)} $currency',
                              ),
                        style: ZadType.labelSmall.copyWith(
                          color: over
                              ? ZadColors.terracottaRust
                              : ZadColors.inkMuted,
                          fontWeight: over ? FontWeight.w700 : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: ZadSpacing.xs + 2),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(ZadRadii.pill),
                    child: LinearProgressIndicator(
                      value: budget > 0 ? (spent / budget).clamp(0, 1) : 0,
                      minHeight: 8,
                      color: color,
                      backgroundColor: ZadColors.outlineVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onInsight,
              tooltip: l.financesSmartAnalysis,
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              icon: Icon(
                ZadIcons.assistant,
                size: 20,
                color: ZadColors.forestEmerald,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
