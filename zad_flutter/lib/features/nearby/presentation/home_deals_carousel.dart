/// «عروض على نواقصك» on home (owner 4/11): a vertical list of deal rows inside
/// the page (owner 6/11: a list, not a sideways strip), at most
/// [homeDealsShown] of them, «شوف الكل» for the rest — the picture, what
/// the home is short of, the store, the price and the saving, the store's
/// discount code (one tap copies it), and «على أمازون», the tagged search
/// (`zad0b-21` amazon.sa, `zad04-21` amazon.eg).
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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/local/screen_cache.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/components/zad_network_image.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/nearby/domain/home_deals.dart';
import 'package:zad/features/nearby/domain/store_deals.dart';
import 'package:zad/shared/affiliate/data/affiliate_repository.dart';
import 'package:zad/shared/affiliate/domain/affiliate.dart';
import 'package:zad/shared/navigation/zad_screens.dart';

/// Rows shown on home; the deals page has the rest.
const int homeDealsShown = 4;

/// How long a fetched strip stays fresh on re-entry.
const Duration homeDealsRefreshEvery = Duration(minutes: 15);

final Map<String, DateTime> _fetchedAt = <String, DateTime>{};

/// The strip.
class HomeDealsCarousel extends ConsumerStatefulWidget {
  /// Creates the strip.
  const new({super.key});

  @override
  ConsumerState<HomeDealsCarousel> createState() => _HomeDealsCarouselState();
}

class _HomeDealsCarouselState extends ConsumerState<HomeDealsCarousel> {
  List<HomeDeal> _deals = const <HomeDeal>[];

  @override
  void initState() {
    super.initState();
    unawaited(Future<void>.microtask(_load));
  }

  Future<void> _load() async {
    final client = ref.read(supabaseClientProvider);
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;
    final cache = ref.read(screenCacheProvider);
    if (cache.read('home_deals', userId) case [final cached]) {
      if (mounted) setState(() => _deals = homeDealsFromJson(cached));
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
      if (mounted) setState(() => _deals = homeDealsFromJson(raw));
    } on Object catch (e) {
      debugPrint('home deals read failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_deals.isEmpty) return const SizedBox.shrink();
    final catalogue =
        ref.watch(affiliateProductsProvider).value ??
        const <AffiliateProduct>[];
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: ZadSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.local_offer, color: ZadColors.green700),
              const SizedBox(width: ZadSpacing.sm),
              Expanded(
                child: Text(
                  l.homeDealsTitle,
                  style: ZadType.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                onPressed: () =>
                    unawaited(ZadScreens.showNearbyDealsScreen(context)),
                child: Text(l.homeDealsSeeAll),
              ),
            ],
          ),
          const SizedBox(height: ZadSpacing.xs),
          for (
            var i = 0;
            i < _deals.length && i < homeDealsShown;
            i++
          ) ...<Widget>[
            if (i > 0) const SizedBox(height: ZadSpacing.sm),
            _DealCard(
              deal: _deals[i],
              image:
                  _deals[i].photo ?? catalogueImage(_deals[i].item, catalogue),
            ),
          ],
        ],
      ),
    );
  }
}

class _DealCard extends ConsumerWidget {
  const new({required this.deal, required this.image});

  static const double _imageSize = 96;

  final HomeDeal deal;
  final String? image;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final tile = Container(
      width: _imageSize,
      height: _imageSize,
      color: ZadColors.mint50,
      alignment: Alignment.center,
      child: const Icon(Icons.local_offer, size: 32, color: ZadColors.green700),
    );
    final saving = deal.saving;
    final before = deal.priceBefore;
    final code = deal.code;
    final url = deal.url;
    return Material(
      color: ZadColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ZadRadii.card),
        side: BorderSide(color: ZadColors.outline.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        onTap: url == null ? null : () => unawaited(openAmazonLink(url)),
        child: Padding(
          padding: const EdgeInsets.all(ZadSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                            width: _imageSize,
                            height: _imageSize,
                            fit: BoxFit.cover,
                            fallback: tile,
                            semanticLabel: deal.item,
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
                  const SizedBox(width: ZadSpacing.md),
                  Expanded(
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
                            _Badge(
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
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ZadSpacing.sm),
              Wrap(
                spacing: ZadSpacing.sm,
                runSpacing: ZadSpacing.sm,
                alignment: WrapAlignment.end,
                children: <Widget>[
                  if (code != null)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(44, 44),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: code.code));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l.dealsCopied(code.code))),
                        );
                      },
                      icon: const Icon(Icons.content_copy, size: 16),
                      label: Text(
                        l.homeDealsCode(code.code),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: () =>
                        unawaited(openAmazonSearch(ref, deal.item)),
                    icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                    label: Text(l.dealsOnAmazon),
                  ),
                ],
              ),
            ],
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
