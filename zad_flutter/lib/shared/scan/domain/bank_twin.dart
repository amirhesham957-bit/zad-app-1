/// The bank's record of the payment a receipt is for.
///
/// A card purchase reaches the app twice: the bank's notification (an expense
/// with `source_type = notification_listener`) and, later, the receipt
/// photographed for its lines. Saved as two expenses, it is counted twice —
/// the reason the owner held back automatic recording until this closed
/// (2026-10-10).
library;

import 'package:zad/shared/proposals/domain/transaction_proposal.dart';
import 'package:zad/shared/transactions/domain/transaction.dart';

/// `zad_transactions.source_type` of an expense the bank channel recorded.
const String kBankSourceType = 'notification_listener';

/// How far a receipt's printed date may sit from the bank's time. A receipt
/// carries a day, not a time, and is often read the next morning.
const Duration kBankTwinWindow = Duration(hours: 24);

/// How far the bank's amount may differ from the receipt's, as a share of the
/// receipt's total. The bank sometimes differs by a few piasters.
const double kBankTwinTolerance = 0.02;

/// Bank kinds that are not a card payment a receipt is for.
const Set<String> _ignoredKinds = <String>{
  'transfer',
  'cash_withdrawal',
  'income',
};

/// What a receipt matched: a recorded bank expense or a pending notification.
class BankMatch {
  /// Exactly one of [transaction] and [proposal] is set.
  const new({this.transaction, this.proposal});

  /// The recorded expense, when that is what matched.
  final ZadTransaction? transaction;

  /// The pending proposal, when that is what matched.
  final TransactionProposal? proposal;

  /// The bank's amount.
  double get amount => transaction?.amount ?? proposal!.amount;

  /// The shop the bank named, or its own title.
  String get merchant {
    final t = transaction;
    if (t != null) {
      final m = t.merchantName;
      return (m == null || m.trim().isEmpty) ? t.title : m;
    }
    final p = proposal!;
    final m = p.merchantName;
    return (m == null || m.trim().isEmpty) ? p.title : m;
  }

  /// When the bank's message came.
  DateTime get at => transaction?.createdAt ?? proposal!.createdAt;
}

bool _amountFits(double bank, double total) =>
    (bank - total).abs() <=
    (total * kBankTwinTolerance > 0.01 ? total * kBankTwinTolerance : 0.01) +
        1e-9;

/// The bank record [total] at [spentAt] most likely is, or null.
///
/// Looks at recorded bank expenses ([rows]) and pending bank notifications
/// ([proposals]): within [kBankTwinTolerance] of the amount and inside
/// [kBankTwinWindow]. The closest in time wins; on equal gaps the exact
/// amount. Transfers, cash withdrawals and income are ignored, and a cash
/// receipt has no bank match.
BankMatch? bankMatchOf({
  required double total,
  required DateTime spentAt,
  required Iterable<ZadTransaction> rows,
  Iterable<TransactionProposal> proposals = const <TransactionProposal>[],
  Wallet? paidWith,
}) {
  if (total <= 0 || paidWith == Wallet.cash) return null;
  BankMatch? best;
  Duration? bestGap;
  double bestDiff = 0;

  void consider(BankMatch m) {
    if (!_amountFits(m.amount, total)) return;
    final gap = m.at.difference(spentAt).abs();
    if (gap > kBankTwinWindow) return;
    final diff = (m.amount - total).abs();
    if (bestGap == null ||
        gap < bestGap! ||
        (gap == bestGap && diff < bestDiff)) {
      best = m;
      bestGap = gap;
      bestDiff = diff;
    }
  }

  for (final t in rows) {
    // A transfer (an ATM withdrawal moved to cash) keeps is_expense true in the
    // table, but it is not the card payment a receipt is for.
    if (t.sourceType != kBankSourceType ||
        !t.isExpense ||
        t.kind == TxnKind.transfer) {
      continue;
    }
    consider(BankMatch(transaction: t));
  }
  for (final p in proposals) {
    if (!p.isOpen || _ignoredKinds.contains(p.txnKind)) continue;
    consider(BankMatch(proposal: p));
  }
  return best;
}

/// The recorded bank expense [total] at [spentAt] most likely is, or null.
ZadTransaction? bankTwinOf({
  required double total,
  required DateTime spentAt,
  required Iterable<ZadTransaction> rows,
  Wallet? paidWith,
}) => bankMatchOf(
  total: total,
  spentAt: spentAt,
  rows: rows,
  paidWith: paidWith,
)?.transaction;
