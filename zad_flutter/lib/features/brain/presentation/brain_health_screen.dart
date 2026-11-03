/// l.brainHealthTitle: the screen that makes a stalled proactive brain visible.
///
/// The verdict is `domain/brain_health.dart`'s; this only puts it into words.
/// The raw server error is never shown — only its kind — and "quiet" reads as
/// "worth a look", not "calm", because a nearly spent chat allowance or an
/// unexpected action means the brain is busy, not idle.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/design/components/zad_card.dart';
import 'package:zad/core/design/components/zad_empty_state.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/brain/application/brain_health_controller.dart';
import 'package:zad/features/brain/data/held_messages_remote.dart';
import 'package:zad/features/brain/domain/brain_health.dart';
import 'package:zad/features/brain/domain/held_messages.dart';

/// Opens the screen.
Future<void> showBrainHealth(BuildContext context) => Navigator.of(context)
    .push<void>(
      MaterialPageRoute<void>(builder: (_) => const BrainHealthScreen()),
    );

/// "3 ساعات", "ساعتين", "يوم واحد" — counts agree with the number (ICU
/// plurals in the ARB; Arabic when [l10n] is absent).
String arabicCount(int n, {required bool days, ZadL10n? l10n}) {
  final l = l10n ?? zadL10nArabic;
  return days ? l.brainHealthDays(n) : l.brainHealthHours(n);
}

/// How long since the last proactive message, in words.
String durationSince(int? hours, [ZadL10n? l10n]) {
  final l = l10n ?? zadL10nArabic;
  if (hours == null) return l.brainHealthNever;
  if (hours < 1) return l.brainHealthJustNow;
  if (hours < 24) return arabicCount(hours, days: false, l10n: l);
  return arabicCount(hours ~/ 24, days: true, l10n: l);
}

/// What a reason says, with its figures.
String reasonText(BrainHealthReason reason, BrainHealth h, [ZadL10n? l10n]) {
  final l = l10n ?? zadL10nArabic;
  return switch (reason) {
    BrainHealthReason.noProactiveYet => l.brainHealthReasonNoProactiveYet,
    BrainHealthReason.proactiveSilent => l.brainHealthReasonProactiveSilent(
      durationSince(h.hoursSinceLastProactive, l),
    ),
    BrainHealthReason.tasksBackedUp => l.brainHealthReasonTasksBackedUp(
      h.tasksBackedUp,
    ),
    BrainHealthReason.runsFailing => l.brainHealthReasonRunsFailing(
      h.failedRunsLast7Days,
      h.runsLast7Days,
    ),
    BrainHealthReason.tasksFailed => l.brainHealthReasonTasksFailed(
      h.failedTasksLast7Days,
    ),
    BrainHealthReason.requestsNotRetried => l.brainHealthReasonNotRetried(
      h.queueRowsLast7Days,
    ),
    BrainHealthReason.chatQuotaNearLimit => l.brainHealthReasonQuotaNear(
      (h.chatQuotaRatio * 100).floor(),
    ),
  };
}

Color _statusColor(BrainHealthStatus s) => switch (s) {
  BrainHealthStatus.healthy => ZadColors.green600,
  BrainHealthStatus.quiet => ZadColors.mustardOchre,
  BrainHealthStatus.stalled => ZadColors.terracottaRust,
};

/// The screen.
class BrainHealthScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const new({super.key});

  @override
  ConsumerState<BrainHealthScreen> createState() => _BrainHealthScreenState();
}

class _BrainHealthScreenState extends ConsumerState<BrainHealthScreen> {
  @override
  void initState() {
    super.initState();
    // After this frame: a refresh changes provider state, which is not
    // allowed while the tree is building.
    unawaited(
      Future<void>.microtask(
        () => mounted ? _refresh(sayFailure: false) : null,
      ),
    );
  }

