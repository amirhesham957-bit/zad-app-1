/// Pieces of Kotlin's `BudgetScreen` the «الحركات والميزانية» tab lacked:
///
/// - the budget suggestion card — Kotlin's `recalculateBudgetSuggestion`,
///   computed on the phone from the last two completed months (no model
///   call), shown when it differs from the ceiling by 10% or more, with
///   «تطبيق» and «تجاهل» (a dismissed figure is remembered);
/// - the «الكل / المصروفات / الدخل / البنك» chips and the transactions
///   grouped by day (`TxDateHeader`, `TxRowItem` with its tap-to-reveal edit
///   and delete).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/components/zad_kotlin_surfaces.dart';
import 'package:zad/core/design/foundation/compose_shadow.dart';
import 'package:zad/core/design/tokens/zad_extended_colors.dart';
import 'package:zad/core/design/tokens/zad_palette.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/shared/budget/application/budget_controller.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/navigation/zad_screens.dart';
import 'package:zad/shared/settings/application/settings_controller.dart';
import 'package:zad/shared/subscriptions/application/subscriptions_controller.dart';
import 'package:zad/shared/transactions/application/transactions_controller.dart';
import 'package:zad/shared/transactions/data/transactions_repository.dart';
import 'package:zad/shared/transactions/domain/transaction.dart';

// Kotlin's `zad_prefs` / `dismissed_budget_suggestion`.
const String _dismissedKey = 'zad_prefs:dismissed_budget_suggestion';

String _money(double v) => NumberFormat('#,##0.##', 'en').format(v);

/// Kotlin's `recalculateBudgetSuggestion`, or null when there is nothing to
/// suggest.
final budgetSuggestionProvider = Provider<double?>((ref) {
  final rows = ref.watch(transactionsControllerProvider).rows;
  final subs = ref.watch(subscriptionsControllerProvider).items;
  final limit = ref.watch(
    settingsControllerProvider.select((v) => v.settings?.monthlyLimit ?? 0),
  );
  ref.watch(_dismissRevisionProvider);
  final zone = tz.getLocation(ref.watch(accountTimeZoneProvider));
  final now = tz.TZDateTime.from(ref.read(nowProvider)().toUtc(), zone);
  final thisMonth = now.year * 12 + now.month;

  final monthly = <int, double>{};
  for (final t in rows) {
    if (!t.isExpense) continue;
    final d = tz.TZDateTime.from(t.createdAt.toUtc(), zone);
    final ym = d.year * 12 + d.month;
    if (ym == thisMonth) continue; // the running month is not complete
    monthly[ym] = (monthly[ym] ?? 0) + t.amount;
  }
  final recent = (monthly.keys.toList()..sort((a, b) => b.compareTo(a)))
      .take(2)
      .toList();
  if (recent.isEmpty) return null;

  final recurring = subs
      .where((s) => s.isActive)
      .fold<double>(0, (sum, s) => sum + s.monthlyCost);
  final variable =
      recent
          .map((m) => (monthly[m]! - recurring).clamp(0, double.infinity))
          .reduce((a, b) => a + b) /
      recent.length;
  final rounded = ((recurring + variable) / 50).round() * 50.0;
  final diff = limit > 0 ? (rounded - limit).abs() / limit : 1.0;
  final dismissed = double.tryParse(
    ref.read(localStoreProvider).device.get(_dismissedKey) ?? '',
  );
  return diff >= 0.10 && rounded != dismissed ? rounded : null;
});

class _DismissRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final _dismissRevisionProvider = NotifierProvider<_DismissRevision, int>(
  _DismissRevision.new,
);

/// Kotlin's advisory card: needs the customer's approval.
class BudgetSuggestionCard extends ConsumerWidget {
  /// Creates the card.
  const new({required this.currency, super.key});

