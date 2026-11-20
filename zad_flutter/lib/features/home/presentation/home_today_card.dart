/// «النهارده في بيتك»: what asks for the customer today, as one calm card —
/// what the home is short of, the doses still open, the subscriptions about
/// to renew. Each row opens its own world; with nothing due the card says so.
/// It reads the controllers those worlds read and fetches nothing itself.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/components/zad_empty_state.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/home/presentation/glance_cards.dart'
    show canTakeAt;
import 'package:zad/shared/inventory/application/pantry_controller.dart';
import 'package:zad/shared/inventory/application/shopping_controller.dart';
import 'package:zad/shared/navigation/destinations.dart';
import 'package:zad/shared/navigation/zad_screens.dart';
import 'package:zad/shared/pharmacy/application/pharmacy_controller.dart';
import 'package:zad/shared/pharmacy/domain/dose_slot.dart';
import 'package:zad/shared/subscriptions/application/subscriptions_controller.dart';
import 'package:zad/shared/worlds/art/zad_art.dart';
import 'package:zad/shared/worlds/art/zad_art_kinds.dart';
import 'package:zad/shared/worlds/world_card.dart';
import 'package:zad/shared/worlds/world_row.dart';
import 'package:zad/shared/worlds/zad_world.dart';

/// How many dose and renewal rows the card shows before the world itself.
const int kHomeTodayRows = 3;

/// The card.
class HomeTodayCard extends ConsumerWidget {
  /// Creates the card.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final now = ref.read(nowProvider)();
    final short = ref.watch(
      pantryControllerProvider.select((v) => v.shortages),
    );
    final toBuy = ref.watch(
      shoppingControllerProvider.select((v) => v.outstanding),
    );
    final doseSlots = ref.watch(
      pharmacyControllerProvider.select((v) => v.today),
    );
    final subs = ref.watch(subscriptionsControllerProvider);

    final doses = <DoseSlot>[
      for (final s in doseSlots)
        if (!s.isTaken && s.stateAt(now) != DoseState.missed) s,
    ]..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    final renewals = <(String, int)>[];
    for (final s in subs.active) {
      final next = s.nextRenewalFrom(subs.today);
      if (next == null) continue;
      final days = next.difference(subs.today).inDays;
      if (days >= 0 && days <= 7) renewals.add((s.title, days));
    }
    renewals.sort((a, b) => a.$2.compareTo(b.$2));

    final rows = <Widget>[
      if (short.isNotEmpty)
        _row(
          world: ZadWorld.inv,
          art: ZadIconArt.pantry,
          title: l10n.homeTodayShortTitle,
          line: l10n.homeTodayShortSub(short.first.item.itemName, short.length),
          urgent: true,
          onTap: () =>
              ZadScreens.showHouseholdSection(context, HouseholdSection.pantry),
        ),
      if (toBuy.isNotEmpty)
        _row(
          world: ZadWorld.shop,
          art: ZadIconArt.cart,
          title: l10n.homeWidgetShortages,
          line: l10n.homeTodayShortSub(toBuy.first.itemName, toBuy.length),
          onTap: () => ZadScreens.showHouseholdSection(
            context,
            HouseholdSection.shopping,
          ),
        ),
      for (final d in doses.take(kHomeTodayRows))
        _row(
          world: ZadWorld.ph,
          art: ZadIconArt.pill,
          title: d.medicine.name,
          line: canTakeAt(d, now) && d.stateAt(now) == DoseState.due
              ? l10n.homeCareDoseNow
              : l10n.homeCareDoseAt(
                  DateFormat.jm(context.dateLocale)
                      .format(DateTime(2000, 1, 1, d.time.hour, d.time.minute)),
                ),
          urgent: d.stateAt(now) == DoseState.due,
          onTap: () => ZadScreens.showHouseholdSection(
            context,
            HouseholdSection.pharmacy,
          ),
        ),
      for (final (title, days) in renewals.take(kHomeTodayRows))
        _row(
          world: ZadWorld.subs,
          art: ZadIconArt.repeat,
          title: title,
          line: switch (days) {
            0 => l10n.homeCareRenewsToday,
            1 => l10n.homeCareRenewsTomorrow,
            final d => l10n.homeCareRenewsInDays(d),
          },
          urgent: days <= 1,
          onTap: () => ZadScreens.showSubscriptionsScreen(context),
        ),
    ];

    return ZadWorldCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.homeTodayTitle,
            style: ZadType.titleMedium.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: ZadSpacing.sm),
          if (rows.isEmpty)
            ZadEmptyState(
              icon: Icons.check_circle_outline_rounded,
              title: l10n.homeTodayEmpty,
              message: l10n.homeTodayEmptyHint,
            )
          else
            for (var i = 0; i < rows.length; i++) ...<Widget>[
              if (i > 0) const ZadWorldDivider(),
              rows[i],
            ],
        ],
      ),
    );
  }

  Widget _row({
    required ZadWorld world,
    required ZadIconArt art,
    required String title,
    required String line,
    required VoidCallback onTap,
    bool urgent = false,
  }) => ZadWorldRow(
    leading: ZadWorldTile(
      color: world.color,
      child: ZadArt.icon(art, size: 28),
    ),
    title: title,
    subtitle: line,
    stateColor: urgent ? ZadColors.terracottaRust : world.color,
    onTap: () => unawaited(Future<void>.sync(onTap)),
  );
}
