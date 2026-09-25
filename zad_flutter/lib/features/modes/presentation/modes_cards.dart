/// Broke mode and the savings challenge — Kotlin's `BrokeModeCards.kt` and
/// `SavingsChallengeCards.kt`: the banner and card while running, the entry
/// cards and dialogs to start them, the stop confirmation, and the share.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:share_plus/share_plus.dart';
import 'package:zad/core/money/money.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/budget/application/budget_controller.dart';
import 'package:zad/features/home/presentation/metrics_duo.dart';
import 'package:zad/features/modes/application/modes_controller.dart';
import 'package:zad/features/modes/domain/modes.dart';
import 'package:zad/features/transactions/application/transactions_controller.dart';

String _money(double v, String currency) =>
    '${NumberFormat('#,##0.##', 'en').format(v)} $currency'.trim();

/// Broke mode where it belongs: the banner while it runs, the entry card
/// otherwise when [offerEntry] (the budget screen offers it; Home does not).
class BrokeModeSlot extends ConsumerWidget {
  /// Creates the slot.
  const new({this.offerEntry = false, super.key});

  /// Show the entry card when broke mode is off.
  final bool offerEntry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(modesControllerProvider);
    final now = ref.read(nowProvider)();
    final broke = view.broke;
    final daysLeft =
        ref.watch(
          budgetControllerProvider.select((v) => v.snapshot?.daysLeft),
        ) ??
        1;
    if (broke != null && broke.isActiveAt(now)) {
      return _BrokeBanner(mode: broke, daysLeft: daysLeft);
    }
    if (!offerEntry) return const SizedBox.shrink();
    return _EntryCard(
      icon: ZadIcons.budget,
      tint: ZadColors.terracottaRust,
      title: 'مفلس لآخر الشهر؟',
      subtitle: 'زاد تقسّم اللي معاك على الأيام الباقية وتوقف أي اقتراح شراء',
      action: 'فعّل وضع الطوارئ',
      onTap: () => unawaited(showBrokeModeDialog(context, ref, daysLeft)),
    );
  }
}

class _BrokeBanner extends ConsumerWidget {
  const new({required this.mode, required this.daysLeft});

