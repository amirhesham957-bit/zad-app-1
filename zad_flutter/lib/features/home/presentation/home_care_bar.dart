/// Home's sideways bar of what comes round next: medicines with a dose still
/// to take today, then subscriptions by their next renewal (owner, 2026-11-15).
/// It reads the controllers the glance tiles read and fetches nothing.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/components/zad_card.dart';
import 'package:zad/core/design/components/zad_icon_chip.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_motion.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/home/presentation/glance_cards.dart'
    show nextDoseOf;
import 'package:zad/shared/budget/application/budget_controller.dart';
import 'package:zad/shared/navigation/destinations.dart';
import 'package:zad/shared/navigation/zad_screens.dart';
import 'package:zad/shared/pharmacy/application/pharmacy_controller.dart';
import 'package:zad/shared/pharmacy/domain/dose_slot.dart';
import 'package:zad/shared/subscriptions/application/subscriptions_controller.dart';
import 'package:zad/shared/subscriptions/domain/subscription.dart';
import 'package:zad/shared/subscriptions/presentation/subscription_brands.dart';

/// One entry of the bar, before it is drawn.
sealed class _Entry {
  const new();
}

class _DoseEntry extends _Entry {
  const new(this.slot);
  final DoseSlot slot;
}

class _SubEntry extends _Entry {
  const new(this.sub, this.date);
  final Subscription sub;
  final DateTime? date;
}

/// The bar: title, then one horizontal row of cards.
class HomeCareBar extends ConsumerWidget {
  /// Creates the bar.
  const new({super.key});

  /// Whether the chips keep moving. Widget tests turn it off: a loop never
  /// lets `pumpAndSettle` finish.
  static bool loops = true;

  /// The card's width and height.
  static const double cardWidth = 156;

  /// The card height.
  static const double cardHeight = 128;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pharmacy = ref.watch(pharmacyControllerProvider);
    final subs = ref.watch(subscriptionsControllerProvider);
    final now = ref.read(nowProvider)();

    // One card per medicine: its next dose still open today, soonest first.
    final doses = <_DoseEntry>[];
    final seen = <String>{};
    final slots = <DoseSlot>[...pharmacy.today]
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    for (final slot in slots) {
      if (seen.contains(slot.medicine.id)) continue;
      final next = nextDoseOf(
        slots.where((s) => s.medicine.id == slot.medicine.id).toList(),
        now,
      );
      if (next != null) {
        seen.add(slot.medicine.id);
        doses.add(_DoseEntry(next));
      }
    }
    doses.sort((a, b) => a.slot.scheduledAt.compareTo(b.slot.scheduledAt));

    final renewals =
        <_SubEntry>[
            for (final s in subs.active)
              _SubEntry(s, s.nextRenewalFrom(subs.today)),
          ]
          // Rows with no readable date go last; the sort is stable otherwise.
          ..sort((a, b) {
            if (a.date == null || b.date == null) {
              return a.date == null ? (b.date == null ? 0 : 1) : -1;
            }
            return a.date!.compareTo(b.date!);
          });

    final entries = <_Entry>[...doses, ...renewals];
    if (entries.isEmpty) return const SizedBox.shrink();

