/// «عروض على نواقصك» on home: a sideways bar of picture cards (owner 11/11,
/// replacing 6/11's vertical list: «بار بصور» beside the pantry tiles), at most
/// [homeDealsShown] of them, «شوف الكل» for the rest — the picture, what
/// the home is short of, the store, the price and the saving, the store's
/// discount code (one tap copies it), and «على أمازون», the tagged search
/// (`zad0b-21` amazon.sa, `zad04-21` amazon.eg), labelled «اطلبه من
/// أمازون، يوصلك بسرعة» under the cheapest local store (owner 11/11), and
/// Amazon's Associates disclosure under the list.
/// A tap on the card opens the deal where it was found.
///
/// Reads zad-brain's `home_deals` (no model involved): last answer first
/// from the screen cache, then the server, at most once per
/// [homeDealsRefreshEvery] on re-entry. Nothing to show = no strip.
///
/// Pictures follow the deals page's rule: the YouTube video's thumbnail, the
/// deal page's own preview picture (server-read `og:image`), or Amazon's own
/// photo of the same product from the affiliate catalogue —
/// never a stock photo — else a tile.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zad/core/data/local/screen_cache.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/components/zad_network_image.dart';
import 'package:zad/core/design/foundation/elevation.dart';
import 'package:zad/core/design/foundation/squircle.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_motion.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/nearby/data/deal_signal.dart';
import 'package:zad/features/nearby/domain/home_deals.dart';
import 'package:zad/features/nearby/domain/shein_offers.dart';
import 'package:zad/features/nearby/domain/store_deals.dart';
import 'package:zad/shared/affiliate/data/affiliate_repository.dart';
import 'package:zad/shared/affiliate/domain/affiliate.dart';
import 'package:zad/shared/campaigns/domain/campaign.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/navigation/zad_screens.dart';

/// Rows shown on home; the deals page has the rest.
const int homeDealsShown = 10;

/// How long a fetched strip stays fresh on re-entry.
const Duration homeDealsRefreshEvery = Duration(minutes: 15);

final Map<String, DateTime> _fetchedAt = <String, DateTime>{};

/// When SHEIN's offers were last read, per account and country.
final Map<String, DateTime> _sheinFetchedAt = <String, DateTime>{};

/// The strip.
class HomeDealsCarousel extends ConsumerStatefulWidget {
  /// Creates the strip.
  const new({this.occasion, super.key});

  /// The running occasion, marked beside the title in its own colour.
  final Campaign? occasion;

  @override
  ConsumerState<HomeDealsCarousel> createState() => _HomeDealsCarouselState();
}

class _HomeDealsCarouselState extends ConsumerState<HomeDealsCarousel> {
  List<HomeDeal> _deals = const <HomeDeal>[];
  List<SheinOffer> _shein = const <SheinOffer>[];

  @override
  void initState() {
    super.initState();
    unawaited(Future<void>.microtask(_load));
    unawaited(Future<void>.microtask(_loadShein));
  }

  /// SHEIN's offers for a Gulf account (owner 11/11): a plain read of
  /// `zad_affiliate_offers`, no model, kept on the phone and read again at
  /// most every [homeDealsRefreshEvery] like the deals.
  Future<void> _loadShein() async {
    final country = ref.read(accountCountryProvider)?.toUpperCase();
    if (!sheinMarket(country)) return;
    final client = ref.read(supabaseClientProvider);
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;
    final cache = ref.read(screenCacheProvider);
    final key = 'shein_offers_$country';
    if (cache.read(key, userId) case final cached? when cached.isNotEmpty) {
      if (mounted) setState(() => _shein = sheinOffersFromJson(cached));
    }
    final stamp = '$userId|$country';
    final last = _sheinFetchedAt[stamp];
    if (last != null &&
        DateTime.now().difference(last) < homeDealsRefreshEvery) {
      return;
    }
    try {
      final rows = await client
          .from('zad_affiliate_offers')
          .select('id,title,image_url,affiliate_url,coupon_code')
          .eq('is_active', true)
          .contains('target_countries', <String>[country!])
          .order('created_at', ascending: false)
          .limit(homeDealsShown);
      _sheinFetchedAt[stamp] = DateTime.now();
      unawaited(
        cache.write(key, userId, <Map<String, dynamic>>[
          for (final r in rows) Map<String, dynamic>.from(r),
        ]),
      );
      if (mounted) setState(() => _shein = sheinOffersFromJson(rows));
    } on Object catch (e) {
      debugPrint('shein offers read failed: $e');
    }
  }

