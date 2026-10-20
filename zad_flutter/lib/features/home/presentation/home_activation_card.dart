/// Kotlin's `HomeActivationCard` (`ui/components/HomeActivationCard.kt`) and
/// `buildHomeActivationProgress` (`data/HomeActivation.kt`): «جهّز زاد
/// لبيتك», four steps that make the balance, alerts and forecasts useful from
/// day one.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/design/foundation/compose_shadow.dart';
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
class HomeActivationSlot extends ConsumerWidget {
  /// Creates the slot.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(homeActivationProgressProvider);
    if (progress.isComplete) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: HomeActivationCard(
        progress: progress,
        onSetBalance: () => ZadScreens.showMonthlyLimitSheet(context),
        onEnableBankReading: () => ZadScreens.openBankReading(context, ref),
        onAddInventoryItem: () =>
            ref.read(shellNavigationProvider.notifier).open(ShellTab.inventory),
        onSetFirstGoal: () => ZadScreens.showLifeGoalPickerSheet(context),
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
