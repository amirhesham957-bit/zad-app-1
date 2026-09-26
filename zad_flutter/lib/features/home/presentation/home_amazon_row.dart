/// Kotlin's «🛍️ تسوق من أمازون» on home (`HomeScreen.kt` §9,
/// `ZadAmazonDealCard`, `ZadAmazonSearchChip`, and the view model's
/// `affiliatePicks` / `affiliateSearchNeeds` / `refreshAmazonRecommendations`).
///
/// Every card is tied to a real need — an item that ran out, one running
/// low, a line on the shopping list — with the reason written on it. No need,
/// no section. The server's recommendations (`amazon-creators-search`,
/// action `recommendations`) are a database match plus photos, no model, so
/// they load with home, at most once per five minutes for the same pantry and
/// list sizes, as in Kotlin.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:url_launcher/url_launcher.dart';
import 'package:zad/core/env/zad_env.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/design/components/zad_pressable.dart';
import 'package:zad/design/foundation/compose_shadow.dart';
import 'package:zad/design/tokens/zad_extended_colors.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/affiliate/data/affiliate_repository.dart';
import 'package:zad/features/affiliate/domain/affiliate.dart';
import 'package:zad/features/budget/application/budget_controller.dart';
import 'package:zad/features/inventory/application/pantry_controller.dart';
import 'package:zad/features/inventory/application/shopping_controller.dart';
import 'package:zad/features/modes/application/modes_controller.dart';

/// Kotlin's `AmazonRecommendation`.
@immutable
class AmazonRecommendation {
  /// Creates one.
  const new({
    required this.name,
    required this.reason,
    required this.url,
    this.imageUrl,
    this.price,
    this.productId,
  });

  /// The item.
  final String name;

  /// Why it is shown.
  final String reason;

  /// The tagged link, built server-side.
  final String url;

  /// A photo, when found.
  final String? imageUrl;

  /// A price, when known.
  final double? price;

  /// The catalogue row, for the click record.
  final String? productId;
}

/// A need with no catalogue row — opens as an Amazon search.
typedef _Need = ({String name, String reason, int score});

/// A catalogue product matched to a need.
typedef _Pick = ({AffiliateProduct product, String reason, int score});

String _normalize(String raw) => raw
    .trim()
    .toLowerCase()
    .replaceAll(RegExp('[ً-ْـ]'), '')
    .replaceAll(RegExp('[أإآ]'), 'ا')
    .replaceAll('ة', 'ه')
    .replaceAll('ى', 'ي')
    .replaceAll(RegExp(r'\s+'), ' ');

/// The server's recommendations: null while unread or when the server
/// failed (home then falls back to the local match), empty when there is no
/// real need.
class AmazonRecommendations extends Notifier<List<AmazonRecommendation>?> {
  final Map<String, DateTime> _lastFetch = <String, DateTime>{};

  @override
  List<AmazonRecommendation>? build() => null;

  /// Kotlin's `refreshAmazonRecommendations(signature)` with its 5-minute
  /// guard per signature.
  Future<void> refresh(String signature) async {
    final now = ref.read(nowProvider)();
    final last = _lastFetch[signature];
    if (last != null && now.difference(last) < const Duration(minutes: 5)) {
      return;
    }
    _lastFetch[signature] = now;
    try {
      final response = await ref
          .read(supabaseClientProvider)
          .functions
          .invoke(
            'amazon-creators-search',
            body: const <String, dynamic>{'action': 'recommendations'},
          );
      final data = response.data;
      final items = data is Map ? data['items'] : null;
      if (items is! List) return;
      if (!ref.mounted) return;
      state = <AmazonRecommendation>[
        for (final raw in items)
          if (raw is Map)
            if (raw['name'] case final String name when name.trim().isNotEmpty)
              if (raw['url'] case final String url
                  when url.startsWith('https://'))
                AmazonRecommendation(
                  name: name,
                  reason: (raw['reason'] as String?) ?? '',
                  url: url,
                  imageUrl: switch (raw['image_url']) {
                    final String u when u.startsWith('https://') => u,
                    _ => null,
                  },
                  price: switch (raw['price']) {
                    final num p when p > 0 => p.toDouble(),
                    _ => null,
                  },
                  productId: raw['product_id'] as String?,
                ),
      ];
    } on Object catch (e) {
      debugPrint('refreshAmazonRecommendations() FAILED: $e');
    }
  }
}

/// The server's recommendations.
final amazonRecommendationsProvider =
    NotifierProvider<AmazonRecommendations, List<AmazonRecommendation>?>(
      AmazonRecommendations.new,
    );

/// The section.
class HomeAmazonRow extends ConsumerStatefulWidget {
  /// Creates the section.
  const new({super.key});

  @override
  ConsumerState<HomeAmazonRow> createState() => _HomeAmazonRowState();
}

class _HomeAmazonRowState extends ConsumerState<HomeAmazonRow> {
  String? _signature;

