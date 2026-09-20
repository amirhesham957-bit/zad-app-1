/// Bank transactions waiting for a yes.
///
/// Nothing on this screen has touched anyone's balance yet. That is the whole
/// premise — the server reads a bank message, writes a proposal, and waits.
/// Answering here is the only thing that turns one into a transaction.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:zad/design/components/zad_card.dart';
import 'package:zad/design/components/zad_empty_state.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/proposals/application/proposals_controller.dart';
import 'package:zad/features/proposals/domain/transaction_proposal.dart';

/// The list of things to answer.
class ProposalsScreen extends ConsumerWidget {
  /// Creates the screen.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(proposalsControllerProvider);
    final controller = ref.read(proposalsControllerProvider.notifier);

    ref.listen(proposalsControllerProvider, (previous, next) {
      final outcome = next.lastOutcome;
      if (outcome == null || outcome == previous?.lastOutcome) return;
      final message = _outcomeMessage(outcome);
      if (message == null) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    });

    return DecoratedBox(
      decoration: const BoxDecoration(gradient: ZadColors.canvas),
      child: RefreshIndicator(
        onRefresh: () => controller.refresh(force: true),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            const SliverAppBar(
              title: Text('محتاجة تأكيدك'),
              floating: true,
              backgroundColor: Colors.transparent,
            ),
            if (view.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _Empty(hasError: view.error != null),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(ZadSpacing.gutter),
                sliver: SliverList.separated(
                  itemCount: view.rows.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: ZadSpacing.md),
                  itemBuilder: (_, i) => _ProposalCard(
                    proposal: view.rows[i],
                    busy: view.deciding.contains(view.rows[i].id),
                    onDecide: (d) => controller.decide(view.rows[i].id, d),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// What to say after the server settles one.
  ///
  /// `already_resolved` is called out rather than hidden: the customer may
  /// have answered from Telegram, or on another phone, and being told "that
  /// was already done" is more honest than a confirmation that implies this
  /// tap did the work.
  static String? _outcomeMessage(ProposalOutcome outcome) =>
      switch (outcome.status) {
        'posted' =>
          outcome.alreadyResolved
              ? 'كانت متسجلة بالفعل، وماتكررتش.'
              : 'تمام، اتسجلت.',
        'rejected' =>
          outcome.alreadyResolved ? 'كانت مرفوضة بالفعل.' : 'تمام، مش هتتحسب.',
        'merged' => 'اعتبرناهم عملية واحدة، ومش هتتحسب مرتين.',
        'expired' => 'الطلب ده عدت عليه أكتر من أسبوع وانتهت صلاحيته.',
        _ => null,
      };
}

/// One proposal, and the answer it is waiting for.
class _ProposalCard extends StatelessWidget {
  const new({
    required this.proposal,
    required this.busy,
    required this.onDecide,
  });

  final TransactionProposal proposal;
  final bool busy;
  final ValueChanged<ProposalDecision> onDecide;

  @override
  Widget build(BuildContext context) {
    final needsKind = proposal.status == ProposalStatus.needsClassification;

    return ZadCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      proposal.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: ZadType.titleSmall.copyWith(color: ZadColors.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitle(proposal),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ZadType.bodySmall.copyWith(
                        color: ZadColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: ZadSpacing.md),
              Text(
                _money(proposal.amount),
                style: ZadType.figure(20).copyWith(color: ZadColors.ink),
              ),
            ],
          ),
          const SizedBox(height: ZadSpacing.md),
          // Said plainly, because it is the reassurance that makes it safe to
          // leave one of these unanswered.
          Text(
            'لسه ماتحسبتش على رصيدك.',
            style: ZadType.labelSmall.copyWith(color: ZadColors.mustardOchre),
          ),
          const SizedBox(height: ZadSpacing.lg),

          if (needsKind) ...<Widget>[
            Text(
              'دي إيه بالظبط؟',
              style: ZadType.labelMedium.copyWith(color: ZadColors.inkMuted),
            ),
            const SizedBox(height: ZadSpacing.sm),
            Wrap(
              spacing: ZadSpacing.sm,
              children: <Widget>[
                _Choice(
                  label: 'مصروف',
                  busy: busy,
                  onTap: () => onDecide(ProposalDecision.expense),
                ),
                _Choice(
                  label: 'دخل',
                  busy: busy,
                  onTap: () => onDecide(ProposalDecision.income),
                ),
                _Choice(
                  label: 'تحويل',
                  busy: busy,
                  onTap: () => onDecide(ProposalDecision.transfer),
                ),
              ],
            ),
            const SizedBox(height: ZadSpacing.sm),
            _RejectButton(
              busy: busy,
              onTap: () => onDecide(ProposalDecision.reject),
            ),
          ] else
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton(
                    onPressed: busy
                        ? null
                        : () {
                            unawaited(HapticFeedback.mediumImpact());
                            onDecide(ProposalDecision.confirm);
                          },
                    child: const Text('أكد'),
                  ),
                ),
                const SizedBox(width: ZadSpacing.md),
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy
                        ? null
                        : () => onDecide(ProposalDecision.reject),
                    child: const Text('مش بتاعتي'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// Where it came from, and which way the server thinks it goes.
  static String _subtitle(TransactionProposal p) => <String>[
    if (p.source case final s? when s.isNotEmpty) s,
    switch (p.txnKind) {
      'income' => 'دخل متوقع',
      'transfer' => 'تحويل متوقع',
      'expense' => 'مصروف متوقع',
      _ => 'الاتجاه مش واضح',
    },
    DateFormat('d MMMM', 'ar').format(p.createdAt.toLocal()),
  ].join(' · ');
}

class _Choice extends StatelessWidget {
  const new({required this.label, required this.busy, required this.onTap});

  final String label;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) =>
      OutlinedButton(onPressed: busy ? null : onTap, child: Text(label));
}

class _RejectButton extends StatelessWidget {
  const new({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: busy ? null : onTap,
    child: Text(
      'مش بتاعتي',
      style: ZadType.labelMedium.copyWith(color: ZadColors.inkMuted),
    ),
  );
}

class _Empty extends StatelessWidget {
  const new({required this.hasError});

  final bool hasError;

  @override
  Widget build(BuildContext context) => ZadEmptyState(
    icon: hasError ? ZadIcons.failed : ZadIcons.synced,
    title: hasError ? 'مقدرتش أجيب الطلبات' : 'مفيش حاجة مستنية منك',
    message: hasError
        ? 'اسحب الشاشة لتحت عشان نحاول تاني.'
        : 'أول ما توصل رسالة بنك محتاجة تأكيدك، هتلاقيها هنا.',
    tone: hasError ? ZadEmptyTone.problem : ZadEmptyTone.calm,
  );
}

String _money(double amount) => NumberFormat('#,##0.##', 'en').format(amount);
