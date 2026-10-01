/// The lines of «موجز زاد النهارده» (daily_brief.dart): what needs the
/// customer now, each opening where it is handled. Home shows the first few;
/// «نصايح زاد» shows them all.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/shared/brain/domain/daily_brief.dart';
import 'package:zad/shared/budget/application/budget_controller.dart';
import 'package:zad/shared/inventory/application/pantry_controller.dart';
import 'package:zad/shared/navigation/destinations.dart';
import 'package:zad/shared/navigation/shell_navigation.dart';
import 'package:zad/shared/navigation/zad_screens.dart';
import 'package:zad/shared/pharmacy/application/pharmacy_controller.dart';
import 'package:zad/shared/subscriptions/application/subscriptions_controller.dart';

/// The brief as it stands, from what is on the device — no model call.
List<BriefItem> watchDailyBrief(WidgetRef ref, {int max = 5}) {
  final pantry = ref.watch(pantryControllerProvider).items;
  final doses = ref.watch(pharmacyControllerProvider).today;
  final subs = ref.watch(subscriptionsControllerProvider);
  final budget = ref.watch(budgetControllerProvider);
  return dailyBrief(
    pantry: pantry,
    doses: doses,
    subscriptions: subs.items,
    today: subs.today,
    now: ref.read(nowProvider)(),
    spendable: budget.snapshot == null ? null : budget.spendable,
    currency: budget.snapshot?.currency ?? '',
    max: max,
  );
}

/// The brief's lines, or [empty] when nothing needs the customer.
class DailyBriefLines extends ConsumerWidget {
  /// Creates the lines.
  const new({required this.empty, this.max = 5, super.key});

  /// At most this many lines.
  final int max;

  /// Shown when there is nothing.
  final Widget empty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = watchDailyBrief(ref, max: max);
    if (items.isEmpty) return empty;

    // A tab lies under whatever was pushed over the shell («نصايح زاد»):
    // back to the shell first, or the tab changes out of sight.
    void open(ShellTab tab) {
      Navigator.of(context).popUntil((r) => r.isFirst);
      ref.read(shellNavigationProvider.notifier).open(tab);
    }

    void tap(BriefItem item) => switch (item.kind) {
      BriefKind.doseDue || BriefKind.dosesMissed => unawaited(
        ZadScreens.showHouseholdSection(context, HouseholdSection.pharmacy),
      ),
      BriefKind.overspent || BriefKind.renewal => open(ShellTab.money),
      BriefKind.shortage => open(ShellTab.household),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
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
      ],
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
