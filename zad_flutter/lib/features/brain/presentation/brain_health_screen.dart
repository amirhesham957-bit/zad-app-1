/// "صحة عقل زاد": the screen that makes a stalled proactive brain visible.
///
/// The verdict is `domain/brain_health.dart`'s; this only puts it into words.
/// The raw server error is never shown — only its kind — and "quiet" reads as
/// "worth a look", not "calm", because a nearly spent chat allowance or an
/// unexpected action means the brain is busy, not idle.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/design/components/zad_card.dart';
import 'package:zad/design/components/zad_empty_state.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/brain/application/brain_health_controller.dart';
import 'package:zad/features/brain/domain/brain_health.dart';

/// Opens the screen.
Future<void> showBrainHealth(BuildContext context) => Navigator.of(context)
    .push<void>(
      MaterialPageRoute<void>(builder: (_) => const BrainHealthScreen()),
    );

/// "3 ساعات", "ساعتين", "يوم واحد" — Arabic counts agree with the number.
String arabicCount(int n, {required bool days}) {
  if (days) {
    return switch (n) {
      1 => 'يوم واحد',
      2 => 'يومين',
      >= 3 && <= 10 => '$n أيام',
      _ => '$n يوم',
    };
  }
  return switch (n) {
    1 => 'ساعة واحدة',
    2 => 'ساعتين',
    >= 3 && <= 10 => '$n ساعات',
    _ => '$n ساعة',
  };
}

/// How long since the last proactive message, in words.
String durationSince(int? hours) {
  if (hours == null) return 'ولا مرة';
  if (hours < 1) return 'دلوقتي';
  if (hours < 24) return arabicCount(hours, days: false);
  return arabicCount(hours ~/ 24, days: true);
}

/// What a reason says, with its figures.
String reasonText(BrainHealthReason reason, BrainHealth h) => switch (reason) {
  BrainHealthReason.noProactiveYet =>
    'زاد لسه بيتعرف عليك، وهيبدأ يبعتلك تنبيهات استباقية بعد شوية استخدام',
  BrainHealthReason.proactiveSilent =>
    'زاد بطّل يبعت تنبيهات استباقية من '
        '${durationSince(h.hoursSinceLastProactive)}',
  BrainHealthReason.tasksBackedUp =>
    'عدد المهام الواقفة أو المتأخرة: ${h.tasksBackedUp}',
  BrainHealthReason.runsFailing =>
    'عدد التشغيلات الفاشلة: ${h.failedRunsLast7Days} من ${h.runsLast7Days}',
  BrainHealthReason.tasksFailed =>
    'عدد المهام اللي فشلت: ${h.failedTasksLast7Days}',
  BrainHealthReason.requestsNotRetried =>
    'عدد الطلبات اللي ماتعادتش: ${h.queueRowsLast7Days}',
  BrainHealthReason.chatQuotaNearLimit =>
    'استخدام الشات قرب من الحد اليومي '
        '(${(h.chatQuotaRatio * 100).floor()}%) — ممكن الردود تقف لحد بكرة',
};

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
  static const String _cannotSee =
      'معرفتش أقرا حالة العقل دلوقتي. ده مش معناه إن كل حاجة تمام — معناه '
      'إني مش شايف.';

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
        ..showSnackBar(const SnackBar(content: Text(_cannotSee)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(brainHealthControllerProvider);
    final health = view.health;

    return DecoratedBox(
      decoration: const BoxDecoration(gradient: ZadColors.canvas),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('صحة عقل زاد'),
          actions: <Widget>[
            IconButton(
              onPressed: view.isLoading ? null : _refresh,
              tooltip: 'حدّث',
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
            title: 'مش شايف العقل دلوقتي',
            message: _cannotSee,
            tone: ZadEmptyTone.problem,
            action: FilledButton(
              onPressed: _refresh,
              child: const Text('جرب تاني'),
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

    return ListView(
      padding: const EdgeInsets.all(ZadSpacing.gutter),
      children: <Widget>[
        _StatusBanner(health: h),
        const SizedBox(height: ZadSpacing.md),
        _Section(
          title: 'النشاط',
          children: <Widget>[
            _Metric(
              'آخر تنبيه استباقي',
              durationSince(h.hoursSinceLastProactive),
            ),
            _Metric('تشغيلات آخر ٧ أيام', '${h.runsLast7Days}'),
            _Metric(
              'منها فشلت',
              '${h.failedRunsLast7Days}',
              alarming: h.failedRunsLast7Days > 0,
            ),
            _Metric('رؤى آخر ٧ أيام', '${h.insightsLast7Days}'),
            _Metric('رؤى لسه مشوفتهاش', '${h.pendingInsights}'),
            if (h.lastFailureKind case final BrainFailureKind kind)
              _Metric('نوع آخر عطل', switch (kind) {
                BrainFailureKind.providerBusy => 'المزوّد مشغول',
                BrainFailureKind.configuration => 'مشكلة إعداد',
                BrainFailureKind.other => 'غير معروف',
              }),
          ],
        ),
        const SizedBox(height: ZadSpacing.md),
        _Section(
          title: 'المهام والطابور',
          children: <Widget>[
            _Metric(
              'مهام واقفة أو متأخرة',
              '${h.tasksBackedUp}',
              alarming: h.tasksBackedUp > 0,
            ),
            _Metric('مهام مستنية دورها', '${h.pendingTasksCount}'),
            _Metric(
              'مهام فشلت آخر ٧ أيام',
              '${h.failedTasksLast7Days}',
              alarming: h.failedTasksLast7Days > 0,
            ),
            _Metric(
              'طلبات ماتعادتش',
              '${h.queueRowsLast7Days}',
              alarming: h.queueRowsLast7Days > 0,
            ),
          ],
        ),
        const SizedBox(height: ZadSpacing.md),
        _Section(
          title: 'استخدام الشات',
          children: <Widget>[
            _Metric(
              'الطلبات',
              '${h.requestsToday} من ${BrainHealthLimits.dailyRequests}',
            ),
            _Metric(
              'حجم الردود',
              '${h.tokensToday} من ${BrainHealthLimits.dailyTokens}',
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
              'الرصيد ده بتاع ردود الشات بس، وبيتصفّر كل يوم بتوقيت جرينتش — '
              'مالوش علاقة بشغل زاد في الخلفية',
              style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
            ),
          ],
        ),
        const SizedBox(height: ZadSpacing.md),
        _Section(
          title: 'التعلّم',
          children: <Widget>[
            _Metric('أهداف زاد شغال عليها', '${h.activeGoals}'),
            _Metric(
              'تصرفات غير متوقعة من زاد آخر ٧ أيام',
              '${h.driftLast7Days}',
              alarming: h.driftLast7Days > 0,
            ),
          ],
        ),
        const SizedBox(height: ZadSpacing.xxl),
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const new({required this.health});

  final BrainHealth health;

  @override
  Widget build(BuildContext context) {
    final status = health.status;
    final tint = _statusColor(status);
    final (icon, title) = switch (status) {
      BrainHealthStatus.healthy => (ZadIcons.selected, 'العقل شغال تمام'),
      BrainHealthStatus.quiet => (ZadIcons.failed, 'فيه حاجة تستاهل نظرة'),
      BrainHealthStatus.stalled => (ZadIcons.failed, 'العقل واقف ومحتاج تدخّل'),
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
                'مفيش أي مشكلة مرصودة. زاد بيشتغل في الخلفية وبيسجّل كل خطوة.',
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