  /// The currency symbol.
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestion = ref.watch(budgetSuggestionProvider);
    if (suggestion == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final info = context.zadExt.info;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: info.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.insights, size: 20, color: info),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'زاد يقترح تعديل ميزانيتك إلى '
                    '${'${_money(suggestion)} $currency'.trim()} بناءً على '
                    'متوسط آخر شهرين',
                    style: ZadType.bodyMedium.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                SizedBox(
                  height: 34,
                  child: FilledButton(
                    onPressed: () async {
                      await ref
                          .read(settingsControllerProvider.notifier)
                          .setMonthlyLimit(suggestion);
                      ref.read(_dismissRevisionProvider.notifier).bump();
                      unawaited(
                        ref
                            .read(budgetControllerProvider.notifier)
                            .refresh(force: true),
                      );
                    },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 34),
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: const Text('تطبيق', style: ZadType.labelSmall),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 34,
                  child: OutlinedButton(
                    onPressed: () {
                      unawaited(
                        ref
                            .read(localStoreProvider)
                            .device
                            .put(_dismissedKey, '$suggestion'),
                      );
                      ref.read(_dismissRevisionProvider.notifier).bump();
                    },
                    style: OutlinedButton.styleFrom(
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: const Text('تجاهل', style: ZadType.labelSmall),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Kotlin's filter chips and the day-grouped transactions.
class BudgetTransactionsSection extends ConsumerStatefulWidget {
  /// Creates the section.
  const new({required this.income, required this.spent, super.key});

  /// This cycle's income, for «هذا الشهر».
  final double income;

  /// This cycle's spending.
  final double spent;

  @override
  ConsumerState<BudgetTransactionsSection> createState() => _TxSectionState();
}

class _TxSectionState extends ConsumerState<BudgetTransactionsSection> {
  String _filter = 'الكل';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final success = context.zadExt.success;
    final currency = ref.watch(
      budgetControllerProvider.select((v) => v.snapshot?.currency ?? ''),
    );
    final rows = ref.watch(transactionsControllerProvider).rows;
    final zone = tz.getLocation(ref.watch(accountTimeZoneProvider));
    final filtered = <ZadTransaction>[
      for (final t in rows)
        if (switch (_filter) {
          'المصروفات' => t.kind == TxnKind.expense,
          'الدخل' => t.kind == TxnKind.income,
          'البنك' =>
            t.sourceType == 'bank_sms' || t.sourceType == 'bank_notification',
          _ => true,
        })
          t,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final grouped = <DateTime, List<ZadTransaction>>{};
    for (final t in filtered) {
      final d = tz.TZDateTime.from(t.createdAt.toUtc(), zone);
      (grouped[DateTime.utc(d.year, d.month, d.day)] ??= <ZadTransaction>[])
          .add(t);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Wrap(
            spacing: 8,
            children: <Widget>[
              for (final f in const <String>[
                'الكل',
                'المصروفات',
                'الدخل',
                'البنك',
              ])
                FilterChip(
                  selected: _filter == f,
                  onSelected: (_) => setState(() => _filter = f),
                  label: Text(f),
                  selectedColor: scheme.primary,
                  labelStyle: TextStyle(color: scheme.onSurface),
                  shape: const StadiumBorder(),
                ),
            ],
          ),
        ),
        Text(
          'هذا الشهر',
          style: ZadType.labelMedium.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: <Widget>[
            if (widget.income > 0) ...<Widget>[
              Text(
                '+${'${_money(widget.income)} $currency'.trim()}',
                style: ZadType.bodyMedium.copyWith(
                  color: success,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (widget.spent > 0)
              Text(
                '−${'${_money(widget.spent)} $currency'.trim()}',
                style: ZadType.bodyMedium.copyWith(
                  color: scheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.all(48),
            child: KtEmptyState(
              icon: Icons.receipt_long,
              title: 'لا توجد معاملات بعد.',
              subtitle: 'أضف معاملة أو اربط البنك لتتبع مصاريفك تلقائياً',
            ),
          )
        else
          for (final MapEntry(key: day, value: list)
              in grouped.entries) ...<Widget>[
            _TxDateHeader(day: day, txList: list, zone: zone),
            for (final t in list)
              _TxRowItem(key: ValueKey<String>(t.id), tx: t, zone: zone),
          ],
      ],
    );
  }
}

/// Kotlin's `TxDateHeader`.
class _TxDateHeader extends ConsumerWidget {
  const new({required this.day, required this.txList, required this.zone});

  final DateTime day;
  final List<ZadTransaction> txList;
  final tz.Location zone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final now = tz.TZDateTime.from(ref.read(nowProvider)().toUtc(), zone);
    final today = DateTime.utc(now.year, now.month, now.day);
    final label = day == today
        ? 'اليوم'
        : day == today.subtract(const Duration(days: 1))
        ? 'أمس'
        : DateFormat('d MMMM', 'ar').format(day);
    final total = txList.fold<double>(
      0,
      (s, t) => s + (t.isExpense ? -t.amount : t.amount),
    );
    final currency = ref.watch(
      budgetControllerProvider.select((v) => v.snapshot?.currency ?? ''),
    );
    final style = ZadType.labelMedium.copyWith(fontWeight: FontWeight.w600);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label, style: style.copyWith(color: scheme.onSurfaceVariant)),
          Text(
            '${total >= 0 ? '+' : ''}${'${_money(total)} $currency'.trim()}',
            style: style.copyWith(
              color: total >= 0 ? context.zadExt.success : scheme.error,
            ),
          ),
        ],
      ),
    );
  }
}

/// Kotlin's `TxRowItem`: a tap shows edit and delete.
class _TxRowItem extends ConsumerStatefulWidget {
  const new({required this.tx, required this.zone, super.key});

  final ZadTransaction tx;
  final tz.Location zone;

  @override
  ConsumerState<_TxRowItem> createState() => _TxRowItemState();
}

class _TxRowItemState extends ConsumerState<_TxRowItem> {
  bool _actions = false;

  (IconData, Color, Color) _visual(String? category, bool expense) {
    final c = (category ?? '').toLowerCase();
    final icon = switch (c) {
      'طعام' || 'مطاعم' || 'المطاعم' => Icons.restaurant,
      'تسوق' || 'مشتريات' || 'البقالة' => Icons.shopping_cart,
      'نقل' || 'مواصلات' => Icons.directions_car,
      'صحة' || 'مستشفى' => Icons.local_hospital,
      'ترفيه' => Icons.movie,
      'الاشتراكات' || 'اشتراك' => Icons.subscriptions,
      'راتب' || 'الراتب' || 'دخل' => Icons.payments,
      'فواتير' => Icons.receipt,
      'تحويل' => Icons.swap_horiz,
      _ => expense ? Icons.remove : Icons.add,
    };
    final (bg, fg) = switch (c) {
      'طعام' || 'مطاعم' => (ZadPalette.catFoodBg, ZadPalette.catFoodIcon),
      'تسوق' || 'مشتريات' => (ZadPalette.catDailyBg, ZadPalette.catDailyIcon),
      'نقل' ||
      'مواصلات' => (ZadPalette.catTransportBg, ZadPalette.catTransportIcon),
      'الاشتراكات' ||
      'اشتراك' => (ZadPalette.catBillsBg, ZadPalette.catBillsIcon),
      'راتب' ||
      'الراتب' ||
      'دخل' => (ZadPalette.catBankingBg, ZadPalette.catBankingIcon),
      'ترفيه' => (ZadPalette.catEntertainBg, ZadPalette.catEntertainIcon),
      'صحة' => (ZadPalette.catHealthBg, ZadPalette.catHealthIcon),
      _ =>
        expense
            ? (ZadPalette.catDailyBg, ZadPalette.catDailyIcon)
            : (ZadPalette.catBankingBg, ZadPalette.catBankingIcon),
    };
    return (icon, bg, fg);
  }

  Future<void> _delete() async {
    await ref.read(transactionsRepositoryProvider).delete(widget.tx.id);
    ref.read(transactionsControllerProvider.notifier).reloadFromCache();
    ref.read(budgetControllerProvider.notifier).recomputePending();
    unawaited(
      ref.read(outboxProvider).flush().then((_) {}, onError: (Object _) {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tx = widget.tx;
    final expense = tx.isExpense;
    final (icon, bg, fg) = _visual(tx.category, expense);
    final time = DateFormat('HH:mm')
        .format(tz.TZDateTime.from(tx.createdAt.toUtc(), widget.zone));
    final currency = ref.watch(
      budgetControllerProvider.select((v) => v.snapshot?.currency ?? ''),
    );
    final shape = BorderRadius.circular(18);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: shape,
          boxShadow: composeShadow(
            elevation: 4,
            ambient: Colors.black,
            spot: fg.withValues(alpha: 0.14),
          ),
        ),
        child: Material(
          color: scheme.surface,
          borderRadius: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => setState(() => _actions = !_actions),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, size: 22, color: fg),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          tx.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ZadType.titleMedium.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Wrap(
                          spacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: <Widget>[
                            if ((tx.category ?? '').isNotEmpty)
                              Text(
                                tx.category!,
                                style: ZadType.labelSmall.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            if (tx.bankName case final bank?)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: ZadPalette.catBankingBg,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  bank,
                                  style: ZadType.labelSmall.copyWith(
                                    fontSize: 10,
                                    color: ZadPalette.catBankingIcon,
                                  ),
                                ),
                              ),
                            Text(
                              time,
                              style: ZadType.labelSmall.copyWith(
                                fontSize: 10,
                                color: scheme.onSurfaceVariant.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        '${expense ? '−' : '+'} ${_money(tx.amount)}',
                        style: ZadType.titleMedium.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: expense
                              ? scheme.error
                              : context.zadExt.success,
                        ),
                      ),
                      Text(
                        currency,
                        style: ZadType.labelSmall.copyWith(
                          fontSize: 10,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  if (_actions) ...<Widget>[
                    SizedBox.square(
                      dimension: 32,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        tooltip: 'تعديل المعاملة',
                        onPressed: () {
                          setState(() => _actions = false);
                          unawaited(
                            ZadScreens.showEditTransactionSheet(context, tx),
                          );
                        },
                        icon: Icon(
                          Icons.edit,
                          size: 18,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    SizedBox.square(
                      dimension: 32,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        tooltip: 'مسح المعاملة',
                        onPressed: () {
                          setState(() => _actions = false);
                          unawaited(_delete());
                        },
                        icon: Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: scheme.error,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