  final BrokeMode mode;
  final int daysLeft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const ink = Color(0xFF5C1D0C);
    final cap = mode.dailyCap;
    final days = daysLeft < 1 ? 1 : daysLeft;
    return Container(
      padding: const EdgeInsets.all(ZadSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFFFBE3D9),
        borderRadius: BorderRadius.circular(ZadRadii.cardLarge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: ink.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const SizedBox.square(
                  dimension: 40,
                  child: Icon(ZadIcons.failed, size: 22, color: ink),
                ),
              ),
              const SizedBox(width: ZadSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'وضع الطوارئ شغال',
                      style: ZadType.titleSmall.copyWith(
                        color: ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      cap == null
                          ? 'قولي معاك كام لآخر الشهر وأنا أقسّمهم على الأيام'
                          : 'مصروفك النهارده '
                                '${_money(cap, mode.currency ?? '')} '
                                'بالظبط — فاضل $days يوم',
                      style: ZadType.bodyMedium.copyWith(color: ink),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: ZadSpacing.sm),
          Text(
            'وقفت اقتراحات الشراء، والوصفات من اللي في البيت بس. هنعدّيها سوا.',
            style: ZadType.bodySmall.copyWith(
              color: ink.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: ZadSpacing.sm),
          Wrap(
            spacing: ZadSpacing.sm,
            children: <Widget>[
              if (cap == null)
                FilledButton(
                  onPressed: () =>
                      unawaited(showBrokeModeDialog(context, ref, days)),
                  child: const Text('معايا كام؟'),
                ),
              TextButton(
                onPressed: () => unawaited(
                  ref.read(modesControllerProvider.notifier).endBroke(),
                ),
                style: TextButton.styleFrom(foregroundColor: ink),
                child: const Text('قبضت — اقفل الوضع'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// «معاك كام لآخر الشهر؟» — blank means "use my confirmed balance".
Future<void> showBrokeModeDialog(
  BuildContext context,
  WidgetRef ref,
  int daysLeft,
) async {
  final controller = TextEditingController();
  final result = await showDialog<({double? cash})>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setState) {
        final text = controller.text.trim();
        final parsed = parseMoneyInput(text);
        // parseMoneyInput refuses zero; a customer with nothing left can
        // still say so.
        final zero = RegExp(r'^[0٠]+([.,][0٠]*)?$').hasMatch(text);
        final ok = text.isEmpty || parsed != null || zero;
        return AlertDialog(
          title: const Text('وضع الطوارئ'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'فاضل ${daysLeft < 1 ? 1 : daysLeft} يوم. اكتب اللي معاك '
                'فعلاً، أو سيبه فاضي وأحسب من رصيدك.',
              ),
              const SizedBox(height: ZadSpacing.md),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'معاك كام لآخر الشهر؟',
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(c).pop(),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: ok
                  ? () => Navigator.of(c).pop((cash: zero ? 0.0 : parsed))
                  : null,
              child: const Text('فعّل وضع الطوارئ'),
            ),
          ],
        );
      },
    ),
  );
  controller.dispose();
  if (result == null) return;
  await ref.read(modesControllerProvider.notifier).activateBroke(result.cash);
}

/// The challenge: its card while running, else the entry card when
/// [offerEntry], and under the card the stop button when [offerStop].
class SavingsChallengeSlot extends ConsumerWidget {
  /// Creates the slot.
  const new({this.offerEntry = false, this.offerStop = false, super.key});

  /// Show the entry card when no challenge runs.
  final bool offerEntry;

  /// Show "إيقاف التحدي" under a running one.
  final bool offerStop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(modesControllerProvider);
    final challenge = view.challenge;
    final controller = ref.read(modesControllerProvider.notifier);
    if (challenge == null) {
      if (!offerEntry) return const SizedBox.shrink();
      return _EntryCard(
        icon: ZadIcons.leaderboard,
        tint: ZadColors.mustardOchre,
        title: 'تحدي ٣٠ يوم توفير',
        subtitle: 'سقف يومي، سلسلة أيام، وزاد تحتفل معاك بصوتها في كل محطة',
        action: 'ابدأ التحدي',
        onTap: () => unawaited(showChallengeDialog(context, ref)),
      );
    }
    // Watched so a new expense moves the bar; the rows come from the whole
    // cache, since "today" may straddle a period boundary.
    ref.watch(transactionsControllerProvider);
    final rows = ref.read(transactionsRepositoryProvider).allCached();
    final spent = spentToday(rows, controller.isToday);
    final day = challengeDayIndex(challenge, controller.today());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _ChallengeCard(challenge: challenge, dayIndex: day, todaySpent: spent),
        if (offerStop)
          TextButton(
            onPressed: () => unawaited(_confirmStop(context, ref)),
            style: TextButton.styleFrom(
              foregroundColor: ZadColors.inkMuted,
              minimumSize: const Size(0, 44),
            ),
            child: const Text('إيقاف التحدي'),
          ),
      ],
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  const new({
    required this.challenge,
    required this.dayIndex,
    required this.todaySpent,
  });

  final SavingsChallenge challenge;
  final int dayIndex;
  final double todaySpent;

  @override
  Widget build(BuildContext context) {
    final cap = challenge.dailyCap;
    final over = todaySpent > cap;
    final currency = challenge.currency ?? '';
    return Container(
      padding: const EdgeInsets.all(ZadSpacing.lg),
      decoration: BoxDecoration(
        color: ZadColors.surface,
        borderRadius: BorderRadius.circular(ZadRadii.cardLarge),
        border: Border.all(color: ZadColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                ZadIcons.leaderboard,
                size: 22,
                color: ZadColors.mustardOchre,
              ),
              const SizedBox(width: ZadSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'تحدي ${challenge.lengthDays} يوم توفير',
                      style: ZadType.titleSmall.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'اليوم $dayIndex من ${challenge.lengthDays}',
                      style: ZadType.bodySmall.copyWith(
                        color: ZadColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => unawaited(
                  SharePlus.instance.share(
                    ShareParams(
                      text:
                          'أنا في اليوم $dayIndex من تحدي '
                          '${challenge.lengthDays} يوم توفير مع زاد 🔥 وسلسلتي '
                          '${challenge.streak} يوم ورا بعض! تيجي تتحداني؟',
                    ),
                  ),
                ),
                tooltip: 'شارك التحدي',
                icon: const Icon(ZadIcons.send, color: ZadColors.forestEmerald),
              ),
            ],
          ),
          const SizedBox(height: ZadSpacing.sm),
          Row(
            children: <Widget>[
              _Stat(value: '🔥 ${challenge.streak}', label: 'ورا بعض'),
              const SizedBox(width: ZadSpacing.lg),
              _Stat(value: '${challenge.daysWon}', label: 'يوم كسبته'),
              const SizedBox(width: ZadSpacing.lg),
              _Stat(value: '${challenge.bestStreak}', label: 'أطول سلسلة'),
            ],
          ),
          const SizedBox(height: ZadSpacing.sm),
          Text(
            'صرفت النهارده ${_money(todaySpent, currency)} من '
            '${_money(cap, currency)}',
            style: ZadType.bodyMedium.copyWith(
              color: over ? ZadColors.terracottaRust : ZadColors.ink,
            ),
          ),
          const SizedBox(height: ZadSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: cap > 0 ? (todaySpent / cap).clamp(0, 1) : 1,
              minHeight: 8,
              color: over ? ZadColors.terracottaRust : ZadColors.forestEmerald,
              backgroundColor: ZadColors.outlineVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const new({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(
        value,
        style: ZadType.titleMedium.copyWith(fontWeight: FontWeight.w700),
      ),
      Text(
        label,
        style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
      ),
    ],
  );
}

class _EntryCard extends StatelessWidget {
  const new({
    required this.icon,
    required this.tint,
    required this.title,
    required this.subtitle,
    required this.action,
    required this.onTap,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final String subtitle;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: ZadSpacing.lg,
      vertical: ZadSpacing.md,
    ),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(ZadRadii.card),
      border: Border.all(color: ZadColors.outlineVariant),
    ),
    child: Row(
      children: <Widget>[
        Icon(icon, size: 24, color: tint),
        const SizedBox(width: ZadSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: ZadType.bodyLarge.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                subtitle,
                style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
              ),
            ],
          ),
        ),
        const SizedBox(width: ZadSpacing.sm),
        OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
          child: Text(action),
        ),
      ],
    ),
  );
}