  @override
  Widget build(BuildContext context) {
    final inventory = ref.watch(
      pantryControllerProvider.select((v) => v.items),
    );
    final shopping = ref.watch(
      shoppingControllerProvider.select((v) => v.items),
    );
    final products = ref.watch(affiliateProductsProvider).value ?? const [];
    final recs = ref.watch(amazonRecommendationsProvider);
    final brokeActive = ref.watch(
      modesControllerProvider.select((v) => v.broke != null),
    );

    // Kotlin's LaunchedEffect(inventory.size, shoppingList.size).
    final signature = '${inventory.length}:${shopping.length}';
    if (signature != _signature) {
      _signature = signature;
      unawaited(
        Future<void>.microtask(
          () => ref
              .read(amazonRecommendationsProvider.notifier)
              .refresh(signature),
        ),
      );
    }

    // The needs: ran out (3), running low (2), on the list (2).
    final needs = <(String, int, String)>[
      for (final i in inventory)
        if (i.quantity <= 0) (i.itemName, 3, 'خلص من مخزونك'),
      for (final i in inventory)
        if (i.quantity > 0 && i.quantity <= (i.lowStockThreshold ?? 2))
          (i.itemName, 2, 'قارب على النفاد'),
      for (final s in shopping)
        if (!s.isPurchased) (s.itemName, 2, 'في قايمة التسوق'),
    ];

    // Local `affiliatePicks`.
    final localPicks = <_Pick>[];
    for (final product in products) {
      if (!product.isActive) continue;
      final haystack = <String>[
        product.nameAr,
        ...product.keywords,
      ].map(_normalize).where((h) => h.isNotEmpty).toList();
      (String, int, String)? best;
      var bestScore = 0;
      for (final need in needs) {
        final key = _normalize(need.$1);
        if (key.isEmpty) continue;
        final score = haystack.any((h) => h == key)
            ? need.$2 * 10
            : haystack.any((h) => h.contains(key) || key.contains(h))
            ? need.$2
            : 0;
        if (score > bestScore) {
          bestScore = score;
          best = need;
        }
      }
      if (best == null) continue;
      localPicks.add((product: product, reason: best.$3, score: bestScore));
    }
    localPicks.sort((a, b) => b.score.compareTo(a.score));

    // Local `affiliateSearchNeeds`: needs no catalogue row covers.
    final catalogue = <String>[
      for (final p in products)
        if (p.isActive)
          for (final k in <String>[p.nameAr, ...p.keywords])
            if (_normalize(k).isNotEmpty) _normalize(k),
    ];
    final localNeeds = <String, _Need>{};
    for (final need in needs) {
      final name = need.$1.trim();
      final key = _normalize(name);
      if (key.isEmpty) continue;
      if (catalogue.any(
        (c) => c == key || c.contains(key) || key.contains(c),
      )) {
        continue;
      }
      final existing = localNeeds[key];
      if (existing == null || need.$2 > existing.score) {
        localNeeds[key] = (name: name, reason: need.$3, score: need.$2);
      }
    }
    final sortedNeeds = localNeeds.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    final picks = recs != null
        ? <_Pick>[
            for (final r in recs)
              if (r.imageUrl != null)
                (
                  product: (
                    id: r.productId ?? 'rec:${r.name}',
                    nameAr: r.name,
                    asin: null,
                    asinVerified: false,
                    imageUrl: r.imageUrl,
                    averagePriceSar: r.price ?? 0,
                    isActive: true,
                    keywords: const <String>[],
                    priceCheckedAt: null,
                  ),
                  reason: r.reason,
                  score: 1,
                ),
          ]
        : localPicks.take(8).toList();

    final searchNeeds = recs != null
        ? <_Need>[
            for (final r in recs)
              if (r.imageUrl == null)
                (name: r.name, reason: r.reason, score: 1),
          ]
        : sortedNeeds.isNotEmpty
        ? sortedNeeds.take(10).toList()
        : <_Need>[
            for (final s in shopping)
              (name: s.itemName, reason: 'في قائمة التسوق', score: 1),
          ].fold<List<_Need>>(<_Need>[], (acc, n) {
            if (acc.length < 5 && !acc.any((a) => a.name == n.name)) acc.add(n);
            return acc;
          });

    // وضع الطوارئ: no buying suggestions at all.
    if (brokeActive || (picks.isEmpty && searchNeeds.isEmpty)) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Text('🛍️', style: ZadType.bodyLarge),
              const SizedBox(width: 6),
              Text(
                'تسوق من أمازون',
                style: ZadType.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (picks.isNotEmpty)
            _Bleed(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                clipBehavior: Clip.none,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    for (var i = 0; i < picks.length; i++) ...<Widget>[
                      if (i > 0) const SizedBox(width: 12),
                      ZadAmazonDealCard(
                        product: picks[i].product,
                        reason: picks[i].reason,
                        onTap: () => _openPick(picks[i], recs),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          if (searchNeeds.isNotEmpty) ...<Widget>[
            if (picks.isNotEmpty) const SizedBox(height: 10),
            _Bleed(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                child: Row(
                  children: <Widget>[
                    for (var i = 0; i < searchNeeds.length; i++) ...<Widget>[
                      if (i > 0) const SizedBox(width: 8),
                      ZadAmazonSearchChip(
                        itemName: searchNeeds[i].name,
                        reason: searchNeeds[i].reason,
                        onTap: () {
                          final match = recs
                              ?.where((r) => r.name == searchNeeds[i].name)
                              .firstOrNull;
                          unawaited(
                            _launch(
                              match?.url ?? _searchUrl(searchNeeds[i].name),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openPick(_Pick pick, List<AmazonRecommendation>? recs) async {
    final rec = recs?.where((r) => r.name == pick.product.nameAr).firstOrNull;
    if (rec == null) {
      await openAffiliateProduct(ref, pick.product, sourceScreen: 'home');
      return;
    }
    if (rec.productId case final id?) {
      final client = ref.read(supabaseClientProvider);
      try {
        await client.from('affiliate_clicks').insert(<String, dynamic>{
          'product_id': id,
          'user_id': client.auth.currentUser?.id,
          'source_screen': 'home',
        });
      } on Object catch (e) {
        debugPrint('affiliate click not recorded: $e');
      }
    }
    await _launch(rec.url);
  }

  /// Kotlin's `AffiliateHelper.open`: a browser, never the Amazon app —
  /// which would open its home page and drop the commission cookie.
  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await launchUrl(uri, mode: LaunchMode.inAppBrowserView)) return;
    } on Object catch (e) {
      debugPrint('affiliate browser tab failed: $e');
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// Kotlin's `bleedHorizontal(20.dp)`: the rail runs to the screen edges.
class _Bleed extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SizedBox(
      width: constraints.maxWidth,
      child: OverflowBox(
        maxWidth: constraints.maxWidth + 40,
        minWidth: constraints.maxWidth + 40,
        child: child,
      ),
    ),
  );
}

/// Kotlin's `ZadAmazonDealCard`: 140 dp wide, photo, reason, name, price
/// with its age, «أمازون», and the affiliate disclosure.
class ZadAmazonDealCard extends ConsumerWidget {
  /// Creates the card.
  const new({
    required this.product,
    required this.onTap,
    this.reason,
    super.key,
  });

  /// The product.
  final AffiliateProduct product;

  /// Why it is shown.
  final String? reason;

  /// Opens it.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final ext = context.zadExt;
    final currency = ref.watch(
      budgetControllerProvider.select((v) => v.snapshot?.currency ?? ''),
    );
    final age = priceAgeDays(product, ref.read(nowProvider)());
    final placeholder = Center(
      child: Icon(
        Icons.shopping_bag,
        size: 24,
        color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
      ),
    );
    return ZadPressable(
      haptic: false,
      onPressed: onTap,
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: kZadCardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 80,
                width: double.infinity,
                child: ColoredBox(
                  color: ext.surfaceContainerLow,
                  child: (product.imageUrl?.trim().isNotEmpty ?? false)
                      ? Image.network(
                          product.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => placeholder,
                        )
                      : placeholder,
                ),
              ),
            ),
            if (reason?.trim().isNotEmpty ?? false) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                reason!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ZadType.labelSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: ext.secondaryDark,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              '${product.nameAr}\n',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: ZadType.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        product.averagePriceSar > 0
                            ? '${_money(product.averagePriceSar)}'
                                  '${currency.isEmpty ? '' : ' $currency'}'
                            : '—',
                        style: ZadType.labelLarge.copyWith(
                          fontWeight: FontWeight.w800,
                          color: ext.secondaryDark,
                        ),
                      ),
                      Text(
                        age == null
                            ? 'سعر تقريبي'
                            : age <= 1
                            ? 'اتحدث النهاردة'
                            : 'سعر منذ $age يوم',
                        maxLines: 1,
                        style: ZadType.labelSmall.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'أمازون',
                  style: ZadType.labelSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // The affiliate disclosure — Amazon's terms, and honesty.
            Text(
              'رابط شراء أفلييت — عمولة لزاد بدون أي زيادة عليك',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ZadType.labelSmall.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kotlin's `ZadAmazonSearchChip`: "look this up on Amazon" — no photo, no
/// price, because none is known.
class ZadAmazonSearchChip extends StatelessWidget {
  /// Creates the chip.
  const new({
    required this.itemName,
    required this.reason,
    required this.onTap,
    super.key,
  });

  /// The item.
  final String itemName;

  /// Why.
  final String reason;

  /// Opens the search.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ext = context.zadExt;
    return ZadPressable(
      haptic: false,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: ext.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.search, size: 16, color: ext.secondaryDark),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  itemName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ZadType.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                Text(
                  reason,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ZadType.labelSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _money(double v) => NumberFormat('#,##0.##', 'en').format(v);

/// Kotlin's `AffiliateHelper.productUrl(asin = null, fallbackSearchTerm)`.
String _searchUrl(String term) =>
    'https://www.amazon.sa/s?k=${Uri.encodeQueryComponent(term)}'
    '&tag=${ZadEnv.amazonAssociateTag}';
