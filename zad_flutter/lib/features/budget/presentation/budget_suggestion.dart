/// The budget suggestion — Kotlin's `recalculateBudgetSuggestion`, computed
/// on the phone from the last two completed months (no model call), shown
/// when it differs from the ceiling by 10% or more, with «تطبيق» and «تجاهل»
/// (a dismissed figure is remembered).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/design/tokens/zad_world_colors.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/shared/budget/application/budget_controller.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/settings/application/settings_controller.dart';
import 'package:zad/shared/subscriptions/application/subscriptions_controller.dart';
import 'package:zad/shared/transactions/application/transactions_controller.dart';
import 'package:zad/shared/worlds/art/art.dart';
import 'package:zad/shared/worlds/world_card.dart';

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
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: ZadSpacing.md),
      child: ZadWorldCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                ZadArt.icon(ZadIconArt.chart, size: 28),
                const SizedBox(width: ZadSpacing.md),
                Expanded(
                  child: Text(
                    l.budgetSuggest('${_money(suggestion)} $currency'.trim()),
                    style: ZadType.bodyMedium.copyWith(
                      color: ZadColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: ZadSpacing.md),
            Row(
              children: <Widget>[
                FilledButton(
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
                    minimumSize: const Size(0, 44),
                    backgroundColor: ZadWorldColors.budget,
                    shape: const StadiumBorder(),
                  ),
                  child: Text(l.commonApply),
                ),
                const SizedBox(width: ZadSpacing.md),
                OutlinedButton(
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
                    minimumSize: const Size(0, 44),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(l.commonDismiss),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