  Future<void> _load() async {
    final client = ref.read(supabaseClientProvider);
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;
    final cache = ref.read(screenCacheProvider);
    if (cache.read('home_deals', userId) case [final cached]) {
      if (mounted) {
        setState(() => _deals = cheapestLocalFirst(homeDealsFromJson(cached)));
      }
    }
    final last = _fetchedAt[userId];
    if (last != null &&
        DateTime.now().difference(last) < homeDealsRefreshEvery) {
      return;
    }
    try {
      final raw = (await client.functions.invoke(
        'zad-brain',
        body: const <String, dynamic>{'action': 'home_deals'},
      )).data;
      if (raw is! Map || raw['ok'] != true) return;
      _fetchedAt[userId] = DateTime.now();
      unawaited(
        cache.write('home_deals', userId, <Map<String, dynamic>>[
          Map<String, dynamic>.from(raw),
        ]),
      );
      if (mounted) {
        setState(() => _deals = cheapestLocalFirst(homeDealsFromJson(raw)));
      }
    } on Object catch (e) {
      debugPrint('home deals read failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalogue =
        ref.watch(affiliateProductsProvider).value ??
        const <AffiliateProduct>[];
    final l = context.l10n;
    final shown = _deals.take(homeDealsShown).toList();
    // The local stores and Amazon first, SHEIN after them (Gulf only).
    final shein = _shein.take(homeDealsShown).toList();
    final count = shown.length + shein.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: ZadSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Flexible(
                child: Text(
                  l.homeDealsTitle,
                  style: ZadType.titleLarge.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (widget.occasion case final o?) ...<Widget>[
                const SizedBox(width: ZadSpacing.sm),
                Flexible(child: OccasionMark(campaign: o)),
              ],
              const Spacer(),
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                onPressed: () =>
                    unawaited(ZadScreens.showNearbyDealsScreen(context)),
                child: Text(l.homeDealsSeeAll),
              ),
            ],
          ),
          const SizedBox(height: ZadSpacing.xs),
          if (count == 0)
            // No deals yet: the bar still says where they will come from,
            // instead of vanishing (journey map, 11/11) — one short line, not
            // an empty bar's height.
            const _SearchingCard()
          else
            SizedBox(
              height: HomeDealCard.height,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: count,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: ZadSpacing.md),
                itemBuilder: (_, i) =>
                    (i < shown.length
                            ? HomeDealCard(
                                deal: shown[i],
                                image:
                                    shown[i].photo ??
                                    catalogueImage(shown[i].item, catalogue),
                              )
                            : SheinOfferCard(offer: shein[i - shown.length]))
                        .animate()
                        .fadeIn(
                          duration: ZadDuration.quick,
                          delay: Duration(milliseconds: 40 * i),
                        )
                        .slideX(begin: 0.08, curve: ZadCurves.standard),
              ),
            ),
          // Every card carries «اطلبه من أمازون»; with no card there is no
          // Amazon link on the bar, and the disclosure would describe nothing.
          if (shown.isNotEmpty) ...<Widget>[
            const SizedBox(height: ZadSpacing.sm),
            Text(
              l.amazonAssociatesDisclosure,
              style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
            ),
          ],
          // SHEIN's links earn Zad a commission too; said under them.
          if (shein.isNotEmpty) ...<Widget>[
            const SizedBox(height: ZadSpacing.xs),
            Text(
              l.sheinDisclosure,
              style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
            ),
          ],
        ],
      ),
    );
  }
}

