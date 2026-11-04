/// «العروض» — what Zad found this week for the account's country: store
/// deals with their picture, discount codes from stores' and delivery apps'
/// posts, and on every deal a tagged Amazon search (the affiliate profile:
/// `zad0b-21` on amazon.sa, `zad04-21` on amazon.eg).
///
/// Reads `zad_my_deals()`; last time's answer shows first (screen cache).
/// Never an LLM call: the deals were found by the weekly runs on the server.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/local/screen_cache.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/components/zad_card.dart';
import 'package:zad/core/design/components/zad_empty_state.dart';
import 'package:zad/core/design/components/zad_network_image.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/nearby/domain/store_deals.dart';
import 'package:zad/shared/affiliate/data/affiliate_repository.dart';
import 'package:zad/shared/affiliate/domain/affiliate.dart';

/// The list.
class DealsView extends ConsumerStatefulWidget {
  /// Creates the list.
  const new({super.key});

  @override
  ConsumerState<DealsView> createState() => _DealsViewState();
}

class _DealsViewState extends ConsumerState<DealsView> {
  MyDeals _data = noDeals;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(Future<void>.microtask(_load));
  }

  Future<void> _load() async {
    final client = ref.read(supabaseClientProvider);
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final cache = ref.read(screenCacheProvider);
    if (_loading) {
      if (cache.read('deals', userId) case [final cached]) {
        setState(() {
          _data = myDealsFromJson(cached);
          _loading = false;
        });
      }
    }
    try {
      final raw = await client.rpc<dynamic>('zad_my_deals');
      if (raw is Map) {
        unawaited(
          cache.write('deals', userId, <Map<String, dynamic>>[
            Map<String, dynamic>.from(raw),
          ]),
        );
      }
      if (!mounted) return;
      setState(() {
        _data = myDealsFromJson(raw);
        _loading = false;
        _failed = false;
      });
    } on Object catch (e) {
      debugPrint('deals read failed: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = _data.deals.isEmpty && _data.codes.isEmpty;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final catalogue =
        ref.watch(affiliateProductsProvider).value ??
        const <AffiliateProduct>[];
    final country = _data.country;
    final empty = _data.deals.isEmpty && _data.codes.isEmpty;
    final l = context.l10n;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(ZadSpacing.lg),
        children: <Widget>[
          if (empty)
            ZadEmptyState(
              icon: _failed ? Icons.wifi_off : Icons.local_offer_outlined,
              title: _failed ? l.dealsFailedTitle : l.dealsEmptyTitle,
              message: _failed ? l.dealsFailedBody : l.dealsEmptyBody,
            ),
          if (_data.codes.isNotEmpty) ...<Widget>[
            Text(l.dealsCodesHeader, style: ZadType.titleMedium),
            const SizedBox(height: ZadSpacing.sm),
            for (final c in _data.codes) ...<Widget>[
              _CodeCard(code: c),
              const SizedBox(height: ZadSpacing.sm),
            ],
            const SizedBox(height: ZadSpacing.lg),
          ],
          if (_data.deals.isNotEmpty) ...<Widget>[
            Text(l.dealsStoresHeader, style: ZadType.titleMedium),
            const SizedBox(height: ZadSpacing.sm),
            for (final d in _data.deals) ...<Widget>[
              _DealCard(
                deal: d,
                image: dealImage(d, catalogue),
                country: country,
              ),
              const SizedBox(height: ZadSpacing.sm),
            ],
          ],
          const SizedBox(height: ZadSpacing.md),
          Text(
            l.dealsFootnote,
            style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _DealCard extends ConsumerWidget {
  const new({required this.deal, required this.image, required this.country});

  final StoreDeal deal;
  final String? image;
  final String? country;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tile = Container(
      width: 72,
      height: 72,
      color: ZadColors.mint50,
      alignment: Alignment.center,
      child: const Icon(Icons.local_offer, color: ZadColors.green700),
    );
    final l = context.l10n;
    return ZadCard(
      onTap: () => openAmazonLink(deal.url),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(ZadSpacing.md),
            child: image == null
                ? tile
                : ZadNetworkImage(
                    image!,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    fallback: tile,
                    semanticLabel: deal.item,
                  ),
          ),
          const SizedBox(width: ZadSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(deal.item, style: ZadType.titleSmall),
                const SizedBox(height: ZadSpacing.xs),
                Text(_priceLine(l, deal), style: ZadType.bodyMedium),
                const SizedBox(height: ZadSpacing.xs),
                Text(
                  _metaLine(l, deal.source, until: deal.until),
                  style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(44, 44),
                    ),
                    onPressed: () => openAmazonSearch(ref, deal.item),
                    icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                    label: Text(l.dealsOnAmazon),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeCard extends StatelessWidget {
  const new({required this.code});

  final DealCode code;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final percent = code.percent;
    final off = percent != null && percent > 0
        ? l.dealsPercent(dealMoney(percent))
        : '${dealMoney(code.amount ?? 0)} ${code.currency ?? ''}'.trim();
    return ZadCard(
      onTap: () => openAmazonLink(code.url),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l.dealsCodeTitle(code.store, off),
                  style: ZadType.titleSmall,
                ),
                const SizedBox(height: ZadSpacing.xs),
                Text(
                  _metaLine(
                    l,
                    code.source,
                    until: code.until,
                    minOrder: code.minOrder,
                  ),
                  style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: ZadSpacing.sm),
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size(44, 44)),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code.code));
              if (!context.mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(l.dealsCopied(code.code))));
            },
            child: Text(code.code, style: ZadType.labelLarge),
          ),
        ],
      ),
    );
  }
}

String _sourceLabel(ZadL10n l, String kind) => switch (dealSourceOf(kind)) {
  DealSource.video => l.dealsSourceVideo,
  DealSource.post => l.dealsSourcePost,
  DealSource.page => l.dealsSourcePage,
  DealSource.flyer => l.dealsSourceFlyer,
  DealSource.receipts => l.dealsSourceReceipts,
  DealSource.partner => l.dealsSourcePartner,
  DealSource.other => l.dealsSourceOther,
};

String _priceLine(ZadL10n l, StoreDeal d) {
  final before = d.priceBefore;
  final saving = d.saving;
  return <String>[
    l.dealsPrice(d.store, dealMoney(d.price), d.currency).trim(),
    if (before != null) l.dealsWasPrice(dealMoney(before)),
    if (saving != null && saving > 0) '(−${l.dealsPercent('$saving')})',
  ].join(' ');
}

String _metaLine(ZadL10n l, String kind, {DateTime? until, double? minOrder}) =>
    <String>[
      _sourceLabel(l, kind),
      if (minOrder != null && minOrder > 0)
        l.dealsMinOrder(dealMoney(minOrder)),
      if (until != null) l.dealsUntil(dealDay(until)),
    ].join(' · ');
