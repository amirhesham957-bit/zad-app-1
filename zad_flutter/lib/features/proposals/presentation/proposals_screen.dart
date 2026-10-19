/// Bank transactions waiting for a yes.
///
/// Nothing on this screen has touched anyone's balance yet. That is the whole
/// premise — the server reads a bank message, writes a proposal, and waits.
/// Answering here is the only thing that turns one into a transaction.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/components/zad_empty_state.dart';
import 'package:zad/core/design/foundation/compose_shadow.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/features/proposals/application/proposal_snooze.dart';
import 'package:zad/shared/companion/domain/pet_meal.dart';
import 'package:zad/shared/market/domain/market.dart';
import 'package:zad/shared/proposals/application/proposals_controller.dart';
import 'package:zad/shared/proposals/domain/transaction_proposal.dart';
import 'package:zad/shared/settings/data/settings_repository.dart';

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
      decoration: BoxDecoration(gradient: ZadColors.canvas),
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
                  itemBuilder: (_, i) => ProposalCard(
                    proposal: view.rows[i],
                    busy: view.deciding.contains(view.rows[i].id),
                    failed: view.failed.contains(view.rows[i].id),
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

/// Kotlin's block on الرئيسية: «عمليات بنكية بانتظارك» over the waiting
/// proposals, spaced 10dp — nothing at all while none is waiting.
class HomeProposalsSection extends ConsumerWidget {
  /// Creates the section.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(proposalsControllerProvider);
    // Swiped left: off home for a few hours, still on the proposals screen.
    final snooze = ref.watch(proposalSnoozeProvider);
    final now = ref.read(nowProvider)();
    final rows = <TransactionProposal>[
      for (final p in view.rows)
        if (!(snooze[p.id]?.isAfter(now) ?? false)) p,
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    final controller = ref.read(proposalsControllerProvider.notifier);

    ref.listen(proposalsControllerProvider, (previous, next) {
      final outcome = next.lastOutcome;
      if (outcome == null || outcome == previous?.lastOutcome) return;
      final message = ProposalsScreen._outcomeMessage(outcome);
      if (message == null) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    });

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'عمليات بنكية بانتظارك',
              style: ZadType.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          for (var i = 0; i < rows.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: 10),
            _FeedThePet(
              proposal: rows[i],
              busy: view.deciding.contains(rows[i].id),
              onConfirm: () =>
                  controller.decide(rows[i].id, ProposalDecision.confirm),
              child: SwipeableProposal(
                proposal: rows[i],
                busy: view.deciding.contains(rows[i].id),
                onConfirm: () =>
                    controller.decide(rows[i].id, ProposalDecision.confirm),
                onPostpone: () => ref
                    .read(proposalSnoozeProvider.notifier)
                    .snooze(rows[i].id),
                child: ProposalCard(
                  proposal: rows[i],
                  busy: view.deciding.contains(rows[i].id),
                  failed: view.failed.contains(rows[i].id),
                  onDecide: (d) => controller.decide(rows[i].id, d),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A home proposal card that can be dragged onto رفيق زاد (ZAD_PLAN ٥.٣):
/// held, it lifts as a small chip; dropped on the pet it is confirmed — the
/// card's own «تأكيد» — and the pet eats. Only where a swipe could confirm.
class _FeedThePet extends StatelessWidget {
  const new({
    required this.proposal,
    required this.busy,
    required this.onConfirm,
    required this.child,
  });

  final TransactionProposal proposal;
  final bool busy;
  final VoidCallback onConfirm;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (busy || !SwipeableProposal.canConfirm(proposal)) return child;
    final label = proposal.merchantName ?? proposal.bankName ?? 'مصروف';
    return LongPressDraggable<PetMeal>(
      data: PetMeal(label: label, log: onConfirm),
      onDragStarted: () => unawaited(HapticFeedback.mediumImpact()),
      feedback: Material(
        key: const ValueKey<String>('pet-meal-chip'),
        color: ZadColors.forestEmerald,
        borderRadius: BorderRadius.circular(ZadRadii.pill),
        elevation: 6,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ZadSpacing.lg,
            vertical: ZadSpacing.sm,
          ),
          child: Text(
            '🍽️ $label · ${proposal.amount.toStringAsFixed(0)}',
            style: ZadType.labelLarge.copyWith(color: Colors.white),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.4, child: child),
      child: child,
    );
  }
}

/// A home proposal card that swipes (ZAD_PLAN ٢.٤): to the right confirms,
/// to the left postpones — by the hand's direction, whatever the text's.
///
/// Confirming by swipe is offered only where the card's own «تأكيد» is: a
/// proposal still asking for its direction, or whether it is a duplicate,
/// keeps its buttons and only postpones. A confirm springs the card back and
/// lets it show «جارٍ تنفيذ القرار…» until the server answers; a postpone
/// takes it off home at once.
class SwipeableProposal extends StatelessWidget {
  /// Creates the wrapper.
  const new({
    required this.proposal,
    required this.busy,
    required this.onConfirm,
    required this.onPostpone,
    required this.child,
    super.key,
  });

  /// The proposal under the card.
  final TransactionProposal proposal;

  /// A decision is in flight: nothing swipes.
  final bool busy;

  /// Swiped right.
  final VoidCallback onConfirm;

  /// Swiped left.
  final VoidCallback onPostpone;

  /// The card.
  final Widget child;

  /// Whether a right swipe may confirm this proposal.
  static bool canConfirm(TransactionProposal p) =>
      p.status == ProposalStatus.awaitingConfirmation &&
      !p.asksDuplicateQuestion;

  @override
  Widget build(BuildContext context) {
    if (busy) return child;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    // In RTL, start is the right edge: a hand moving right goes end→start.
    final right = rtl
        ? DismissDirection.endToStart
        : DismissDirection.startToEnd;
    final left = rtl
        ? DismissDirection.startToEnd
        : DismissDirection.endToStart;
    final confirmable = canConfirm(proposal);
    final direction = confirmable ? DismissDirection.horizontal : left;

    Widget hint(String text, IconData icon, Color color, Alignment at) =>
        Container(
          alignment: at,
          padding: const EdgeInsets.symmetric(horizontal: ZadSpacing.lg),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, color: color, size: 20),
              const SizedBox(width: ZadSpacing.sm),
              Text(text, style: ZadType.labelLarge.copyWith(color: color)),
            ],
          ),
        );

    final confirmHint = hint(
      'تأكيد',
      ZadIcons.selected,
      ZadColors.green600,
      Alignment.centerLeft,
    );
    final postponeHint = hint(
      'أجّل ٤ ساعات',
      Icons.schedule,
      ZadColors.slate,
      Alignment.centerRight,
    );

    return Dismissible(
      key: ValueKey<String>('swipe-${proposal.id}'),
      direction: direction,
      // background shows for startToEnd, secondaryBackground for endToStart.
      background: right == DismissDirection.startToEnd
          ? confirmHint
          : postponeHint,
      secondaryBackground: right == DismissDirection.endToStart
          ? confirmHint
          : postponeHint,
      confirmDismiss: (d) async {
        if (d == right && confirmable) {
          unawaited(HapticFeedback.mediumImpact());
          onConfirm();
          // Back into place, where it shows the decision in flight.
          return false;
        }
        if (d == left) {
          unawaited(HapticFeedback.selectionClick());
          onPostpone();
          return true;
        }
        return false;
      },
      child: child,
    );
  }
}

/// Kotlin's `TransactionProposalCard` (`ui/widgets/TransactionProposalCard.kt`).
class ProposalCard extends ConsumerWidget {
  /// Creates the card.
  const new({
    required this.proposal,
    required this.busy,
    required this.failed,
    required this.onDecide,
    super.key,
  });

  /// The proposal.
  final TransactionProposal proposal;

  /// A decision is in flight.
  final bool busy;

  /// The last decision failed.
  final bool failed;

  /// Sends a decision.
  final ValueChanged<ProposalDecision> onDecide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final country = ref.watch(settingsRepositoryProvider).cached()?.country;
    final currency = (proposal.currency?.trim().isNotEmpty ?? false)
        ? proposal.currency!
        : marketFor(country)?.currencySymbol ?? '';
    final source = proposal.merchantName ?? proposal.bankName;
    final needsKind = proposal.status == ProposalStatus.needsClassification;
    final direction = needsKind
        ? 'حدد الاتجاه'
        : switch (proposal.txnKind) {
            'income' => 'دخل متوقع',
            'transfer' => 'تحويل متوقع',
            _ => 'مصروف متوقع',
          };
    // Compose `Surface(color = White, tonalElevation = 1.dp)`: tinted only
    // where White is the scheme's surface — the light theme.
    final tinted = scheme.surface == Colors.white
        ? Color.alphaBlend(
            scheme.primary.withValues(alpha: (4.5 * math.log(2) + 2) / 100),
            Colors.white,
          )
        : Colors.white;

    void decide(ProposalDecision d) {
      if (d == ProposalDecision.confirm) {
        unawaited(HapticFeedback.mediumImpact());
      }
      onDecide(d);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tinted,
        borderRadius: BorderRadius.circular(8),
        boxShadow: composeShadow(
          elevation: 2,
          ambient: Colors.black,
          spot: Colors.black,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 34,
                  height: 34,
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet,
                    size: 20,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${proposal.amount.toStringAsFixed(2)} $currency',
                        style: ZadType.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurface,
                        ),
                      ),
                      Text(
                        proposal.title,
                        style: ZadType.bodyMedium.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  direction,
                  style: ZadType.labelSmall.copyWith(color: scheme.secondary),
                ),
              ],
            ),
            if (source != null && source.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'المصدر: $source',
                style: ZadType.bodySmall.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'لن يتغير الرصيد قبل قرارك.',
              style: ZadType.bodySmall.copyWith(color: scheme.onSurfaceVariant),
            ),
            if (failed) ...<Widget>[
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Icon(Icons.error_outline, size: 16, color: scheme.error),
                  const SizedBox(width: 6),
                  Text(
                    'تعذر تنفيذ القرار. حاول مرة أخرى.',
                    style: ZadType.labelSmall.copyWith(color: scheme.error),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            if (busy)
              const SizedBox(
                height: 40,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('جارٍ تنفيذ القرار…', style: ZadType.labelMedium),
                  ],
                ),
              )
            else if (proposal.asksDuplicateQuestion) ...<Widget>[
              Text(
                'توجد عملية أخرى بنفس المبلغ في نفس الوقت تقريبًا. هل هذه '
                'نفس المعاملة؟',
                style: ZadType.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton(
                      onPressed: () => decide(ProposalDecision.duplicate),
                      child: const Text('نفس المعاملة'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => decide(ProposalDecision.separate),
                      child: const Text('عملية أخرى'),
                    ),
                  ),
                ],
              ),
            ] else if (needsKind) ...<Widget>[
              _DirectionButtons(onDecide: decide),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => decide(ProposalDecision.reject),
                child: const Text('رفض'),
              ),
            ] else ...<Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton(
                      onPressed: () => decide(ProposalDecision.confirm),
                      child: const Text('تأكيد'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => decide(ProposalDecision.reject),
                      child: const Text('رفض'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'الاتجاه غير صحيح؟',
                style: ZadType.labelSmall.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              _DirectionButtons(
                currentKind: proposal.txnKind,
                onDecide: decide,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Kotlin's `DirectionButtons`: the three directions, less the current one.
class _DirectionButtons extends StatelessWidget {
  const new({required this.onDecide, this.currentKind});

  final String? currentKind;
  final ValueChanged<ProposalDecision> onDecide;

  @override
  Widget build(BuildContext context) {
    final choices = <(String, String, ProposalDecision)>[
      ('expense', 'مصروف', ProposalDecision.expense),
      ('income', 'دخل', ProposalDecision.income),
      ('transfer', 'تحويل', ProposalDecision.transfer),
    ].where((c) => c.$1 != currentKind).toList();
    return Row(
      children: <Widget>[
        for (var i = 0; i < choices.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
              onPressed: () => onDecide(choices[i].$3),
              child: Text(
                choices[i].$2,
                maxLines: 1,
                style: ZadType.labelSmall,
              ),
            ),
          ),
        ],
      ],
    );
  }
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