  Future<void> _refresh({bool sayFailure = true}) async {
    final ok = await ref.read(brainHealthControllerProvider.notifier).refresh();
    if (!ok && sayFailure && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(context.l10n.brainHealthCannotSee)),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(brainHealthControllerProvider);
    final health = view.health;
    final l = context.l10n;

    return DecoratedBox(
      decoration: BoxDecoration(gradient: ZadColors.canvas),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(l.brainHealthTitle),
          actions: <Widget>[
            IconButton(
              onPressed: view.isLoading ? null : _refresh,
              tooltip: l.brainHealthRefresh,
              icon: view.isLoading && health != null
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(ZadIcons.retry),
            ),
          ],
        ),
        body: switch (health) {
          null when view.isLoading => const Center(
            child: CircularProgressIndicator(),
          ),
          null => ZadEmptyState(
            icon: ZadIcons.failed,
            title: l.brainHealthCannotSeeTitle,
            message: l.brainHealthCannotSee,
            tone: ZadEmptyTone.problem,
            action: FilledButton(
              onPressed: _refresh,
              child: Text(l.brainHealthRetry),
            ),
          ),
          final BrainHealth h => _Body(health: h),
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const new({required this.health});

  final BrainHealth health;

  @override
  Widget build(BuildContext context) {
    final h = health;
    final ratio = h.chatQuotaRatio.clamp(0.0, 1.0);
    final quotaColor = h.chatQuotaRatio >= BrainHealthLimits.chatQuotaWarnRatio
        ? ZadColors.terracottaRust
        : h.chatQuotaRatio >= BrainHealthLimits.chatQuotaWarnRatio / 2
        ? ZadColors.mustardOchre
        : ZadColors.green600;
    final l = context.l10n;

    return ListView(
      padding: const EdgeInsets.all(ZadSpacing.gutter),
      children: <Widget>[
        _StatusBanner(health: h),
        const SizedBox(height: ZadSpacing.md),
        _Section(
          title: l.brainHealthActivity,
          children: <Widget>[
            _Metric(
              l.brainHealthLastProactive,
              durationSince(h.hoursSinceLastProactive, l),
            ),
            _Metric(l.brainHealthRuns7d, '${h.runsLast7Days}'),
            _Metric(
              l.brainHealthRunsFailed,
              '${h.failedRunsLast7Days}',
              alarming: h.failedRunsLast7Days > 0,
            ),
            _Metric(l.brainHealthInsights7d, '${h.insightsLast7Days}'),
            _Metric(l.brainHealthInsightsUnseen, '${h.pendingInsights}'),
            if (h.lastFailureKind case final BrainFailureKind kind)
              _Metric(l.brainHealthLastFailure, switch (kind) {
                BrainFailureKind.providerBusy => l.brainHealthFailureBusy,
                BrainFailureKind.configuration => l.brainHealthFailureConfig,
                BrainFailureKind.other => l.brainHealthFailureOther,
              }),
          ],
        ),
        const SizedBox(height: ZadSpacing.md),
        _Section(
          title: l.brainHealthTasks,
          children: <Widget>[
            _Metric(
              l.brainHealthTasksStuck,
              '${h.tasksBackedUp}',
              alarming: h.tasksBackedUp > 0,
            ),
            _Metric(l.brainHealthTasksPending, '${h.pendingTasksCount}'),
            _Metric(
              l.brainHealthTasksFailed7d,
              '${h.failedTasksLast7Days}',
              alarming: h.failedTasksLast7Days > 0,
            ),
            _Metric(
              l.brainHealthNotRetried,
              '${h.queueRowsLast7Days}',
              alarming: h.queueRowsLast7Days > 0,
            ),
          ],
        ),
        const SizedBox(height: ZadSpacing.md),
        _Section(
          title: l.brainHealthChatUse,
          children: <Widget>[
            _Metric(
              l.brainHealthRequests,
              l.brainHealthOf(h.requestsToday, BrainHealthLimits.dailyRequests),
            ),
            _Metric(
              l.brainHealthTokens,
              l.brainHealthOf(h.tokensToday, BrainHealthLimits.dailyTokens),
            ),
            const SizedBox(height: ZadSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(ZadSpacing.xs),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                color: quotaColor,
                backgroundColor: ZadColors.surfaceVariant,
              ),
            ),
            const SizedBox(height: ZadSpacing.sm),
            Text(
              l.brainHealthQuotaNote,
              style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
            ),
          ],
        ),
        const SizedBox(height: ZadSpacing.md),
        _Section(
          title: l.brainHealthLearning,
          children: <Widget>[
            _Metric(l.brainHealthGoals, '${h.activeGoals}'),
            _Metric(
              l.brainHealthDrift,
              '${h.driftLast7Days}',
              alarming: h.driftLast7Days > 0,
            ),
          ],
        ),
        const SizedBox(height: ZadSpacing.md),
        const _HeldThisWeek(),
        const SizedBox(height: ZadSpacing.xxl),
      ],
    );
  }
}

/// «اللي سكتّ عنه وليه» (ZAD_PLAN 3.5): each guard that held a message this
/// week, in words. Its own read: a failure here never hides the verdict above.
class _HeldThisWeek extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final held = ref.watch(heldThisWeekProvider);
    final muted = ZadType.bodySmall.copyWith(color: ZadColors.inkMuted);
    return _Section(
      title: l.heldTitle,
      children: switch (held) {
        AsyncData(:final value) when value.isEmpty => <Widget>[
          Text(l.heldNone, style: muted),
        ],
        AsyncData(:final value) => <Widget>[
          for (final line in value)
            Padding(
              padding: const EdgeInsets.only(bottom: ZadSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${heldKindText(l, line)}: '
                    '${heldActionText(l, line.action)}'
                    '${line.times > 1 ? ' (${l.heldTimes(line.times)})' : ''}',
                    style: ZadType.bodyMedium,
                  ),
                  Text(heldReasonText(l, line.reason), style: muted),
                ],
              ),
            ),
          Text(
            l.heldAskHint,
            style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
          ),
        ],
        AsyncError() => <Widget>[Text(l.heldFailed, style: muted)],
        _ => <Widget>[Text(l.heldLoading, style: muted)],
      },
    );
  }
}

