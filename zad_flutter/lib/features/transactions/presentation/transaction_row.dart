/// One transaction in the world's list: its drawing, what and where, the
/// source it came from (drawn icon + line), the amount, and — after a tap —
/// edit and delete.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/design/tokens/zad_world_colors.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/transactions/presentation/edit_transaction_sheet.dart';
import 'package:zad/features/transactions/presentation/transaction_source.dart';
import 'package:zad/shared/transactions/domain/transaction.dart';
import 'package:zad/shared/worlds/art/art.dart';

// l10n: data-begin
// Words that mean fuel, matched against a title or category the customer
// (or a bank message) wrote.
const List<String> _fuelWords = <String>['بنزين', 'وقود', 'fuel', 'petrol'];
// l10n: data-end

/// The drawing of a transaction: a coin for money in, arrows for a
/// transfer, a pump for fuel, else the item's own product or a tinted carton.
Widget transactionArt(ZadTransaction t, {required double size}) {
  if (t.kind == TxnKind.income) {
    return ZadArt.icon(ZadIconArt.coin, size: size);
  }
  if (t.kind == TxnKind.transfer) {
    return ZadArt.icon(ZadIconArt.repeat, size: size);
  }
  final text = '${t.title} ${t.category ?? ''}'.toLowerCase();
  if (_fuelWords.any(text.contains)) {
    return ZadArt.icon(ZadIconArt.fuel, size: size);
  }
  return zadItemArt(t.title, size: size, category: t.category);
}

/// A transaction's amount the way the list prints it.
String transactionMoney(double amount) =>
    NumberFormat('#,##0.##', 'en').format(amount);

/// The row. A tap shows its edit and delete buttons, a second hides them.
class TransactionRow extends ConsumerStatefulWidget {
  /// Creates the row.
  const new({required this.txn, super.key});

  /// The transaction.
  final ZadTransaction txn;

  @override
  ConsumerState<TransactionRow> createState() => _TransactionRowState();
}

class _TransactionRowState extends ConsumerState<TransactionRow> {
  bool _actions = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final txn = widget.txn;
    final source = TxSource.of(txn);
    final tint = zadCategoryTint(txn.category);
    final sign = txn.kind == TxnKind.income
        ? '+'
        : txn.kind == TxnKind.expense
        ? '−'
        : '';
    return InkWell(
      onTap: () => setState(() => _actions = !_actions),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: ZadSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(ZadRadii.chip),
                  ),
                  child: transactionArt(txn, size: 30),
                ),
                const SizedBox(width: ZadSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        txn.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ZadType.titleSmall.copyWith(
                          color: ZadColors.ink,
                        ),
                      ),
                      Text(
                        _subtitle(txn, l),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ZadType.bodySmall.copyWith(
                          color: ZadColors.inkMuted,
                        ),
                      ),
                      const SizedBox(height: ZadSpacing.xs),
                      Row(
                        children: <Widget>[
                          ZadArt.icon(source.art, size: 16),
                          const SizedBox(width: ZadSpacing.xs),
                          Flexible(
                            child: Text(
                              source.label(l, bank: txn.bankName),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ZadType.labelSmall.copyWith(
                                color: ZadWorldColors.transactions,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: ZadSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      '$sign${transactionMoney(txn.amount)}',
                      textDirection: TextDirection.ltr,
                      style: ZadType.figure(17).copyWith(
                        // Income is the exception worth colouring: colouring
                        // every expense red would make an ordinary month look
                        // like an emergency.
                        color: txn.kind == TxnKind.income
                            ? ZadColors.green600
                            : ZadColors.ink,
                      ),
                    ),
                    if (txn.isPending) ...<Widget>[
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            ZadIcons.pending,
                            size: 11,
                            color: ZadColors.mustardOchre,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            l.txPendingOne,
                            style: ZadType.labelSmall.copyWith(
                              color: ZadColors.mustardOchre,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),
            if (_actions)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  IconButton(
                    onPressed: () {
                      setState(() => _actions = false);
                      unawaited(showEditTransactionSheet(context, txn));
                    },
                    tooltip: l.commonEdit,
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    icon: const Icon(ZadIcons.edit, size: 20),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() => _actions = false);
                      unawaited(confirmDeleteTransaction(context, ref, txn));
                    },
                    tooltip: l.commonDelete,
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    icon: Icon(
                      ZadIcons.delete,
                      size: 20,
                      color: ZadColors.terracottaRust,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// Category, wallet, the merchant when a bank message named one, and who in
  /// the house it was for. The category stays in Arabic: it is written to the
  /// column and matched against, not read from a translation table.
  static String _subtitle(ZadTransaction txn, ZadL10n l10n) => <String>[
    if (txn.category case final c? when c.isNotEmpty) c,
    switch (txn.wallet) {
      Wallet.cash => l10n.walletCash,
      Wallet.card => l10n.walletCard,
      Wallet.bank => l10n.walletBank,
    },
    if (txn.merchantName case final m? when m.isNotEmpty) m,
    if (txn.forPerson case final p? when p.isNotEmpty) l10n.txForPersonTag(p),
  ].join(' · ');
}
