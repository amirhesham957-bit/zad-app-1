/// Kotlin's `HomeActivationCard` (`ui/components/HomeActivationCard.kt`) and
/// `buildHomeActivationProgress` (`data/HomeActivation.kt`): «جهّز زاد
/// لبيتك», four steps that make the balance, alerts and forecasts useful from
/// day one.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/design/foundation/compose_shadow.dart';
import 'package:zad/core/design/foundation/squircle.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_motion.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/shared/bank/application/bank_access_controller.dart';
import 'package:zad/shared/budget/application/budget_controller.dart';
import 'package:zad/shared/goals/data/life_goals_remote.dart';
import 'package:zad/shared/inventory/application/pantry_controller.dart';
import 'package:zad/shared/navigation/shell_navigation.dart';
import 'package:zad/shared/navigation/zad_screens.dart';

/// Kotlin's `HomeActivationStep`.
enum HomeActivationStep {
  /// ثبّت رصيد البداية.
  setBalance,

  /// فعّل قراءة إشعارات البنك.
  enableBankReading,

  /// أضف أول صنف للبيت.
  addFirstInventoryItem,

  /// حدد أول هدف لبيتك.
  setFirstGoal,
}

/// Kotlin's `HomeActivationProgress`.
class HomeActivationProgress {
  /// Creates a progress.
  const new(this.completedSteps);

  /// The steps done.
  final Set<HomeActivationStep> completedSteps;

  /// Always four.
  int get totalCount => HomeActivationStep.values.length;

  /// How many are done.
  int get completedCount => completedSteps.length;

  /// All four done.
  bool get isComplete => completedCount == totalCount;

  /// One step done.
  bool isStepComplete(HomeActivationStep step) => completedSteps.contains(step);
}

/// The home screen's progress, from the same four readings Kotlin uses.
final homeActivationProgressProvider = Provider<HomeActivationProgress>((ref) {
  final snapshot = ref.watch(budgetControllerProvider).snapshot;
  // Kotlin: `budgetConfirmed && balanceFigure != null`.
  final hasConfirmedBalance =
      snapshot != null && snapshot.limitConfirmed && snapshot.remaining != null;
  // Kotlin: notification access granted and the listener connected.
  final bankReadingEnabled = ref.watch(
    bankAccessControllerProvider.select(
      (s) => s.granted && s.lastConnectedAt != null,
    ),
  );
  final hasInventory = ref.watch(
    pantryControllerProvider.select((v) => v.items.isNotEmpty),
  );
  // Unknown (still reading, or the read failed) counts as done, so the step
  // does not appear and vanish on a bad network — Kotlin's `?: true`.
  final hasActiveGoal = ref.watch(hasActiveLifeGoalProvider).value ?? true;
  return HomeActivationProgress(<HomeActivationStep>{
    if (hasConfirmedBalance) HomeActivationStep.setBalance,
    if (bankReadingEnabled) HomeActivationStep.enableBankReading,
    if (hasInventory) HomeActivationStep.addFirstInventoryItem,
    if (hasActiveGoal) HomeActivationStep.setFirstGoal,
  });
});

/// The card, shown on home while any step is left (Kotlin's
/// `if (!activationProgress.isComplete)`).
class HomeActivationSlot extends ConsumerStatefulWidget {
  /// Creates the slot.
  const new({super.key});

  @override
  ConsumerState<HomeActivationSlot> createState() => _HomeActivationSlotState();
}

