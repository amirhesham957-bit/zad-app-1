/// «عروضي» — every offer that is running for the customer in one world: the
/// partner coupons for the account's country, the discounts their own
/// notifications carried, and the way into the nearby shops' deals. A code is
/// one tap to copy; an offer with a link opens it. Nothing here calls a model
/// and nothing is written: the server fills both tables.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:url_launcher/url_launcher.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/components/zad_empty_state.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/design/tokens/zad_world_colors.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/offers/application/offers_controller.dart';
import 'package:zad/features/offers/domain/offers.dart';
import 'package:zad/features/offers/presentation/offers_scene.dart';
import 'package:zad/shared/navigation/zad_screens.dart';
import 'package:zad/shared/worlds/art/art.dart';
import 'package:zad/shared/worlds/world_card.dart';
import 'package:zad/shared/worlds/world_row.dart';
import 'package:zad/shared/worlds/world_scaffold.dart';
import 'package:zad/shared/worlds/zad_world.dart';

/// Opens the screen.
Future<void> showOffersScreen(BuildContext context) => Navigator.of(context)
    .push<void>(MaterialPageRoute<void>(builder: (_) => const OffersScreen()));

/// The screen: the world over the controller's state.
class OffersScreen extends ConsumerWidget {
  /// Creates the screen.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(offersControllerProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: OffersWorld(
        partner: s.partner,
        mine: s.mine,
        loading: s.loading,
        now: ref.watch(nowProvider)(),
        onRefresh: ref.read(offersControllerProvider.notifier).refresh,
        onOpenNearby: () =>
            unawaited(ZadScreens.showNearbyDealsScreen(context)),
        onOpenLink: (url) => unawaited(_open(context, url)),
      ),
    );
  }

  Future<void> _open(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final failed = context.l10n.offersOpenFailed;
    try {
      if (await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } on Object catch (e) {
      debugPrint('offer link failed: $e');
    }
    messenger?.showSnackBar(SnackBar(content: Text(failed)));
  }
}

/// The world over plain data, so a test can feed it directly.
class OffersWorld extends StatelessWidget {
  /// Creates the world.
  const new({
    required this.partner,
    required this.mine,
    required this.loading,
    required this.now,
    required this.onRefresh,
    required this.onOpenNearby,
    required this.onOpenLink,
    super.key,
  });

  /// Partner offers for the account's country.
  final List<Offer> partner;

  /// Offers from the customer's own notifications.
  final List<Offer> mine;

  /// No answer yet.
  final bool loading;

  /// The clock.
  final DateTime now;

  /// Pull-to-refresh.
  final Future<void> Function() onRefresh;

  /// The nearby deals row.
  final VoidCallback onOpenNearby;

  /// An offer with a link was tapped.
  final void Function(String url) onOpenLink;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final liveMine = mine.where((o) => o.liveAt(now)).toList();
    final livePartner = partner.where((o) => o.liveAt(now)).toList();
    final total = liveMine.length + livePartner.length;
    return ZadWorldScaffold(
      world: ZadWorld.offers,
      eyebrow: liveMine.isEmpty ? null : l.offersEyebrowMine(liveMine.length),
      title: l.worldLabelOffers,
      stateLine: total == 0 ? l.offersStateEmpty : l.offersStateCount(total),
      scene: (loop) => OffersWorldScene(loop, live: total > 0),
      zado: const ZadWorldZado(left: 30, top: 50),
      onRefresh: onRefresh,
      slivers: <Widget>[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            ZadSpacing.gutter,
            ZadSpacing.md,
            ZadSpacing.gutter,
            0,
          ),
          sliver: SliverList.list(
            children: <Widget>[
              if (loading && total == 0)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (total == 0)
                ZadEmptyState(
                  icon: ZadIcons.prices,
                  title: l.offersEmptyTitle,
                  message: l.offersEmptyMessage,
                ),
              if (liveMine.isNotEmpty) ..._section(l.offersMineTitle, liveMine),
              if (livePartner.isNotEmpty)
                ..._section(l.offersPartnerTitle, livePartner),
              const SizedBox(height: ZadSpacing.md),
              ZadWorldCard(
                onTap: onOpenNearby,
                child: ZadWorldRow(
                  leading: ZadWorldTile(
                    color: ZadWorldColors.offers,
                    child: ZadArt.icon(ZadIconArt.pin, size: 30),
                  ),
                  title: l.offersNearbyTitle,
                  subtitle: l.offersNearbyMessage,
                  stateColor: ZadColors.inkMuted,
                  trailing: const Icon(ZadIcons.forward),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _section(String title, List<Offer> offers) => <Widget>[
    Padding(
      padding: const EdgeInsets.only(top: ZadSpacing.md, bottom: ZadSpacing.sm),
      child: Text(title, style: ZadType.titleSmall),
    ),
    ZadWorldCard(
      child: Column(
        children: <Widget>[
          for (final (i, o) in offers.indexed) ...<Widget>[
            if (i > 0) const ZadWorldDivider(),
            _OfferRow(offer: o, now: now, onOpenLink: onOpenLink),
          ],
        ],
      ),
    ),
  ];
}

const List<Color> _tints = <Color>[
  Color(0xFFE5473C),
  Color(0xFFF5B93A),
  Color(0xFF0F9B76),
  Color(0xFF3B82F6),
  ZadWorldColors.offers,
];

class _OfferRow extends StatelessWidget {
  const new({required this.offer, required this.now, required this.onOpenLink});

  final Offer offer;
  final DateTime now;
  final void Function(String url) onOpenLink;

  String _title(ZadL10n l) {
    if (offer.title.isNotEmpty) return offer.title;
    final fmt = NumberFormat('#,##0.##');
    if (offer.percent case final p? when p > 0) {
      return l.offersPercentOff(fmt.format(p));
    }
    if (offer.amount case final a? when a > 0) {
      return l.offersAmountOff(fmt.format(a), offer.currency ?? '');
    }
    return l.offersFallbackTitle;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final days = offer.daysLeft(now);
    final expiry = switch (days) {
      null => null,
      0 => l.offersExpiresToday,
      final d => l.offersExpiresInDays(d),
    };
    final tint = _tints[offer.store.hashCode.abs() % _tints.length];
    final link = offer.link;
    return ZadWorldRow(
      leading: ZadWorldTile(
        color: tint,
        child: ZadArt.icon(ZadIconArt.store, size: 30),
      ),
      title: offer.store,
      subtitle: expiry == null ? _title(l) : '${_title(l)} — $expiry',
      stateColor: days != null && days <= 1
          ? ZadColors.terracottaRust
          : ZadColors.inkMuted,
      onTap: link == null ? null : () => onOpenLink(link),
      trailing: _CodeButton(code: offer.code),
    );
  }
}

class _CodeButton extends StatelessWidget {
  const new({required this.code});

  final String? code;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = code;
    if (c == null) {
      return Text(
        l.offersNoCode,
        style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
      );
    }
    return Semantics(
      button: true,
      label: '${l.offersCopy} $c',
      excludeSemantics: true,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: ZadSpacing.md),
        ),
        onPressed: () {
          unawaited(Clipboard.setData(ClipboardData(text: c)));
          unawaited(HapticFeedback.selectionClick());
          ScaffoldMessenger.maybeOf(context)
              ?.showSnackBar(SnackBar(content: Text(l.offersCopied(c))));
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              c,
              style: ZadType.labelSmall,
              textDirection: TextDirection.ltr,
            ),
            Text(l.offersCopy, style: ZadType.labelSmall),
          ],
        ),
      ),
    );
  }
}