    final l10n = context.l10n;
    final currency = ref.watch(
      budgetControllerProvider.select((v) => v.snapshot?.currency ?? ''),
    );
    final animate = !MediaQuery.disableAnimationsOf(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: ZadSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: ZadSpacing.sm),
            child: Text(
              l10n.homeCareTitle,
              style: ZadType.titleLarge.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          SizedBox(
            height: cardHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(width: ZadSpacing.sm),
              itemBuilder: (context, i) {
                final card = switch (entries[i]) {
                  _DoseEntry(:final slot) => _DoseCard(
                    slot: slot,
                    now: now,
                    phase: i,
                  ),
                  _SubEntry(:final sub, :final date) => _SubCard(
                    sub: sub,
                    days: date?.difference(subs.today).inDays,
                    currency: currency,
                    phase: i,
                  ),
                };
                if (!animate) return card;
                // Staggered: each card a beat after the one before it.
                return card
                    .animate(delay: ZadDuration.quick * math.min(i, 6))
                    .fadeIn(
                      duration: ZadDuration.enter,
                      curve: ZadCurves.standard,
                    )
                    .slideX(
                      begin: 0.2,
                      end: 0,
                      duration: ZadDuration.enter,
                      curve: ZadCurves.standard,
                    );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DoseCard extends StatelessWidget {
  const new({required this.slot, required this.now, required this.phase});

  final DoseSlot slot;
  final DateTime now;
  final int phase;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final due = slot.stateAt(now) == DoseState.due;
    final time = DateFormat.jm(context.dateLocale)
        .format(DateTime(2000, 1, 1, slot.time.hour, slot.time.minute));
    return _CareCard(
      onTap: () => unawaited(
        ZadScreens.showHouseholdSection(context, HouseholdSection.pharmacy),
      ),
      highlight: due,
      chip: _IdleChip(
        phase: phase,
        kind: _Idle.bob,
        child: ZadIconChip(
          icon: ZadIcons.pharmacy,
          tint: ZadColors.terracottaRust,
        ),
      ),
      title: slot.medicine.name,
      line: due ? l10n.homeCareDoseNow : l10n.homeCareDoseAt(time),
      lineColor: due ? ZadColors.terracottaRust : null,
    );
  }
}

class _SubCard extends StatelessWidget {
  const new({
    required this.sub,
    required this.days,
    required this.currency,
    required this.phase,
  });

  final Subscription sub;
  final int? days;
  final String currency;
  final int phase;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brand = subscriptionBrandFor(sub.title, sub.provider);
    final d = days;
    final soon = d != null && d <= 3;
    final amount = NumberFormat('#,##0.##', 'en').format(sub.amount);
    return _CareCard(
      onTap: () => unawaited(ZadScreens.showSubscriptionsScreen(context)),
      highlight: soon,
      chip: _IdleChip(
        phase: phase,
        kind: _Idle.turn,
        child: ZadIconChip(
          icon: brand?.icon ?? ZadIcons.card,
          tint: brand?.color ?? ZadColors.info,
        ),
      ),
      title: sub.title,
      line: switch (d) {
        null => '',
        <= 0 => l10n.homeCareRenewsToday,
        1 => l10n.homeCareRenewsTomorrow,
        final n => l10n.homeCareRenewsInDays(n),
      },
      lineColor: soon ? ZadColors.terracottaRust : null,
      trailing: '$amount $currency'.trim(),
    );
  }
}

class _CareCard extends StatelessWidget {
  const new({
    required this.onTap,
    required this.highlight,
    required this.chip,
    required this.title,
    required this.line,
    this.lineColor,
    this.trailing,
  });

  final VoidCallback onTap;
  final bool highlight;
  final Widget chip;
  final String title;
  final String line;
  final Color? lineColor;
  final String? trailing;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: HomeCareBar.cardWidth,
    child: ZadCard(
      onTap: onTap,
      padding: const EdgeInsets.all(ZadSpacing.md),
      color: highlight ? ZadColors.mustardOchre.withValues(alpha: 0.10) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          chip,
          const SizedBox(height: ZadSpacing.sm),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ZadType.titleSmall.copyWith(
              color: ZadColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (line.isNotEmpty)
            Text(
              line,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ZadType.labelMedium.copyWith(
                color: lineColor ?? ZadColors.inkMuted,
                fontWeight: lineColor == null ? null : FontWeight.w700,
              ),
            ),
          if (trailing != null)
            Text(
              trailing!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ZadType.labelMedium.copyWith(color: ZadColors.inkMuted),
            ),
        ],
      ),
    ),
  );
}

enum _Idle { bob, turn }

/// A chip with a gentle idle motion: a pill that bobs, icon that tilts
/// once every few seconds. Still when animations are off.
class _IdleChip extends StatefulWidget {
  const new({required this.child, required this.kind, required this.phase});

  final Widget child;
  final _Idle kind;
  final int phase;

  @override
  State<_IdleChip> createState() => _IdleChipState();
}

class _IdleChipState extends State<_IdleChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: ZadDuration.ambient,
    value: (widget.phase % 4) / 4,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (HomeCareBar.loops && !MediaQuery.disableAnimationsOf(context)) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    child: widget.child,
    builder: (context, child) => switch (widget.kind) {
      _Idle.bob => Transform.translate(
        offset: Offset(0, -2.5 * math.sin(_c.value * 2 * math.pi)),
        child: child,
      ),
      // A quick tilt-and-back in the first 40% of the loop, then rest.
      _Idle.turn => Transform.rotate(
        angle: 0.16 * math.sin(2 * math.pi * (_c.value / 0.4).clamp(0.0, 1.0)),
        child: child,
      ),
    },
  );
}
