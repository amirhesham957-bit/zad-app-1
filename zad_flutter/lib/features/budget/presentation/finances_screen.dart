/// "الميزانية والالتزامات" — Kotlin's `FinancesScreen` → `BudgetScreen`:
/// what is available, the obligations, income against spending against the
/// budget, the insight strip, category budgets with their smart analysis,
/// and the subscriptions. The transactions themselves have their own tab in
/// this client, so the screen ends with a way there rather than a second
/// copy of the list.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:zad/app/shell_navigation.dart';
import 'package:zad/core/money/money.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/design/components/zad_empty_state.dart';
import 'package:zad/design/components/zad_pressable.dart';
import 'package:zad/design/foundation/squircle.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/budget/application/budget_controller.dart';
import 'package:zad/features/budget/data/category_budgets_store.dart';
import 'package:zad/features/budget/domain/category_budgets.dart';
import 'package:zad/features/debts/presentation/debts_tab.dart';
import 'package:zad/features/home/presentation/glance_cards.dart';
import 'package:zad/features/modes/presentation/modes_cards.dart';
import 'package:zad/features/obligations/presentation/obligations_section.dart';
import 'package:zad/features/scan/domain/scanned_receipt.dart';
import 'package:zad/features/settings/application/settings_controller.dart';
import 'package:zad/features/settings/presentation/monthly_limit_sheet.dart';
import 'package:zad/features/subscriptions/presentation/subscriptions_screen.dart';
import 'package:zad/features/transactions/application/transactions_controller.dart';
import 'package:zad/features/transactions/domain/transaction.dart';
import 'package:zad/features/transactions/presentation/add_transaction_sheet.dart';

String _money(double v) => NumberFormat('#,##0.##', 'en').format(v);

/// Opens the screen.
Future<void> showFinancesScreen(BuildContext context) => Navigator.of(
  context,
).push<void>(MaterialPageRoute<void>(builder: (_) => const FinancesScreen()));

/// The ceilings on screen.
class CategoryBudgetsController extends Notifier<Map<String, double>> {
  @override
  Map<String, double> build() => ref.read(categoryBudgetsStoreProvider).read();

  /// Sets [category]'s ceiling; zero clears it.
  Future<void> set(String category, double amount) async {
    state = await ref
        .read(categoryBudgetsStoreProvider)
        .write(category, amount);
  }
}

/// The category ceilings.
final categoryBudgetsProvider =
    NotifierProvider<CategoryBudgetsController, Map<String, double>>(
      CategoryBudgetsController.new,
    );

/// The screen.
class FinancesScreen extends StatefulWidget {
  /// Creates the screen.
  const new({this.initialTab = 0, super.key});

  /// 0 الحركات والميزانية, 1 الاشتراكات والأقساط, 2 الديون.
  final int initialTab;

  @override
  State<FinancesScreen> createState() => _FinancesState();
}