/// Why a guard held it.
String heldReasonText(ZadL10n l, HeldReason r) => switch (r) {
  HeldReason.muted => l.heldReasonMuted,
  HeldReason.learnedQuiet => l.heldReasonLearnedQuiet,
  HeldReason.quietHours => l.heldReasonQuietHours,
  HeldReason.replyHour => l.heldReasonReplyHour,
  HeldReason.pacing => l.heldReasonPacing,
  HeldReason.dailyCap => l.heldReasonDailyCap,
  HeldReason.busyDay => l.heldReasonBusyDay,
  HeldReason.circumstance => l.heldReasonCircumstance,
  HeldReason.duplicate => l.heldReasonDuplicate,
  HeldReason.expired => l.heldReasonExpired,
  HeldReason.notRelevant => l.heldReasonNotRelevant,
  HeldReason.nothingNew => l.heldReasonNothingNew,
  HeldReason.other => l.heldReasonOther,
};

/// What happened to it.
String heldActionText(ZadL10n l, HeldAction a) => switch (a) {
  HeldAction.dropped => l.heldActionDropped,
  HeldAction.waiting => l.heldActionWaiting,
  HeldAction.postponed => l.heldActionPostponed,
};

/// The message, in words. Unknown kinds keep a generic name.
String heldKindText(ZadL10n l, HeldLine line) => line.source == 'moment'
    ? switch (line.kind) {
        'good_night' => l.heldKindGoodNight,
        'close_day' => l.heldKindCloseDay,
        'morning_greeting' => l.heldKindMorning,
        'weekly_money_story' => l.heldKindWeeklyStory,
        'newcomer_question' => l.heldKindNewcomer,
        'salary_cycle' => l.heldKindSalary,
        _ => l.heldKindVoice,
      }
    : switch (line.kind) {
        'home_weekly_digest' => l.heldKindDigest,
        'spend_forecast' => l.heldKindForecast,
        'spending_ahead' => l.heldKindSpendingAhead,
        'bill_reminder' => l.heldKindBill,
        'warranty_reminder' => l.heldKindWarranty,
        'goal_review' => l.heldKindGoal,
        'habit_budget' => l.heldKindHabit,
        'predicted_shortage' => l.heldKindShortage,
        'restock_link' => l.heldKindRestock,
        'pet_call' => l.heldKindPet,
        _ => l.heldKindNote,
      };

class _StatusBanner extends StatelessWidget {
  const new({required this.health});

  final BrainHealth health;

  @override
  Widget build(BuildContext context) {
    final status = health.status;
    final tint = _statusColor(status);
    final l = context.l10n;
    final (icon, title) = switch (status) {
      BrainHealthStatus.healthy => (ZadIcons.selected, l.brainHealthHealthy),
      BrainHealthStatus.quiet => (ZadIcons.failed, l.brainHealthQuiet),
      BrainHealthStatus.stalled => (ZadIcons.failed, l.brainHealthStalled),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(ZadSpacing.lg),
        border: Border.all(color: tint.withValues(alpha: 0.25), width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(ZadSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, color: tint, size: 24),
                const SizedBox(width: ZadSpacing.md),
                Expanded(child: Text(title, style: ZadType.titleMedium)),
              ],
            ),
            const SizedBox(height: ZadSpacing.md),
            if (health.reasons.isEmpty)
              Text(
                l.brainHealthAllClear,
                style: ZadType.bodyMedium.copyWith(color: ZadColors.inkMuted),
              )
            else
              for (final r in health.reasons)
                Padding(
                  padding: const EdgeInsets.only(bottom: ZadSpacing.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(top: ZadSpacing.sm),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: _statusColor(r.severity),
                            shape: BoxShape.circle,
                          ),
                          child: const SizedBox.square(dimension: 6),
                        ),
                      ),
                      const SizedBox(width: ZadSpacing.sm),
                      Expanded(
                        child: Text(
                          reasonText(r, health),
                          style: ZadType.bodyMedium.copyWith(
                            color: ZadColors.slate,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const new({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ZadCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(title, style: ZadType.labelLarge),
        const SizedBox(height: ZadSpacing.sm),
        ...children,
      ],
    ),
  );
}

class _Metric extends StatelessWidget {
  const new(this.label, this.value, {this.alarming = false});

  final String label;
  final String value;
  final bool alarming;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: ZadSpacing.xs),
    child: Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: ZadType.bodyMedium.copyWith(color: ZadColors.inkMuted),
          ),
        ),
        const SizedBox(width: ZadSpacing.md),
        Text(
          value,
          style: ZadType.bodyMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: alarming ? ZadColors.terracottaRust : ZadColors.ink,
          ),
        ),
      ],
    ),
  );
}