/// The bar before any deal arrives.
class _SearchingCard extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => Material(
    color: ZadColors.mint50,
    shape: zadSquircle(ZadRadii.cardLarge),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => unawaited(ZadScreens.showNearbyDealsScreen(context)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 96),
        child: Padding(
          padding: const EdgeInsets.all(ZadSpacing.lg),
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.travel_explore,
                size: 40,
                color: ZadColors.green700,
              ),
              const SizedBox(width: ZadSpacing.lg),
              Expanded(
                child: Text(
                  context.l10n.homeDealsSearching,
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

/// One deal in the bar: its picture, why it is here, the price, and one row
/// of buttons (the code, Amazon).
class HomeDealCard extends ConsumerWidget {
  /// Creates the card.
  const new({required this.deal, required this.image, super.key});

  /// The card's size in the bar.
  static const double width = 248;

  /// The bar's height: the image, two lines of name, the store, the price
  /// and one row of buttons (11/11: 336 left an empty grey block under one
  /// card).
  static const double height = 284;

  static const double _imageHeight = 104;

  /// The deal.
  final HomeDeal deal;

  /// Its picture, when there is one.
  final String? image;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final tile = Container(
      width: width,
      height: _imageHeight,
      color: ZadColors.mint50,
      alignment: Alignment.center,
      child: const Icon(Icons.local_offer, size: 32, color: ZadColors.green700),
    );
    final saving = deal.saving;
    final before = deal.priceBefore;
    final code = deal.code;
    final url = deal.url;
    return Container(
      width: width,
      // A soft two-layer shadow instead of a grey edge (HOME_REVIEW ٢).
      decoration: ShapeDecoration(
        shape: zadSquircle(ZadRadii.card),
        shadows: ZadElevation.card,
      ),
      child: Material(
        color: ZadColors.surface,
        clipBehavior: Clip.antiAlias,
        shape: zadSquircle(ZadRadii.card),
        child: InkWell(
          onTap: url == null
              ? null
              : () {
                  sendDealOpened(ref, item: deal.item, store: deal.store);
                  unawaited(openAmazonLink(url));
                },
          child: Padding(
            padding: const EdgeInsets.all(ZadSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(ZadRadii.chip),
                      child: Stack(
                        children: <Widget>[
                          if (image == null)
                            tile
                          else
                            ZadNetworkImage(
                              image!,
                              width: width,
                              height: _imageHeight,
                              fit: BoxFit.cover,
                              fallback: tile,
                              semanticLabel: deal.item,
                            ),
                          // Why it is here, on the picture: under the price
                          // it pushed the buttons onto a second row.
                          PositionedDirectional(
                            bottom: ZadSpacing.xs,
                            start: ZadSpacing.xs,
                            child: _Badge(
                              text: switch (deal.why) {
                                HomeDealWhy.need => l.homeDealsWhyNeed,
                                HomeDealWhy.favorite => l.homeDealsWhyFavorite,
                                HomeDealWhy.fire => l.homeDealsWhyFire,
                                HomeDealWhy.want => l.homeDealsWhyWant,
                                HomeDealWhy.season => l.homeDealsWhySeason,
                                HomeDealWhy.top => l.homeDealsWhyTop,
                              },
                              color: ZadColors.green700,
                            ),
                          ),
                          if (saving != null && saving > 0)
                            PositionedDirectional(
                              top: ZadSpacing.xs,
                              start: ZadSpacing.xs,
                              child: _Badge(
                                text: '−${l.dealsPercent('$saving')}',
                                color: ZadColors.terracottaRust,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: ZadSpacing.sm),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: ZadSpacing.xs,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            deal.item,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: ZadType.titleSmall,
                          ),
                          const SizedBox(height: ZadSpacing.xs),
                          Text(
                            deal.store,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ZadType.labelSmall.copyWith(
                              color: ZadColors.inkMuted,
                            ),
                          ),
                          const SizedBox(height: ZadSpacing.sm),
                          Wrap(
                            spacing: ZadSpacing.sm,
                            runSpacing: ZadSpacing.xs,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: <Widget>[
                              Text(
                                '${dealMoney(deal.price)} ${deal.currency}'
                                    .trim(),
                                style: ZadType.titleMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: ZadColors.green700,
                                ),
                              ),
                              if (before != null)
                                Text(
                                  dealMoney(before),
                                  style: ZadType.bodySmall.copyWith(
                                    color: ZadColors.inkMuted,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // One row, pinned to the card's foot so every card in the bar
                // ends on the same line: the code (copied on a tap, its text
                // in the tooltip) and Amazon.
                Row(
                  children: <Widget>[
                    if (code != null) ...<Widget>[
                      IconButton.outlined(
                        constraints: const BoxConstraints.tightFor(
                          width: 44,
                          height: 44,
                        ),
                        tooltip: l.homeDealsCode(code.code),
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: code.code),
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l.dealsCopied(code.code))),
                          );
                        },
                        icon: const Icon(Icons.content_copy, size: 18),
                      ),
                      const SizedBox(width: ZadSpacing.sm),
                    ],
                    Expanded(
                      child: FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(44, 44),
                          shape: const StadiumBorder(),
                        ),
                        onPressed: () =>
                            unawaited(openAmazonSearch(ref, deal.item)),
                        icon: const Icon(
                          Icons.shopping_cart_outlined,
                          size: 18,
                        ),
                        label: Text(
                          l.homeDealsOrderOnAmazon,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const new({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(ZadRadii.chip),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ZadSpacing.sm,
        vertical: ZadSpacing.xs,
      ),
      child: Text(
        text,
        style: ZadType.labelSmall.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

/// One SHEIN offer, the size of a deal card: the picture, the name, SHEIN,
/// a shopper code when the offer has one, and «تسوّق على SHEIN».
class SheinOfferCard extends ConsumerWidget {
  /// Creates the card.
  const new({required this.offer, super.key});

  /// The offer.
  final SheinOffer offer;

  Future<void> _open(WidgetRef ref) async {
    sendDealOpened(ref, item: offer.title, store: 'SHEIN');
    final uri = Uri.parse(offer.url);
    // SHEIN's link opens its app when installed, the browser otherwise.
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } on Object catch (e) {
      debugPrint('shein app failed: $e');
    }
    try {
      await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    } on Object catch (e) {
      debugPrint('shein tab failed: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    const imageHeight = 104.0;
    final tile = Container(
      height: imageHeight,
      color: ZadColors.mint50,
      alignment: Alignment.center,
      child: const Icon(
        Icons.checkroom_outlined,
        size: 32,
        color: ZadColors.green700,
      ),
    );
    final code = offer.code;
    return Container(
      width: HomeDealCard.width,
      decoration: ShapeDecoration(
        shape: zadSquircle(ZadRadii.card),
        shadows: ZadElevation.card,
      ),
      child: Material(
        color: ZadColors.surface,
        clipBehavior: Clip.antiAlias,
        shape: zadSquircle(ZadRadii.card),
        child: InkWell(
          onTap: () => unawaited(_open(ref)),
          child: Padding(
            padding: const EdgeInsets.all(ZadSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(ZadRadii.chip),
                  child: offer.image == null
                      ? tile
                      : ZadNetworkImage(
                          offer.image!,
                          height: imageHeight,
                          fit: BoxFit.cover,
                          fallback: tile,
                          semanticLabel: offer.title,
                        ),
                ),
                const SizedBox(height: ZadSpacing.sm),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ZadSpacing.xs,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        offer.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: ZadType.titleSmall,
                      ),
                      const SizedBox(height: ZadSpacing.xs),
                      Text(
                        'SHEIN', // l10n: data
                        style: ZadType.labelSmall.copyWith(
                          color: ZadColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Row(
                  children: <Widget>[
                    if (code != null) ...<Widget>[
                      IconButton.outlined(
                        constraints: const BoxConstraints.tightFor(
                          width: 44,
                          height: 44,
                        ),
                        tooltip: l.homeDealsCode(code),
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: code));
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l.dealsCopied(code))),
                          );
                        },
                        icon: const Icon(Icons.content_copy, size: 18),
                      ),
                      const SizedBox(width: ZadSpacing.sm),
                    ],
                    Expanded(
                      child: FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(44, 44),
                          shape: const StadiumBorder(),
                        ),
                        onPressed: () => unawaited(_open(ref)),
                        icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                        label: Text(
                          l.sheinShop,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The occasion beside the deals' title: its badge and name in its colour,
/// on a faint wash of it (HOME_REVIEW ٢: the occasion colours the header,
/// the money card's glow and this mark, nothing else).
class OccasionMark extends StatelessWidget {
  /// Creates the mark.
  const new({required this.campaign, super.key});

  /// The occasion.
  final Campaign campaign;

  @override
  Widget build(BuildContext context) {
    final color = Color(campaign.primary);
    final name = (campaign.eventName ?? '').trim();
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ZadSpacing.sm,
        vertical: ZadSpacing.xs,
      ),
      decoration: ShapeDecoration(
        color: color.withValues(alpha: 0.10),
        shape: const StadiumBorder(),
      ),
      child: Text(
        name.isEmpty ? campaign.badge : '${campaign.badge} $name',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: ZadType.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