/// Kotlin's `FinancesScreen`: three tabs over one title.
class _FinancesState extends State<FinancesScreen> {
  late int _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(gradient: ZadColors.canvas),
    child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('الميزانية والالتزامات')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: ZadSpacing.gutter,
              vertical: ZadSpacing.xs,
            ),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: const <ButtonSegment<int>>[
                  ButtonSegment<int>(
                    value: 0,
                    label: Text('الحركات والميزانية'),
                  ),
                  ButtonSegment<int>(
                    value: 1,
                    label: Text('الاشتراكات والأقساط'),
                  ),
                  ButtonSegment<int>(value: 2, label: Text('الديون')),
                ],
                selected: <int>{_tab},
                onSelectionChanged: (s) => setState(() => _tab = s.first),
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: const <Widget>[
                _DailyTab(),
                SubscriptionsScreen(embedded: true),
                DebtsTab(),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Kotlin's `BudgetScreen` — the «الحركات والميزانية» tab.
class _DailyTab extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budget = ref.watch(budgetControllerProvider);
    final snapshot = budget.snapshot;
    final rows = ref.watch(transactionsControllerProvider).rows;
    final ceilings = ref.watch(categoryBudgetsProvider);
    final limit = ref.watch(
      settingsControllerProvider.select((v) => v.settings?.monthlyLimit ?? 0),
    );
    final currency = snapshot?.currency ?? '';
    final spent = snapshot?.spent ?? 0;
    final income = snapshot?.income ?? 0;
    final lines = categoryLines(
      standard: kStandardCategories,
      budgets: ceilings,
      spent: spentByCategory(rows),
    );

    return DecoratedBox(
      decoration: const BoxDecoration(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'finances-add',
          onPressed: () => showAddTransactionSheet(context),
          icon: const Icon(ZadIcons.add),
          label: const Text('معاملة'),
          backgroundColor: ZadColors.forestEmerald,
          foregroundColor: Colors.white,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            ZadSpacing.gutter,
            ZadSpacing.sm,
            ZadSpacing.gutter,
            96,
          ),
          children: <Widget>[
            _Available(view: budget, currency: currency),
            const SizedBox(height: ZadSpacing.md),
            const BrokeModeSlot(offerEntry: true),
            const SizedBox(height: ZadSpacing.md),
            const SavingsChallengeSlot(offerEntry: true, offerStop: true),
            const SizedBox(height: ZadSpacing.md),
            const ObligationsSection(),
            const SizedBox(height: ZadSpacing.sm),
            _Summary(
              income: income,
              spent: spent,
              budget: limit,
              currency: currency,
            ),
            const SizedBox(height: ZadSpacing.md),
            _InsightStrip(spent: spent, budget: limit),
            const SizedBox(height: ZadSpacing.lg),
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text('ميزانيات الفئات', style: ZadType.titleMedium),
                ),
                TextButton.icon(
                  onPressed: () => unawaited(_editCategory(context, ref)),
                  icon: const Icon(ZadIcons.add, size: 16),
                  label: const Text('تحديد فئة'),
                ),
              ],
            ),
            if (lines.isEmpty)
              const ZadEmptyState(
                icon: ZadIcons.budget,
                title: 'لسه ما حددتش ميزانية لأي فئة',
                message: 'اضغط "تحديد فئة" عشان زاد يتابعلك كل فئة لوحدها.',
              )
            else
              for (final l in lines) ...<Widget>[
                _CategoryCard(
                  line: l,
                  currency: currency,
                  onEdit: () => unawaited(
                    _editCategory(context, ref, category: l.category),
                  ),
                  onInsight: () =>
                      unawaited(_showInsight(context, ref, l.category, rows)),
                ),
                const SizedBox(height: ZadSpacing.sm),
              ],
            const SizedBox(height: ZadSpacing.lg),
            const SubscriptionsGlanceCard(),
            const SizedBox(height: ZadSpacing.lg),
            _MonthTotals(income: income, spent: spent, currency: currency),
            const SizedBox(height: ZadSpacing.sm),
            OutlinedButton.icon(
              onPressed: () {
                ref
                    .read(shellNavigationProvider.notifier)
                    .open(ShellTab.transactions);
                Navigator.of(context).popUntil((r) => r.isFirst);
              },
              icon: const Icon(ZadIcons.forward, size: 18),
              label: const Text('كل المعاملات'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kotlin's solid emerald block: المتاح, the pencil, "≈" when unconfirmed,
/// and "متبقي X · محجوز Y" when something is held back.
class _Available extends StatelessWidget {
  const new({required this.view, required this.currency});

  final BudgetView view;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final available = view.spendable;
    final snapshot = view.snapshot;
    final unsure = view.isStale || view.pendingSpend > 0;
    return Container(
      padding: const EdgeInsets.all(ZadSpacing.lg + 4),
      decoration: ShapeDecoration(
        color: ZadColors.green800,
        shape: zadSquircle(ZadRadii.cardLarge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'متاح',
                  style: ZadType.labelLarge.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => showMonthlyLimitSheet(context),
                tooltip: 'تعديل الرصيد',
                icon: Icon(
                  ZadIcons.edit,
                  size: 17,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          Text(
            available == null
                ? 'لسه محددتش ميزانيتك'
                : '${unsure ? '≈ ' : ''}${_money(available)} $currency'.trim(),
            style: available == null
                ? ZadType.titleMedium.copyWith(color: Colors.white)
                : ZadType.figure(34).copyWith(
                    color: available < 0
                        ? const Color(0xFFFFA69E)
                        : Colors.white,
                  ),
          ),
          if (snapshot != null &&
              snapshot.committed > 0 &&
              snapshot.remaining != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              'متبقي ${_money(snapshot.remaining!)} · محجوز '
              '${_money(snapshot.committed)}',
              style: ZadType.labelSmall.copyWith(
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// الدخل · المصروفات · الميزانية, side by side.
class _Summary extends StatelessWidget {
  const new({
    required this.income,
    required this.spent,
    required this.budget,
    required this.currency,
  });

  final double income;
  final double spent;
  final double budget;
  final String currency;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: ZadSpacing.lg),
    decoration: ShapeDecoration(
      color: ZadColors.surface,
      shape: zadSquircle(ZadRadii.cardLarge),
    ),
    child: Row(
      children: <Widget>[
        Expanded(
          child: _SummaryItem(
            label: 'الدخل',
            amount: income,
            icon: ZadIcons.income,
            color: ZadColors.green600,
          ),
        ),
        Container(width: 1, height: 50, color: ZadColors.outlineVariant),
        Expanded(
          child: _SummaryItem(
            label: 'المصروفات',
            amount: spent,
            icon: ZadIcons.expense,
            color: ZadColors.terracottaRust,
          ),
        ),
        Container(width: 1, height: 50, color: ZadColors.outlineVariant),
        Expanded(
          child: _SummaryItem(
            label: 'الميزانية',
            amount: budget,
            icon: ZadIcons.budget,
            color: ZadColors.mustardOchre,
          ),
        ),
      ],
    ),
  );
}

class _SummaryItem extends StatelessWidget {
  const new({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
  });

  final String label;
  final double amount;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: SizedBox.square(
          dimension: 36,
          child: Icon(icon, size: 18, color: color),
        ),
      ),
      const SizedBox(height: ZadSpacing.xs),
      FittedBox(
        child: Text(
          NumberFormat('#,##0', 'en').format(amount),
          style: ZadType.titleMedium.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      Text(label, style: ZadType.labelSmall.copyWith(color: ZadColors.slate)),
    ],
  );
}

/// Kotlin's AI strip: how much of the budget is gone, and a tap to talk it
/// over with زاد.
class _InsightStrip extends ConsumerWidget {
  const new({required this.spent, required this.budget});

  final double spent;
  final double budget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insight = budgetInsight(spent: spent, budget: budget);
    final (icon, color) = switch (insight.tier) {
      3 => (ZadIcons.failed, ZadColors.terracottaRust),
      2 => (ZadIcons.failed, ZadColors.mustardOchre),
      1 => (ZadIcons.memory, ZadColors.forestEmerald),
      _ => (ZadIcons.selected, ZadColors.forestEmerald),
    };
    return ZadPressable(
      onPressed: () {
        ref.read(shellNavigationProvider.notifier).open(ShellTab.chat);
        Navigator.of(context).popUntil((r) => r.isFirst);
      },
      semanticLabel: insight.message,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: ZadSpacing.lg + 4,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(ZadRadii.card),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 22, color: color),
            const SizedBox(width: ZadSpacing.md),
            Expanded(
              child: Text(
                insight.message,
                style: ZadType.bodyMedium.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
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

class _CategoryCard extends StatelessWidget {
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
    final budget = line.budget;
    final spent = line.spent;
    final pct = budget > 0 ? spent / budget * 100 : 0;
    final over = budget > 0 && spent > budget;
    final color = budget <= 0
        ? ZadColors.inkMuted.withValues(alpha: 0.4)
        : over
        ? ZadColors.terracottaRust
        : pct >= 85
        ? ZadColors.mustardOchre
        : ZadColors.forestEmerald;
    return ZadPressable(
      onPressed: onEdit,
      semanticLabel: line.category,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ZadColors.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: color.withValues(alpha: 0.16),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
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
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        budget > 0
                            ? '${_money(spent)} / ${_money(budget)} $currency'
                            : '${_money(spent)} $currency — بدون حد',
                        style: ZadType.labelSmall.copyWith(
                          color: over
                              ? ZadColors.terracottaRust
                              : ZadColors.inkMuted,
                          fontWeight: over ? FontWeight.w700 : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: budget > 0 ? (spent / budget).clamp(0, 1) : 0,
                      minHeight: 6,
                      color: color,
                      backgroundColor: ZadColors.outlineVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onInsight,
              tooltip: 'تحليل ذكي',
              icon: Icon(
                ZadIcons.assistant,
                size: 16,
                color: ZadColors.forestEmerald,
              ),
            ),
            Icon(ZadIcons.edit, size: 16, color: ZadColors.inkMuted),
          ],
        ),
      ),
    );
  }
}

class _MonthTotals extends StatelessWidget {
  const new({
    required this.income,
    required this.spent,
    required this.currency,
  });

  final double income;
  final double spent;
  final String currency;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(
        'هذا الشهر',
        style: ZadType.labelMedium.copyWith(
          color: ZadColors.inkMuted,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: ZadSpacing.xs),
      Row(
        children: <Widget>[
          if (income > 0)
            Text(
              '+${_money(income)} $currency'.trim(),
              style: ZadType.bodyMedium.copyWith(
                color: ZadColors.green600,
                fontWeight: FontWeight.w700,
              ),
            ),
          if (income > 0 && spent > 0) const SizedBox(width: ZadSpacing.sm),
          if (spent > 0)
            Text(
              '−${_money(spent)} $currency'.trim(),
              style: ZadType.bodyMedium.copyWith(
                color: ZadColors.terracottaRust,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    ],
  );
}

/// Kotlin's `CategoryBudgetEditDialog`: a category (chosen when new) and its
/// monthly ceiling. Saving zero clears it.
Future<void> _editCategory(
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
          ? 'تحديد ميزانية فئة'
          : 'تعديل ميزانية ${widget.category}',
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (widget.category == null) ...<Widget>[
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'الفئة'),
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
          decoration: const InputDecoration(labelText: 'الميزانية الشهرية'),
        ),
      ],
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('إلغاء'),
      ),
      TextButton(
        onPressed: () =>
            Navigator.of(context)
                .pop((_category, parseMoneyInput(_amount.text) ?? 0.0)),
        child: const Text('حفظ'),
      ),
    ],
  );
}

/// Kotlin's `CategoryInsightDialog`: one `behavior_analysis` call, asked by
/// the tap, over the category's last fifteen rows.
Future<void> _showInsight(
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
      title: Text('تحليل ذكي: $category'),
      content: FutureBuilder<BehaviorAnalysis>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Row(
              children: <Widget>[
                SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Text('جاري التحليل...'),
              ],
            );
          }
          final a = snap.data;
          if (a == null || a.insight.isEmpty) {
            return const Text('مفيش بيانات كافية لتحليل الفئة دي حالياً.');
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(a.insight),
              const SizedBox(height: ZadSpacing.sm),
              Text(
                a.trendLabel,
                style: ZadType.labelMedium.copyWith(
                  color: ZadColors.forestEmerald,
                ),
              ),
              if (a.predictedNext > 0)
                Text(
                  'المتوقع الشهر القادم: ${_money(a.predictedNext)}',
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
          child: const Text('إغلاق'),
        ),
      ],
    ),
  );
}