/// Kotlin's `SavingsChallengeDialog`: a daily cap (suggested when there is a
/// basis for one) and a length of 7, 14 or 30 days.
Future<void> showChallengeDialog(BuildContext context, WidgetRef ref) async {
  final controller = ref.read(modesControllerProvider.notifier);
  final budget = ref.read(budgetControllerProvider);
  final spendable = budget.spendable;
  final daysLeft = budget.snapshot?.daysLeft ?? 0;
  final suggested = suggestChallengeCap(
    avgDailySpend: _averageDailySpend(ref, controller),
    dailyAllowanceLeft: spendable == null
        ? null
        : safeDailySpend(spendable: spendable, daysLeft: daysLeft),
  );
  final cap = TextEditingController(
    text: suggested == null ? '' : suggested.toStringAsFixed(0),
  );
  var length = 30;
  final result = await showDialog<(double, int)>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setState) {
        final parsed = parseMoneyInput(cap.text);
        final valid = parsed != null && parsed >= 1;
        return AlertDialog(
          title: const Text('تحدي ٣٠ يوم توفير'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                suggested != null
                    ? 'اقترحت سقف أقل شوية من متوسط صرفك — عدّله براحتك.'
                    : 'حدد أقصى مبلغ هتصرفه في اليوم.',
              ),
              const SizedBox(height: ZadSpacing.md),
              TextField(
                controller: cap,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(labelText: 'السقف اليومي'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: ZadSpacing.md),
              Wrap(
                spacing: ZadSpacing.sm,
                children: <Widget>[
                  for (final d in const <int>[7, 14, 30])
                    ChoiceChip(
                      label: Text('$d يوم'),
                      selected: length == d,
                      onSelected: (_) => setState(() => length = d),
                    ),
                ],
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(c).pop(),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: valid
                  ? () => Navigator.of(c).pop((parsed, length))
                  : null,
              child: const Text('ابدأ التحدي'),
            ),
          ],
        );
      },
    ),
  );
  cap.dispose();
  if (result == null) return;
  await controller.startChallenge(result.$1, result.$2);
}

/// The last 30 days' average daily spend, from what is cached — the
/// suggestion's basis, as in Kotlin.
double? _averageDailySpend(WidgetRef ref, ModesController controller) {
  final today = controller.today();
  final from = today.subtract(const Duration(days: 30));
  var total = 0.0;
  for (final t in ref.read(transactionsRepositoryProvider).allCached()) {
    if (!t.countsTowardBudget || !t.isExpense) continue;
    if (t.createdAt.isBefore(from)) continue;
    total += t.amount.abs();
  }
  return total > 0 ? total / 30 : null;
}

Future<void> _confirmStop(BuildContext context, WidgetRef ref) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('توقف التحدي؟'),
      content: const Text(
        'السلسلة هتقف والأيام اللي كسبتها هتفضل محسوبة. تقدر تبدأ تاني وقت '
        'ما تحب.',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(c).pop(false),
          child: const Text('إلغاء'),
        ),
        TextButton(
          onPressed: () => Navigator.of(c).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: ZadColors.terracottaRust,
          ),
          child: const Text('إيقاف التحدي'),
        ),
      ],
    ),
  );
  if (ok == true) {
    await ref.read(modesControllerProvider.notifier).stopChallenge();
  }
}
