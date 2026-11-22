/// ج٢.٤ — the trip's spending in the trip country's currency, with an
/// optional budget the customer sets (kept on this device, per trip).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/components/zad_field_dialog.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/core/money/money.dart';
import 'package:zad/features/home/presentation/travel_banner.dart';
import 'package:zad/shared/market/domain/market.dart';
import 'package:zad/shared/settings/data/settings_repository.dart';
import 'package:zad/shared/transactions/application/transactions_controller.dart';
import 'package:zad/shared/trip/domain/trip_summary.dart';

/// The server's trip start (`zad_users.travel_since`), or null at home.
final tripSinceProvider = FutureProvider<DateTime?>((ref) async {
  await ref.watch(travelReportProvider.future);
  final client = ref.watch(supabaseClientProvider);
  final id = client.auth.currentUser?.id;
  if (id == null) return null;
  try {
    final row = await client
        .from('zad_users')
        .select('travel_since')
        .eq('id', id)
        .maybeSingle();
    final v = row?['travel_since'];
    return v is String ? DateTime.tryParse(v)?.toLocal() : null;
  } on Object {
    return null;
  }
});

String _budgetKey(DateTime since) =>
    'trip_budget_${since.toUtc().toIso8601String()}';

/// The card, or nothing while the customer is home.
class TripCardSlot extends ConsumerStatefulWidget {
  /// Creates the slot.
  const new({super.key});

  @override
  ConsumerState<TripCardSlot> createState() => _TripCardSlotState();
}

class _TripCardSlotState extends ConsumerState<TripCardSlot> {
  double? _budget;
  String? _loadedFor;

  Future<void> _edit(DateTime since, String currency) async {
    final l10n = context.l10n;
    final raw = await showFieldDialog<String>(
      context: context,
      initial: <String>[_budget?.toStringAsFixed(0) ?? ''],
      builder: (ctx, f) => AlertDialog(
        title: Text(l10n.tripSetBudget),
        content: TextField(
          controller: f[0],
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(hintText: l10n.tripBudgetHint(currency)),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, f[0].text),
            child: Text(l10n.tripBudgetSave),
          ),
        ],
      ),
    );
    if (raw == null) return;
    final v = parseMoneyInput(raw);
    if (v == null || v <= 0) return;
    setState(() => _budget = v);
    unawaited(ref.read(localStoreProvider).device.put(_budgetKey(since), '$v'));
  }

  @override
  Widget build(BuildContext context) {
    final country = ref.watch(serverTravelCountryProvider).value;
    final since = ref.watch(tripSinceProvider).value;
    final home = ref.watch(settingsRepositoryProvider).cached()?.currency;
    final trip = marketFor(country);
    if (country == null || since == null || home == null || trip == null) {
      return const SizedBox.shrink();
    }
    final key = _budgetKey(since);
    if (_loadedFor != key) {
      _loadedFor = key;
      _budget = double.tryParse(
        ref.read(localStoreProvider).device.get(key) ?? '',
      );
    }
    final rows = ref.watch(transactionsControllerProvider).rows;
    final s = summarizeTrip(
      rows: rows,
      since: since,
      homeCurrency: home,
      tripCurrency: trip.currency,
      budgetTrip: _budget,
    );
    if (s.spentTrip == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final left = s.remainingTrip;
    final sym = trip.currencySymbol;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _edit(since, trip.currency),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${trip.flag} ${l10n.tripTitle(trip.nameAr)}',
                style: ZadType.bodySmall.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.tripSpent(s.spentTrip!.toStringAsFixed(0), sym),
                style: ZadType.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                left == null
                    ? l10n.tripSetBudget
                    : s.isOver
                    ? l10n.tripOver((-left).toStringAsFixed(0), sym)
                    : l10n.tripLeft(left.toStringAsFixed(0), sym),
                style: ZadType.bodySmall.copyWith(
                  color: s.isOver ? scheme.error : scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
