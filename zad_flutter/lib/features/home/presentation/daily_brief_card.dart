/// «موجز زاد النهارده» — the top of زاد's home (daily_brief.dart).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/features/home/domain/daily_brief.dart';
import 'package:zad/shared/budget/application/budget_controller.dart';
import 'package:zad/shared/inventory/application/pantry_controller.dart';
import 'package:zad/shared/navigation/destinations.dart';
import 'package:zad/shared/navigation/shell_navigation.dart';
import 'package:zad/shared/navigation/zad_screens.dart';
import 'package:zad/shared/pharmacy/application/pharmacy_controller.dart';
import 'package:zad/shared/subscriptions/application/subscriptions_controller.dart';

/// The card.
class DailyBriefCard extends ConsumerWidget {
  /// Creates the card.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pantry = ref.watch(pantryControllerProvider).items;
    final doses = ref.watch(pharmacyControllerProvider).today;
    final subs = ref.watch(subscriptionsControllerProvider);
    final budget = ref.watch(budgetControllerProvider);
    final items = dailyBrief(
      pantry: pantry,
      doses: doses,
      subscriptions: subs.items,
      today: subs.today,
      now: ref.read(nowProvider)(),
      spendable: budget.snapshot == null ? null : budget.spendable,
      currency: budget.snapshot?.currency ?? '',
    );

    void open(ShellTab tab) =>
        ref.read(shellNavigationProvider.notifier).open(tab);

    void tap(BriefItem item) => switch (item.kind) {
      BriefKind.doseDue || BriefKind.dosesMissed => unawaited(
        ZadScreens.showHouseholdSection(context, HouseholdSection.pharmacy),
      ),
      BriefKind.overspent || BriefKind.renewal => open(ShellTab.money),
      BriefKind.shortage => open(ShellTab.household),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: ZadColors.surface,
        borderRadius: BorderRadius.circular(ZadRadii.card),
        border: Border.all(color: ZadColors.outline.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(ZadSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(ZadIcons.brain, color: ZadColors.forestEmerald),
                const SizedBox(width: ZadSpacing.sm),
                Expanded(
                  child: Text(
                    'موجز زاد النهارده',
                    style: ZadType.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => open(ShellTab.assistant),
                  child: const Text('عقل زاد'),
                ),
              ],
            ),
            const SizedBox(height: ZadSpacing.sm),
            if (items.isEmpty)
              Text(
                'كله تمام — مفيش حاجة مستعجلة النهارده.',
                style: ZadType.bodyMedium.copyWith(color: ZadColors.inkMuted),
              )
            else
              for (final item in items)
                _Line(
                  item: item,
                  onTap: () => tap(item),
                  onTake: item.dose == null
                      ? null
                      : () => unawaited(
                          ref
                              .read(pharmacyControllerProvider.notifier)
                              .take(item.dose!),
                        ),
                ),
            const SizedBox(height: ZadSpacing.sm),
            OutlinedButton.icon(
              onPressed: () => open(ShellTab.chat),
              icon: const Icon(ZadIcons.assistant, size: 18),
              label: const Text('اسأل زاد عن أي حاجة'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 44),
                shape: const StadiumBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const new({required this.item, required this.onTap, this.onTake});

  final BriefItem item;
  final VoidCallback onTap;
  final VoidCallback? onTake;

  (IconData, Color) get _look => switch (item.kind) {
    BriefKind.doseDue => (ZadIcons.pharmacy, ZadColors.terracottaRust),
    BriefKind.dosesMissed => (ZadIcons.pharmacy, ZadColors.mustardOchre),
    BriefKind.overspent => (ZadIcons.budget, ZadColors.terracottaRust),
    BriefKind.renewal => (ZadIcons.card, ZadColors.info),
    BriefKind.shortage => (ZadIcons.shopping, ZadColors.forestEmerald),
  };

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _look;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ZadRadii.card),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: ZadSpacing.xs),
          child: Row(
            children: <Widget>[
              Icon(icon, color: color, size: 20),
              const SizedBox(width: ZadSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.title,
                      style: ZadType.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      item.detail,
                      style: ZadType.bodySmall.copyWith(
                        color: ZadColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTake != null)
                FilledButton(
                  onPressed: onTake,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text('خدتها'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
