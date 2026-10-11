/// The bank's record of the payment a receipt is for.
///
/// A card purchase reaches the app twice: the bank's notification (an expense
/// with `source_type = notification_listener`) and, later, the receipt
/// photographed for its lines. Saved as two expenses, it is counted twice —
/// the reason the owner held back automatic recording until this closed
/// (2026-10-10).
library;

import 'package:zad/shared/transactions/domain/transaction.dart';

/// `zad_transactions.source_type` of an expense the bank channel recorded.
const String kBankSourceType = 'notification_listener';

/// How far a receipt's printed date may sit from the bank's time. A receipt
/// carries a day, not a time, and is often read the next morning.
const Duration kBankTwinWindow = Duration(hours: 36);

/// The bank expense [total] at [spentAt] most likely is, or null.
///
/// Same amount to the piaster, an expense, from the bank channel, inside
/// [kBankTwinWindow]; the closest in time when several fit. A cash receipt
/// has no bank twin.
ZadTransaction? bankTwinOf({
  required double total,
  required DateTime spentAt,
  required Iterable<ZadTransaction> rows,
  Wallet? paidWith,
}) {
  if (total <= 0 || paidWith == Wallet.cash) return null;
  ZadTransaction? best;
  Duration? bestGap;
  for (final t in rows) {
    if (t.sourceType != kBankSourceType || !t.isExpense) continue;
    if ((t.amount - total).abs() >= 0.005) continue;
    final gap = t.createdAt.difference(spentAt).abs();
    if (gap > kBankTwinWindow) continue;
    if (bestGap == null || gap < bestGap) {
      best = t;
      bestGap = gap;
    }
  }
  return best;
}