/// One line on Home (ZAD_PLAN ١٠.٨, owner 11/11): «جهّز زاد لبيتك», how many
/// steps are done, and the next one, a tap from doing it. The four-step
/// card opens under it on a tap of the line, as before.
class _HomeActivationSlotState extends ConsumerState<HomeActivationSlot> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(homeActivationProgressProvider);
    if (progress.isComplete) return const SizedBox.shrink();
    final l = context.l10n;
    final actions = <HomeActivationStep, (String, VoidCallback)>{
      HomeActivationStep.setBalance: (
        l.activationBalance,
        () => ZadScreens.showMonthlyLimitSheet(context),
      ),
      HomeActivationStep.enableBankReading: (
        l.activationBank,
        () => ZadScreens.openBankReading(context, ref),
      ),
      HomeActivationStep.addFirstInventoryItem: (
        l.activationFirstItem,
        () =>
            ref.read(shellNavigationProvider.notifier).open(ShellTab.inventory),
      ),
      HomeActivationStep.setFirstGoal: (
        l.activationGoal,
        () => ZadScreens.showLifeGoalPickerSheet(context),
      ),
    };
    final next = HomeActivationStep.values.firstWhere(
      (s) => !progress.isStepComplete(s),
    );
    final (nextTitle, nextAction) = actions[next]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: ZadSpacing.lg),
      child: AnimatedSize(
        duration: ZadDuration.quick,
        curve: ZadCurves.standard,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            HomeActivationLine(
              done: progress.completedCount,
              total: progress.totalCount,
              next: nextTitle,
              open: _open,
              onNext: nextAction,
              onToggle: () => setState(() => _open = !_open),
            ),
            if (_open) ...<Widget>[
              const SizedBox(height: ZadSpacing.sm),
              HomeActivationCard(
                progress: progress,
                onSetBalance: actions[HomeActivationStep.setBalance]!.$2,
                onEnableBankReading:
                    actions[HomeActivationStep.enableBankReading]!.$2,
                onAddInventoryItem:
                    actions[HomeActivationStep.addFirstInventoryItem]!.$2,
                onSetFirstGoal: actions[HomeActivationStep.setFirstGoal]!.$2,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The line: a ring with the steps done, the title, the next step as a
/// button, and the chevron that opens the four.
class HomeActivationLine extends StatelessWidget {
  /// Creates the line.
  const new({
    required this.done,
    required this.total,
    required this.next,
    required this.open,
    required this.onNext,
    required this.onToggle,
    super.key,
  });

  /// Steps done.
  final int done;

  /// Steps in all.
  final int total;

  /// The next step's name.
  final String next;

  /// Whether the four steps show under it.
  final bool open;

  /// Does the next step.
  final VoidCallback onNext;

  /// Opens or closes the four steps.
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Material(
      color: ZadColors.mint50,
      shape: zadSquircle(ZadRadii.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onToggle,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: ZadSpacing.md,
              vertical: ZadSpacing.sm,
            ),
            child: Row(
              children: <Widget>[
                SizedBox.square(
                  dimension: 32,
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      CircularProgressIndicator(
                        value: done / total,
                        strokeWidth: 3,
                        color: ZadColors.green700,
                        backgroundColor: ZadColors.mint100,
                      ),
                      Text(
                        '$done',
                        style: ZadType.labelSmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: ZadColors.green700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: ZadSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        l.activationTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ZadType.titleSmall,
                      ),
                      Text(
                        l.activationProgress(done, total),
                        style: ZadType.labelSmall.copyWith(
                          color: ZadColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: ZadSpacing.sm),
                Flexible(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      foregroundColor: ZadColors.green700,
                    ),
                    onPressed: onNext,
                    child: Text(
                      next,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: open ? 0.5 : 0,
                  duration: ZadDuration.quick,
                  child: Icon(Icons.expand_more, color: ZadColors.inkMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The card.
class HomeActivationCard extends StatelessWidget {
  /// Creates the card.
  const new({
    required this.progress,
    required this.onSetBalance,
    required this.onEnableBankReading,
    required this.onAddInventoryItem,
    required this.onSetFirstGoal,
    super.key,
  });

  /// The four steps.
  final HomeActivationProgress progress;

  /// ثبّت رصيد البداية.
  final VoidCallback onSetBalance;

  /// فعّل قراءة إشعارات البنك.
  final VoidCallback onEnableBankReading;

  /// أضف أول صنف للبيت.
  final VoidCallback onAddInventoryItem;

  /// حدد أول هدف لبيتك.
  final VoidCallback onSetFirstGoal;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (progress.isComplete) return _CompleteCard(scheme: scheme);

    // Compose `Surface(tonalElevation = 1.dp)` over `surface`: the primary
    // tint at `(4.5 * ln(2) + 2) / 100`.
    final tint = (4.5 * math.log(2) + 2) / 100;
    final color = Color.alphaBlend(
      scheme.primary.withValues(alpha: tint),
      scheme.surface,
    );
    return Material(
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              context.l10n.activationTitle,
                              style: ZadType.titleMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                color: scheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              context.l10n.activationSubtitle,
                              style: ZadType.bodySmall.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        context.l10n.activationProgress(
                          progress.completedCount,
                          progress.totalCount,
                        ),
                        style: ZadType.labelMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: scheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: progress.completedCount / progress.totalCount,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                    color: scheme.primary,
                    backgroundColor: scheme.outlineVariant,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _StepRow(
              title: context.l10n.activationBalance,
              description: context.l10n.activationBalanceHint,
              complete: progress.isStepComplete(HomeActivationStep.setBalance),
              onTap: onSetBalance,
            ),
            _StepRow(
              title: context.l10n.activationBank,
              description: context.l10n.activationBankHint,
              complete: progress.isStepComplete(
                HomeActivationStep.enableBankReading,
              ),
              onTap: onEnableBankReading,
            ),
            _StepRow(
              title: context.l10n.activationFirstItem,
              description: context.l10n.activationFirstItemHint,
              complete: progress.isStepComplete(
                HomeActivationStep.addFirstInventoryItem,
              ),
              onTap: onAddInventoryItem,
            ),
            _StepRow(
              title: context.l10n.activationGoal,
              description: context.l10n.activationGoalHint,
              complete: progress.isStepComplete(
                HomeActivationStep.setFirstGoal,
              ),
              onTap: onSetFirstGoal,
            ),
          ],
        ),
      ),
    );
  }
}

/// All four done: a congratulation and a first thing to try, instead of the
/// card vanishing and leaving the customer wondering what they switched on.
class _CompleteCard extends StatelessWidget {
  const new({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(20),
      boxShadow: kZadCardShadow,
    ),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.check_circle,
                size: 22,
                color: Color(0xFF00BFA6),
              ),
              const SizedBox(width: 10),
              Text(
                context.l10n.activationTitle,
                style: ZadType.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.activationAllSet,
            style: ZadType.bodySmall.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    ),
  );
}

class _StepRow extends StatelessWidget {
  const new({
    required this.title,
    required this.description,
    required this.complete,
    required this.onTap,
  });

  final String title;
  final String description;
  final bool complete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: complete ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Row(
          children: <Widget>[
            Icon(
              complete ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 24,
              color: complete ? scheme.primary : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: ZadType.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: complete
                          ? scheme.onSurfaceVariant
                          : scheme.onSurface,
                    ),
                  ),
                  Text(
                    complete ? context.l10n.commonDone : description,
                    style: ZadType.bodySmall.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (!complete)
              Icon(
                Icons.arrow_forward,
                size: 20,
                color: scheme.primary,
                semanticLabel: context.l10n.commonOpen,
              ),
          ],
        ),
      ),
    );
  }
}
