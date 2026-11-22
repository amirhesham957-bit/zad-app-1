/// ج٢.٤ — what a trip has cost so far, shown in the trip country's currency.
///
/// Pure: the server already converted every row into the account's currency
/// (`zad_normalize_transaction_currency`), so the trip figure is that total
/// carried across with the offline seed in `core/money/fx.dart`. It is an
/// estimate and is labelled so by the caller.
library;

import 'package:zad/core/money/fx.dart';
import 'package:zad/core/money/money.dart';
import 'package:zad/shared/transactions/domain/transaction.dart';

/// Spending since a trip began.
class TripSummary {
  /// Creates a summary.
  const new({
    required this.spentHome,
    required this.spentTrip,
    required this.count,
    this.budgetTrip,
  });

  /// Total spent in the account's currency.
  final double spentHome;

  /// The same total in the trip country's currency, or null when a currency
  /// is unknown (never a silent 1:1).
  final double? spentTrip;

  /// Expenses counted.
  final int count;

  /// The trip budget in the trip currency, when the customer set one.
  final double? budgetTrip;

  /// Budget left in the trip currency; negative when over. Null without both
  /// a budget and a conversion.
  double? get remainingTrip {
    final b = budgetTrip;
    final s = spentTrip;
    if (b == null || s == null) return null;
    return (b - s).asMoney;
  }

  /// Whether the budget is spent.
  bool get isOver => (remainingTrip ?? 0) < 0;
}

/// Expenses on or after [since] (transfers and non-budget rows excluded),
/// totalled in [homeCurrency] and [tripCurrency].
TripSummary summarizeTrip({
  required Iterable<ZadTransaction> rows,
  required DateTime since,
  required String homeCurrency,
  required String tripCurrency,
  double? budgetTrip,
}) {
  var total = 0.0;
  var n = 0;
  for (final t in rows) {
    if (!t.isExpense || !t.countsTowardBudget) continue;
    if (t.kind != TxnKind.expense) continue;
    if (t.createdAt.isBefore(since)) continue;
    total += t.amount;
    n++;
  }
  total = total.asMoney;
  final trip = convertCurrency(total, homeCurrency, tripCurrency);
  return TripSummary(
    spentHome: total,
    spentTrip: trip?.asMoney,
    count: n,
    budgetTrip: budgetTrip,
  );
}
