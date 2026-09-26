/// Kotlin's `HomeActivationCard` (`ui/components/HomeActivationCard.kt`) and
/// `buildHomeActivationProgress` (`data/HomeActivation.kt`): «جهّز زاد
/// لبيتك», four steps that make the balance, alerts and forecasts useful from
/// day one.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/app/shell_navigation.dart';
import 'package:zad/design/foundation/compose_shadow.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/bank/application/bank_access_controller.dart';
import 'package:zad/features/budget/application/budget_controller.dart';
import 'package:zad/features/goals/data/life_goals_remote.dart';
import 'package:zad/features/goals/presentation/life_goal_picker_sheet.dart';
import 'package:zad/features/inventory/application/pantry_controller.dart';
import 'package:zad/features/settings/presentation/monthly_limit_sheet.dart';

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
    bankAccessControllerProvider.select((s) => s.granted),
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
        onSetBalance: () => showMonthlyLimitSheet(context),
        onEnableBankReading: () =>
            ref.read(bankAccessControllerProvider.notifier).openSettings(),
        onAddInventoryItem: () =>
            ref.read(shellNavigationProvider.notifier).open(ShellTab.inventory),
        onSetFirstGoal: () => showLifeGoalPickerSheet(context),
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
                              'جهّز زاد لبيتك',
                              style: ZadType.titleMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                color: scheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'أربع خطوات تجعل الرصيد والتنبيهات والتوقعات '
                              'مفيدة من أول يوم',
                              style: ZadType.bodySmall.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${progress.completedCount} من ${progress.totalCount}',
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
              title: 'ثبّت رصيد البداية',
              description:
                  'اكتب المبلغ الموجود الآن ليحسب زاد السحب والإيداع بدقة',
              complete: progress.isStepComplete(HomeActivationStep.setBalance),
              onTap: onSetBalance,
            ),
            _StepRow(
              title: 'فعّل قراءة إشعارات البنك',
              description: 'اسمح لزاد بالتقاط العمليات وعرضها للتأكيد',
              complete: progress.isStepComplete(
                HomeActivationStep.enableBankReading,
              ),
              onTap: onEnableBankReading,
            ),
            _StepRow(
              title: 'أضف أول صنف للبيت',
              description: 'ابدأ بصنف متكرر ليتعلم زاد استهلاكك',
              complete: progress.isStepComplete(
                HomeActivationStep.addFirstInventoryItem,
              ),
              onTap: onAddInventoryItem,
            ),
            _StepRow(
              title: 'حدد أول هدف لبيتك',
              description: 'زاد هيتابعه معاك كل أسبوع',
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
                'جهّز زاد لبيتك',
                style: ZadType.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'كل حاجة جاهزة! 🎉 جرب تقول لزاد "صرفت ٥٠ بقالة" بالصوت أو من '
            'بوت تليجرام — هيسألك تأكيد ويسجلها.',
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
                    complete ? 'تم' : description,
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
                semanticLabel: 'فتح',
              ),
          ],
        ),
      ),
    );
  }
}
