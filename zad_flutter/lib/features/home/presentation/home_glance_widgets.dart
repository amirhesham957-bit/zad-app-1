/// Three small tiles right under the money: the next subscription, what the
/// pantry is short of, and the next dose (owner, 2026-11-09: a quick look
/// without opening anything). They read the controllers those screens read,
/// and fetch nothing of their own.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/components/zad_card.dart';
import 'package:zad/core/design/components/zad_icon_chip.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/home/presentation/glance_cards.dart'
    show nextDoseOf;
import 'package:zad/shared/inventory/application/pantry_controller.dart';
import 'package:zad/shared/navigation/destinations.dart';
import 'package:zad/shared/navigation/zad_screens.dart';
import 'package:zad/shared/pharmacy/application/pharmacy_controller.dart';
import 'package:zad/shared/subscriptions/application/subscriptions_controller.dart';

/// The row of three tiles.
class HomeGlanceWidgets extends StatelessWidget {
  /// Creates the row.
  const new({super.key});

  @override
  Widget build(BuildContext context) => const IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(child: _SubscriptionsTile()),
        SizedBox(width: ZadSpacing.sm),
        Expanded(child: _PantryTile()),
        SizedBox(width: ZadSpacing.sm),
        Expanded(child: _PharmacyTile()),
      ],
    ),
  );
}

class _SubscriptionsTile extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final view = ref.watch(subscriptionsControllerProvider);
    final active = view.active.toList();
    final next = active.isEmpty ? null : active.first;
    final date = next?.nextRenewalFrom(view.today);
    final days = date?.difference(view.today).inDays;

    return _Tile(
      icon: ZadIcons.card,
      tint: ZadColors.info,
      title: l10n.homeWidgetSubs,
      headline: switch (days) {
        null => l10n.homeWidgetSubsEmpty,
        <= 0 => l10n.homeWidgetSubsToday,
        1 => l10n.homeWidgetSubsTomorrow,
        final d => l10n.homeWidgetSubsInDays(d),
      },
      caption: next?.title,
      isUrgent: days != null && days <= 3,
      onTap: () => ZadScreens.showSubscriptionsScreen(context),
    );
  }
}

class _PantryTile extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final view = ref.watch(pantryControllerProvider);
    final short = view.shortages;

    return _Tile(
      icon: ZadIcons.inventory,
      tint: ZadColors.forestEmerald,
      title: l10n.homeWidgetPantry,
      headline: view.items.isEmpty
          ? l10n.homeWidgetPantryEmpty
          : short.isEmpty
          ? l10n.homeWidgetPantryFine
          : l10n.homeWidgetPantryShort(short.length),
      caption: short.isNotEmpty
          ? short.first.item.itemName
          : view.items.isEmpty
          ? null
          : l10n.homeWidgetPantryCount(view.items.length),
      isUrgent: short.isNotEmpty,
      onTap: () =>
          ZadScreens.showHouseholdSection(context, HouseholdSection.pantry),
    );
  }
}

class _PharmacyTile extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final view = ref.watch(pharmacyControllerProvider);
    final medicines = view.medicines.where((m) => !m.isFinishedCourse).length;
    final next = nextDoseOf(view.today, ref.read(nowProvider)());

    return _Tile(
      icon: ZadIcons.pharmacy,
      tint: ZadColors.terracottaRust,
      title: l10n.homeWidgetPharmacy,
      headline: medicines == 0
          ? l10n.homeWidgetPharmacyEmpty
          : next == null
          ? l10n.homeWidgetPharmacyNone
          : DateFormat.jm(
              context.dateLocale,
            ).format(DateTime(2000, 1, 1, next.time.hour, next.time.minute)),
      caption: next?.medicine.name ??
          (medicines == 0 ? null : l10n.homeWidgetPharmacyActive(medicines)),
      isUrgent: false,
      onTap: () =>
          ZadScreens.showHouseholdSection(context, HouseholdSection.pharmacy),
    );
  }
}

class _Tile extends StatelessWidget {
  const new({
    required this.icon,
    required this.tint,
    required this.title,
    required this.headline,
    required this.caption,
    required this.isUrgent,
    required this.onTap,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final String headline;
  final String? caption;
  final bool isUrgent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ZadCard(
    onTap: onTap,
    padding: const EdgeInsets.all(ZadSpacing.md),
    // Something due soon: a warm wash instead of a drawn border.
    color: isUrgent ? ZadColors.mustardOchre.withValues(alpha: 0.10) : null,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ZadIconChip(icon: icon, tint: tint, size: 32),
        const SizedBox(height: ZadSpacing.sm),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
        ),
        const SizedBox(height: ZadSpacing.xs),
        Text(
          headline,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: ZadType.titleSmall.copyWith(color: ZadColors.ink),
        ),
        if (caption != null)
          Text(
            caption!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
          ),
      ],
    ),
  );
}
