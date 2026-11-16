/// The «الحركات والميزانية» tab as a world («الميزانية»): a jar per category
/// filled to what was spent, a coin dropping in when a transaction lands,
/// and under it the money — what is available, the month's totals, reports,
/// the insight, obligations, category ceilings, the ways out of a tight
/// month and the month's movements.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:zad/core/design/components/zad_scroll_away.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/budget/domain/category_budgets.dart';
import 'package:zad/features/budget/presentation/budget_available_card.dart';
import 'package:zad/features/budget/presentation/budget_categories.dart';
import 'package:zad/features/budget/presentation/budget_suggestion.dart';
import 'package:zad/features/budget/presentation/budget_transactions_section.dart';
import 'package:zad/features/budget/presentation/budget_world_scene.dart';
import 'package:zad/shared/budget/application/budget_controller.dart';
import 'package:zad/shared/budget/application/category_budgets_controller.dart';
import 'package:zad/shared/navigation/zad_screens.dart';
import 'package:zad/shared/navigation/zad_slots.dart';
import 'package:zad/shared/orb/domain/companion_state.dart';
import 'package:zad/shared/scan/domain/scanned_receipt.dart';
import 'package:zad/shared/settings/application/settings_controller.dart';
import 'package:zad/shared/transactions/application/transactions_controller.dart';
import 'package:zad/shared/worlds/world_scaffold.dart';
import 'package:zad/shared/worlds/zad_world.dart';

/// The budget world. [showBack] is null to follow the route; the finances
/// screen, which has its own back button over the tabs, passes false.
class BudgetWorld extends ConsumerStatefulWidget {
  /// Creates the world.
  const new({this.showBack, super.key});

  /// Whether to show the world's own back button.
  final bool? showBack;

  @override
  ConsumerState<BudgetWorld> createState() => _BudgetWorldState();
}

class _BudgetWorldState extends ConsumerState<BudgetWorld>
    with SingleTickerProviderStateMixin {
  /// Runs once per arriving transaction; the first jar reads it.
  late final AnimationController _coin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void dispose() {
    _coin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final budget = ref.watch(budgetControllerProvider);
    final snapshot = budget.snapshot;
    final rows = ref.watch(transactionsControllerProvider).rows;
    final ceilings = ref.watch(categoryBudgetsProvider);
    final limit = ref.watch(
      settingsControllerProvider.select((v) => v.settings?.monthlyLimit ?? 0),
    );
    ref.listen<int>(
      transactionsControllerProvider.select((v) => v.rows.length),
      (before, after) {
        final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
        if (before != null && after > before && !still) {
          _coin.forward(from: 0);
        }
      },
    );
    final currency = snapshot?.currency ?? '';
    final spent = snapshot?.spent ?? 0;
    final income = snapshot?.income ?? 0;
    final lines = categoryLines(
      standard: kStandardCategories,
      budgets: ceilings,
      spent: spentByCategory(rows),
    );
    final jars = <BudgetJar>[
      for (final line in lines.take(kBudgetJars))
        (
          fill: line.budget > 0
              ? line.spent / line.budget
              : (spent > 0 ? line.spent / spent : 0),
          color: switch (budgetTone(line)) {
            BudgetTone.over => const Color(0xFFE5473C),
            BudgetTone.near => const Color(0xFFF2B91E),
            BudgetTone.calm => const Color(0xFF37C98E),
            BudgetTone.none => const Color(0xFFB9C0C7),
          },
        ),
    ];
    final tight =
        (budget.spendable ?? 0) < 0 ||
        lines.any((x) => x.budget > 0 && x.spent > x.budget);

    final available = budget.spendable;
    final perDay = available == null || snapshot == null
        ? 0.0
        : available / math.max(1, snapshot.daysLeft);
    String money(double v) =>
        '${NumberFormat('#,##0', 'en').format(v)} $currency'.trim();

    return ZadScrollAwayScope(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: ZadWorldScaffold(
          world: ZadWorld.budget,
          showBack: widget.showBack,
          eyebrow: switch (snapshot) {
            null => null,
            final s when s.cycleEnd != null => l.budgetWorldUntil(
              s.cycleEnd!.day,
            ),
            final s => l.budgetWorldDaysLeft(s.daysLeft),
          },
          title: l.worldLabelBudget,
          stateLine: available == null
              ? l.financesNoBudget
              : perDay > 0
              ? l.budgetWorldState(money(available), money(perDay))
              : l.budgetWorldAvailable(money(available)),
          scene: (loop) => BudgetWorldScene(loop, _coin, jars),
          zado: ZadWorldZado(
            left: 16,
            top: 50,
            size: 140,
            state: tight ? CompanionState.alert : CompanionState.happy,
          ),
          // The two ways in sit under the list, in the thumb zone.
          dockHeight: 80,
          overlay: PositionedDirectional(
            end: ZadSpacing.lg,
            bottom: ZadSpacing.md,
            child: ZadStepsAside(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  FloatingActionButton.small(
                    heroTag: 'finances-scan',
                    onPressed: () =>
                        unawaited(ZadScreens.openZadCamera(context)),
                    tooltip: l.txScanReceipt,
                    backgroundColor: ZadColors.surface,
                    foregroundColor: ZadColors.green800,
                    child: const Icon(ZadIcons.scan),
                  ),
                  const SizedBox(width: ZadSpacing.md),
                  FloatingActionButton.extended(
                    heroTag: 'finances-add',
                    onPressed: () =>
                        ZadScreens.showAddTransactionSheet(context),
                    icon: const Icon(ZadIcons.add),
                    label: Text(l.financesAddTx),
                    backgroundColor: ZadColors.green800,
                    foregroundColor: Colors.white,
                  ),
                ],
              ),
            ),
          ),
          slivers: <Widget>[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                ZadSpacing.gutter,
                ZadSpacing.md,
                ZadSpacing.gutter,
                0,
              ),
              sliver: SliverList.list(
                children: <Widget>[
                  BudgetAvailableCard(view: budget, currency: currency),
                  const SizedBox(height: ZadSpacing.md),
                  BudgetSummaryCard(
                    income: income,
                    spent: spent,
                    budget: limit,
                  ),
                  const SizedBox(height: ZadSpacing.md),
                  // The month's PDF and the dossier live here (ZAD_PLAN
                  // ١٠.٨): reports belong beside the money they cover.
                  if (snapshot != null) ...<Widget>[
                    ZadSlots.homeReportsRow(
                      spent: spent,
                      spendable: budget.spendable,
                      daysLeft: math.max(1, snapshot.daysLeft),
                      currency: currency,
                    ),
                    const SizedBox(height: ZadSpacing.md),
                  ],
                  BudgetInsightCard(spent: spent, budget: limit),
                  BudgetSuggestionCard(currency: currency),
                  const SizedBox(height: ZadSpacing.md),
                  ZadSlots.obligationsSection(),
                  const SizedBox(height: ZadSpacing.lg),
                  BudgetCategories(
                    lines: lines,
                    currency: currency,
                    rows: rows,
                  ),
                  const SizedBox(height: ZadSpacing.md),
                  // The ways out of a tight month, after the money they act
                  // on.
                  ZadSlots.brokeModeSlot(offerEntry: true),
                  const SizedBox(height: ZadSpacing.md),
                  ZadSlots.savingsChallengeSlot(
                    offerEntry: true,
                    offerStop: true,
                  ),
                  const SizedBox(height: ZadSpacing.lg),
                  BudgetTransactionsSection(income: income, spent: spent),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
