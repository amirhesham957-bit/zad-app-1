/// The top of the budget world's body: what is available (with the pencil
/// that edits the balance), income against spending against the budget, and
/// the one-line read of the month that opens a chat with Zad.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:zad/core/design/components/zad_pressable.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/design/tokens/zad_world_colors.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/budget/domain/category_budgets.dart';
import 'package:zad/shared/budget/application/budget_controller.dart';
import 'package:zad/shared/navigation/shell_navigation.dart';
import 'package:zad/shared/navigation/zad_screens.dart';
import 'package:zad/shared/worlds/art/art.dart';
import 'package:zad/shared/worlds/world_card.dart';

/// A figure as the budget prints it.
String budgetMoney(double v) => NumberFormat('#,##0.##', 'en').format(v);

/// المتاح: the pencil, "≈" when unconfirmed, and "متبقي X · محجوز Y" when
/// something is held back.
class BudgetAvailableCard extends StatelessWidget {
  /// Creates the card.
  const new({required this.view, required this.currency, super.key});

  /// The budget.
  final BudgetView view;

  /// The currency symbol.
  final String currency;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final available = view.spendable;
    final snapshot = view.snapshot;
    final unsure = view.isStale || view.pendingSpend > 0;
    return ZadWorldCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              ZadArt.icon(ZadIconArt.coin, size: 24),
              const SizedBox(width: ZadSpacing.sm),
              Expanded(
                child: Text(
                  l.financesAvailable,
                  style: ZadType.labelLarge.copyWith(color: ZadColors.inkMuted),
                ),
              ),
              IconButton(
                onPressed: () => ZadScreens.showMonthlyLimitSheet(context),
                tooltip: l.financesEditBalance,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                icon: Icon(ZadIcons.edit, size: 20, color: ZadColors.inkMuted),
              ),
            ],
          ),
          if (available == null)
            Text(
              l.financesNoBudget,
              style: ZadType.titleMedium.copyWith(color: ZadColors.ink),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: <Widget>[
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${unsure ? '≈ ' : ''}${budgetMoney(available)}',
                      style: ZadType.figure(34).copyWith(
                        color: available < 0
                            ? ZadColors.terracottaRust
                            : ZadColors.ink,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: ZadSpacing.sm),
                // The currency is Arabic text; the figures face has no
                // Arabic glyphs.
                Text(
                  currency,
                  style: ZadType.titleMedium.copyWith(
                    color: ZadColors.inkMuted,
                  ),
                ),
              ],
            ),
          if (snapshot != null &&
              snapshot.committed > 0 &&
              snapshot.remaining != null) ...<Widget>[
            const SizedBox(height: ZadSpacing.xs),
            Text(
              l.financesRemainingCommitted(
                budgetMoney(snapshot.remaining!),
                budgetMoney(snapshot.committed),
              ),
              style: ZadType.labelMedium.copyWith(color: ZadColors.inkMuted),
            ),
          ],
        ],
      ),
    );
  }
}

/// الدخل · المصروفات · الميزانية, side by side, over how much of the budget
/// the spending has used.
class BudgetSummaryCard extends StatelessWidget {
  /// Creates the card.
  const new({
    required this.income,
    required this.spent,
    required this.budget,
    super.key,
  });

  /// Received this cycle.
  final double income;

  /// Spent this cycle.
  final double spent;

  /// The monthly limit.
  final double budget;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final used = budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0.0;
    return ZadWorldCard(
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              _Item(l.txFilterIncome, income, ZadIconArt.coin),
              _Item(l.txFilterExpenses, spent, ZadIconArt.cart),
              _Item(l.sectionBudget, budget, ZadIconArt.jar),
            ],
          ),
          if (budget > 0) ...<Widget>[
            const SizedBox(height: ZadSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(ZadRadii.pill),
              child: LinearProgressIndicator(
                value: used,
                minHeight: 10,
                color: spent > budget
                    ? ZadColors.terracottaRust
                    : ZadWorldColors.budget,
                backgroundColor: ZadColors.outlineVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const new(this.label, this.amount, this.art);

  final String label;
  final double amount;
  final ZadIconArt art;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: <Widget>[
        ZadArt.icon(art, size: 28),
        const SizedBox(height: ZadSpacing.xs),
        FittedBox(
          child: Text(
            NumberFormat('#,##0', 'en').format(amount),
            style: ZadType.titleMedium.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        Text(label, style: ZadType.labelSmall.copyWith(color: ZadColors.slate)),
      ],
    ),
  );
}

/// How much of the budget is gone, and a tap to talk it over with زاد.
class BudgetInsightCard extends ConsumerWidget {
  /// Creates the card.
  const new({required this.spent, required this.budget, super.key});

  /// Spent this cycle.
  final double spent;

  /// The monthly limit.
  final double budget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insight = budgetInsight(
      spent: spent,
      budget: budget,
      l10n: context.l10n,
    );
    final color = switch (insight.tier) {
      3 => ZadColors.terracottaRust,
      2 => ZadColors.mustardOchre,
      _ => ZadColors.forestEmerald,
    };
    return ZadPressable(
      onPressed: () {
        ref.read(shellNavigationProvider.notifier).open(ShellTab.chat);
        Navigator.of(context).popUntil((r) => r.isFirst);
      },
      semanticLabel: insight.message,
      child: ZadWorldCard(
        child: Row(
          children: <Widget>[
            ZadArt.icon(
              insight.tier >= 2 ? ZadIconArt.bell : ZadIconArt.brain,
              size: 28,
            ),
            const SizedBox(width: ZadSpacing.md),
            Expanded(
              child: Text(
                insight.message,
                style: ZadType.bodyMedium.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(ZadIcons.forward, size: 20, color: color),
          ],
        ),
      ),
    );
  }
}
