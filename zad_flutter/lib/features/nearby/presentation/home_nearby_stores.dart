/// Home's «ماركتات وصيدليات جنبك» bar (ZAD_PLAN ١٠.٨, owner 11/11).
///
/// The shops lived only inside «أماكني». Here they are a sideways row, the
/// way Apple Maps shows "Nearby": a round mark per shop with its first
/// letter in its kind's colour (OpenStreetMap has no pictures), the name and
/// how far it is.
///
/// It reads the kept snapshot only. Opening Home never asks for location and
/// never wakes a radio (NearbyController's rule); the list is taken in
/// «أماكني» on a tap, and this bar shows what that left.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/design/foundation/squircle.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/nearby/data/nearby_repository.dart';
import 'package:zad/shared/navigation/zad_screens.dart';
import 'package:zad/shared/nearby/domain/nearby.dart';

/// How many shops the bar shows.
const int homeNearbyShown = 10;

/// The shops for the bar: both kinds inside the widest radius around the
/// snapshot's point, nearest first, one per name.
List<StoreDistance> homeNearbyStores(NearbySnapshot? snapshot) {
  if (snapshot == null) return const <StoreDistance>[];
  return storesWithin(
    <NearbyStore>[...snapshot.supermarkets, ...snapshot.pharmacies],
    from: snapshot.center,
    radius: NearbyRepository.fetchRadius,
  ).take(homeNearbyShown).toList();
}

/// The bar.
class HomeNearbyStores extends ConsumerWidget {
  /// Creates the bar.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final stores = homeNearbyStores(
      ref.watch(nearbyRepositoryProvider).cached(),
    );
    void open() => unawaited(ZadScreens.showMyPlaces(context));
    return Padding(
      padding: const EdgeInsets.only(bottom: ZadSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  l.homeNearbyTitle,
                  style: ZadType.titleLarge.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                onPressed: open,
                child: Text(l.homeNearbySeeAll),
              ),
            ],
          ),
          const SizedBox(height: ZadSpacing.xs),
          if (stores.isEmpty)
            _FindCard(onTap: open)
          else
            SizedBox(
              height: _StoreMark.height,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: stores.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: ZadSpacing.sm),
                itemBuilder: (_, i) =>
                    _StoreMark(store: stores[i], onTap: open),
              ),
            ),
        ],
      ),
    );
  }
}

/// No shops kept yet: one line that leads to where they are found.
class _FindCard extends StatelessWidget {
  const new({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: ZadColors.mint50,
    shape: zadSquircle(ZadRadii.cardLarge),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 72),
        child: Padding(
          padding: const EdgeInsets.all(ZadSpacing.lg),
          child: Row(
            children: <Widget>[
              Icon(ZadIcons.store, size: 32, color: ZadColors.forestEmerald),
              const SizedBox(width: ZadSpacing.lg),
              Expanded(
                child: Text(
                  context.l10n.homeNearbyFind,
                  style: ZadType.titleSmall,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// One shop: its mark, its name, how far.
class _StoreMark extends StatelessWidget {
  const new({required this.store, required this.onTap});

  static const double height = 124;
  static const double _width = 88;
  static const double _mark = 56;

  final StoreDistance store;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pharmacy = store.store.kind == StoreKind.pharmacy;
    final accent = pharmacy
        ? ZadColors.terracottaRust
        : ZadColors.forestEmerald;
    final name = store.store.name.trim();
    final letter = name.isEmpty ? '' : name.characters.first;
    return SizedBox(
      width: _width,
      child: InkWell(
        onTap: onTap,
        customBorder: zadSquircle(ZadRadii.card),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: ZadSpacing.xs),
          child: Column(
            children: <Widget>[
              Container(
                width: _mark,
                height: _mark,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.12),
                ),
                child: letter.isEmpty
                    ? Icon(
                        pharmacy ? ZadIcons.pharmacy : ZadIcons.store,
                        color: accent,
                      )
                    : Text(
                        letter,
                        style: ZadType.titleLarge.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
              const SizedBox(height: ZadSpacing.sm),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: ZadType.labelMedium,
              ),
              Text(
                formatDistance(store.metres),
                maxLines: 1,
                style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
