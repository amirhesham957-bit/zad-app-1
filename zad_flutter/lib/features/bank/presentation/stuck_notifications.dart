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
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/data/sync/outbox_entry.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/shared/budget/application/budget_controller.dart';
import 'package:zad/shared/insights/domain/insight.dart';
import 'package:zad/shared/insights/presentation/question_card.dart';
import 'package:zad/shared/transactions/application/transactions_controller.dart';
import 'package:zad/shared/transactions/data/transactions_repository.dart';
import 'package:zad/shared/transactions/domain/transaction.dart';

class _Revision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final _revisionProvider = NotifierProvider<_Revision, int>(_Revision.new);

/// How close in time two alerts of the same bank and amount must be to count
/// as one notification delivered several times.
const Duration kStuckDuplicateWindow = Duration(minutes: 10);

String _dupKey(OutboxEntry e) {
  final parsed = e.payload['parsed'];
  final amount = parsed is Map ? (parsed['amount'] as num?) : null;
  final currency = parsed is Map ? parsed['currency'] : null;
  final title = e.payload['title'] ?? '';
  return amount == null
      ? '$title|text|${e.payload['text'] ?? ''}'
      : '$title|${amount.toDouble()}|${currency ?? ''}';
}

/// Groups the dead entries: the earliest of each run of the same bank and
/// amount within [kStuckDuplicateWindow] leads, the rest are its duplicates.
final _stuckGroupsProvider = Provider<Map<String, List<OutboxEntry>>>((ref) {
  ref.watch(_revisionProvider);
  final sorted = <OutboxEntry>[
    for (final e in ref.watch(outboxProvider).entries())
      if (e.kind == OutboxKind.notificationIngest &&
          e.state == OutboxState.dead)
        e,
  ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  final groups = <String, List<OutboxEntry>>{};
  final leaders = <String, OutboxEntry>{};
  for (final e in sorted) {
    final key = _dupKey(e);
    final lead = leaders[key];
    if (lead != null &&
        e.createdAt.difference(lead.createdAt) <= kStuckDuplicateWindow) {
      groups[lead.id]!.add(e);
    } else {
      leaders[key] = e;
      groups[e.id] = <OutboxEntry>[e];
    }
  }
  return groups;
});

/// The dead notification entries, duplicates folded into the earliest.
final stuckNotificationsProvider = Provider<List<OutboxEntry>>(
  (ref) => <OutboxEntry>[
    for (final g in ref.watch(_stuckGroupsProvider).values) g.first,
  ],
);

/// The cards, on Home among the questions.
class StuckNotificationsSlot extends ConsumerWidget {
  /// Creates the slot.
  const new({super.key});

  // Entries being recorded: a second tap must not record twice.
  static final Set<String> _busy = <String>{};

  /// Drops the entry and every duplicate folded into it.
  Future<void> _drop(WidgetRef ref, OutboxEntry e) async {
    final group = ref.read(_stuckGroupsProvider)[e.id] ?? <OutboxEntry>[e];
    for (final d in group) {
      await ref.read(outboxProvider).discard(d.id);
    }
    ref.read(_revisionProvider.notifier).bump();
  }

  Future<void> _accept(WidgetRef ref, OutboxEntry e, double amount) async {
    if (!_busy.add(e.id)) return;
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
    _busy.remove(e.id);
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
                yesLabel: context.l10n.stuckNotificationRecord,
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
