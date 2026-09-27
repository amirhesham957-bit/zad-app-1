/// Kotlin's `localExhaustedInsights`: a bank notification that ran out of
/// delivery attempts becomes a question on Home instead of vanishing —
/// «إشعار ما وصلش لزاد». With an amount read from it the card asks
/// «أسجّله؟» (yes/no); without one it only reports it.
///
/// «أيوة» records it through the ordinary manual path and drops the dead
/// entry; «لأ» or dismissing drops it. Kotlin's bank parser also knows the
/// direction; the phone here reads the amount only, so it is recorded as an
/// expense — what a bank alert that failed delivery almost always is.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/data/sync/outbox_entry.dart';
import 'package:zad/features/budget/application/budget_controller.dart';
import 'package:zad/features/insights/domain/insight.dart';
import 'package:zad/features/insights/presentation/insight_cards.dart';
import 'package:zad/features/transactions/application/transactions_controller.dart';
import 'package:zad/features/transactions/domain/transaction.dart';

class _Revision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final _revisionProvider = NotifierProvider<_Revision, int>(_Revision.new);

/// The dead notification entries.
final stuckNotificationsProvider = Provider<List<OutboxEntry>>((ref) {
  ref.watch(_revisionProvider);
  return <OutboxEntry>[
    for (final e in ref.watch(outboxProvider).entries())
      if (e.kind == OutboxKind.notificationIngest &&
          e.state == OutboxState.dead)
        e,
  ];
});

/// The cards, on Home among the questions.
class StuckNotificationsSlot extends ConsumerWidget {
  /// Creates the slot.
  const new({super.key});

  Future<void> _drop(WidgetRef ref, OutboxEntry e) async {
    await ref.read(outboxProvider).discard(e.id);
    ref.read(_revisionProvider.notifier).bump();
  }

  Future<void> _accept(WidgetRef ref, OutboxEntry e, double amount) async {
    final userId = ref.read(signedInUserIdProvider)();
    if (userId != null) {
      final title = (e.payload['title'] as String?)?.trim();
      await ref
          .read(transactionsRepositoryProvider)
          .record(
            (id) => ZadTransaction.expense(
              id: id,
              userId: userId,
              amount: amount,
              title: title == null || title.isEmpty ? 'مصروف' : title,
              createdAt: ref.read(nowProvider)(),
              wallet: Wallet.card,
            ),
          );
      ref.read(transactionsControllerProvider.notifier).reloadFromCache();
      ref.read(budgetControllerProvider.notifier).recomputePending();
    }
    await _drop(ref, e);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stuck = ref.watch(stuckNotificationsProvider);
    if (stuck.isEmpty) return const SizedBox.shrink();
    return Column(
      children: <Widget>[
        for (final e in stuck)
          () {
            final parsed = e.payload['parsed'];
            final amount = parsed is Map
                ? (parsed['amount'] as num?)?.toDouble()
                : null;
            final currency = parsed is Map
                ? parsed['currency'] as String?
                : null;
            final title = (e.payload['title'] as String?) ?? '';
            final amountText = amount == null
                ? null
                : '${amount.toStringAsFixed(amount % 1 == 0 ? 0 : 2)} '
                          '${currency ?? ''}'
                      .trim();
            final insight = ZadInsight(
              id: 'local_outbox_${e.id}',
              title: 'إشعار ما وصلش لزاد',
              body: amountText != null
                  ? 'وصل إشعار بمبلغ $amountText ($title) بس ما قدرناش '
                        'نوصّله. أسجّله؟'
                  : 'وصل إشعار ($title) وما قدرناش نقرا مبلغ منه. راجعه '
                        'وضيفه يدوي لو معاملة.',
              kind: 'question',
              actionType: amountText != null ? 'yes_no' : null,
              aboutItem: (e.payload['text'] as String?)?.characters
                  .take(200)
                  .toString(),
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ZadQuestionCard(
                insight: insight,
                onAnswer: (answer) => unawaited(
                  answer == 'أيوة' && amount != null
                      ? _accept(ref, e, amount)
                      : _drop(ref, e),
                ),
                onDismiss: () => unawaited(_drop(ref, e)),
              ),
            );
          }(),
      ],
    );
  }
}
