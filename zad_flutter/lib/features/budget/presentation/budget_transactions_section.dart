/// The month's movements under the budget: Kotlin's four filter chips,
/// «هذا الشهر» with its income and spending, and the transactions grouped by
/// day (each day's header carries its net), every row with its tap-to-reveal
/// edit and delete.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/components/zad_empty_state.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/budget/presentation/budget_available_card.dart';
import 'package:zad/shared/budget/application/budget_controller.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/transactions/application/transactions_controller.dart';
import 'package:zad/shared/transactions/domain/transaction.dart';
import 'package:zad/shared/transactions/presentation/transaction_row.dart';
import 'package:zad/shared/worlds/world_card.dart';

/// The section.
class BudgetTransactionsSection extends ConsumerStatefulWidget {
  /// Creates the section.
  const new({required this.income, required this.spent, super.key});

  /// This cycle's income, for «هذا الشهر».
  final double income;

  /// This cycle's spending.
  final double spent;

  @override
  ConsumerState<BudgetTransactionsSection> createState() => _SectionState();
}

enum _Filter {
  all,
  expenses,
  income,
  bank;

  String label(ZadL10n l) => switch (this) {
    _Filter.all => l.txFilterAll,
    _Filter.expenses => l.txFilterExpenses,
    _Filter.income => l.txFilterIncome,
    _Filter.bank => l.txFilterBank,
  };

  bool keeps(ZadTransaction t) => switch (this) {
    _Filter.expenses => t.kind == TxnKind.expense,
    _Filter.income => t.kind == TxnKind.income,
    _Filter.bank =>
      t.sourceType == 'bank_sms' || t.sourceType == 'bank_notification',
    _Filter.all => true,
  };
}

class _SectionState extends ConsumerState<BudgetTransactionsSection> {
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final currency = ref.watch(
      budgetControllerProvider.select((v) => v.snapshot?.currency ?? ''),
    );
    final rows = ref.watch(transactionsControllerProvider).rows;
    final zone = tz.getLocation(ref.watch(accountTimeZoneProvider));
    final filtered = rows.where(_filter.keeps).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final grouped = <DateTime, List<ZadTransaction>>{};
    for (final t in filtered) {
      final d = tz.TZDateTime.from(t.createdAt.toUtc(), zone);
      (grouped[DateTime.utc(d.year, d.month, d.day)] ??= <ZadTransaction>[])
          .add(t);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          spacing: ZadSpacing.sm,
          children: <Widget>[
            for (final f in _Filter.values)
              ChoiceChip(
                selected: _filter == f,
                onSelected: (_) => setState(() => _filter = f),
                label: Text(f.label(l)),
                showCheckmark: false,
                shape: const StadiumBorder(),
              ),
          ],
        ),
        const SizedBox(height: ZadSpacing.md),
        Text(
          l.budgetThisMonth,
          style: ZadType.labelMedium.copyWith(color: ZadColors.inkMuted),
        ),
        const SizedBox(height: ZadSpacing.xs),
        Row(
          children: <Widget>[
            if (widget.income > 0) ...<Widget>[
              Text(
                '+${'${budgetMoney(widget.income)} $currency'.trim()}',
                textDirection: TextDirection.ltr,
                style: ZadType.bodyMedium.copyWith(
                  color: ZadColors.green600,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: ZadSpacing.sm),
            ],
            if (widget.spent > 0)
              Text(
                '−${'${budgetMoney(widget.spent)} $currency'.trim()}',
                textDirection: TextDirection.ltr,
                style: ZadType.bodyMedium.copyWith(
                  color: ZadColors.terracottaRust,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
        const SizedBox(height: ZadSpacing.sm),
        if (filtered.isEmpty)
          ZadEmptyState(
            icon: ZadIcons.budget,
            title: l.budgetNoTransactions,
            message: l.budgetNoTransactionsHint,
          )
        else
          for (final MapEntry(key: day, value: list)
              in grouped.entries) ...<Widget>[
            _DayHeader(day: day, rows: list, zone: zone, currency: currency),
            ZadWorldCard(
              child: Column(
                children: <Widget>[
                  for (var i = 0; i < list.length; i++) ...<Widget>[
                    if (i > 0) const Divider(height: 1),
                    TransactionRow(
                      key: ValueKey<String>(list[i].id),
                      txn: list[i],
                      time: DateFormat('HH:mm').format(
                        tz.TZDateTime.from(list[i].createdAt.toUtc(), zone),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
      ],
    );
  }
}

/// Kotlin's `TxDateHeader`: the day, and what it netted.
class _DayHeader extends ConsumerWidget {
  const new({
    required this.day,
    required this.rows,
    required this.zone,
    required this.currency,
  });

  final DateTime day;
  final List<ZadTransaction> rows;
  final tz.Location zone;
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = tz.TZDateTime.from(ref.read(nowProvider)().toUtc(), zone);
    final today = DateTime.utc(now.year, now.month, now.day);
    final label = day == today
        ? context.l10n.dayToday
        : day == today.subtract(const Duration(days: 1))
        ? context.l10n.dayYesterday
        : DateFormat('d MMMM', context.dateLocale).format(day);
    final total = rows.fold<double>(
      0,
      (s, t) => s + (t.isExpense ? -t.amount : t.amount),
    );
    final style = ZadType.labelMedium.copyWith(fontWeight: FontWeight.w700);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, ZadSpacing.md, 0, ZadSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label, style: style.copyWith(color: ZadColors.inkMuted)),
          Text(
            '${total >= 0 ? '+' : ''}'
            '${'${budgetMoney(total)} $currency'.trim()}',
            textDirection: TextDirection.ltr,
            style: style.copyWith(
              color: total >= 0 ? ZadColors.green600 : ZadColors.terracottaRust,
            ),
          ),
        ],
      ),
    );
  }
}
