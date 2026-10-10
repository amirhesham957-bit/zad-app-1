/// Kotlin's Amazon suggestion under the shopping list (`ShoppingListScreen` +
/// `AmazonAffiliateWidget.kt`): after the customer ticks an item bought,
/// `amazon-creators-search` / `match_product` looks for it in the curated
/// catalogue, and the list shows
///
/// - «ترشيحات الشراء من أمازون» with its disclosure and «تفعيل الترشيحات»
///   until the customer agrees (`AffiliateConsentBanner`);
/// - a shimmer while it looks (`AffiliateLoadingSkeleton`);
/// - «اقتراح: بديل من أمازون» and the product card with «اشترِ من أمازون»,
///   then «زاد سجّل N نقرة…» and «إيقاف الترشيحات»;
/// - or, with no match, «لسه بنجهز ترشيحات لـ …» and «ابحث في أمازون» — a
///   tagged search — after recording the term in `affiliate_catalog_requests`.
///
/// As in Kotlin the match runs on the tick (a tap), the consent lives for the
/// session only, and each answer is cached per item name.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:zad/core/design/components/zad_kotlin_surfaces.dart';
import 'package:zad/core/design/components/zad_network_image.dart';
import 'package:zad/core/design/tokens/zad_extended_colors.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/shared/affiliate/application/affiliate_match_controller.dart';
import 'package:zad/shared/affiliate/data/affiliate_repository.dart';
import 'package:zad/shared/affiliate/domain/affiliate.dart';
import 'package:zad/shared/budget/application/budget_controller.dart';

String _price(double v) => NumberFormat('#,##0.##', 'en').format(v);

/// The section under the list.
class AffiliateSuggestionSection extends ConsumerWidget {
  /// Creates the section.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(affiliateMatchProvider);
    if (view.recentlyPurchased.isEmpty) return const SizedBox.shrink();
    final controller = ref.read(affiliateMatchProvider.notifier);
    if (!view.consent) {
      return _ConsentBanner(onAccept: () => controller.setConsent(given: true));
    }
    if (view.matching) return const _LoadingSkeleton();
    final products = ref.watch(affiliateProductsProvider).value;
    final product = view.matchedId == null
        ? null
        : products?.where((p) => p.id == view.matchedId).firstOrNull;
    if (product != null) {
      final scheme = Theme.of(context).colorScheme;
      final clicks = ref.watch(affiliateClickCountProvider).value ?? 0;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'اقتراح: بديل من أمازون',
              style: ZadType.titleSmall.copyWith(
                fontWeight: FontWeight.bold,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          _ProductCard(
            product: product,
            onBuy: () {
              unawaited(
                openAffiliateProduct(ref, product, sourceScreen: 'shopping'),
              );
              ref.invalidate(affiliateClickCountProvider);
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'زاد سجّل $clicks نقرة على ترشيحات أمازون',
                    style: ZadType.labelSmall.copyWith(
                      color: context.zadExt.textTertiary,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => controller.setConsent(given: false),
                  borderRadius: BorderRadius.circular(99),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    child: Text(
                      'إيقاف الترشيحات',
                      style: ZadType.labelSmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
    if (view.searched) return _EmptyState(term: view.recentlyPurchased);
    return const SizedBox.shrink();
  }
}

/// Kotlin's `AffiliateConsentBanner`.
class _ConsentBanner extends StatelessWidget {
  const new({required this.onAccept});

  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ZadListCard(
        color: scheme.primaryContainer,
        child: Column(
          children: <Widget>[
            Icon(Icons.shopping_cart, size: 32, color: scheme.primary),
            const SizedBox(height: 8),
            Text(
              'ترشيحات الشراء من أمازون',
              style: ZadType.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'زاد بيقترح عليك منتجات من أمازون تناسب احتياجاتك. قد نحصل على '
              'عمولة من المشتريات.',
              textAlign: TextAlign.center,
              style: ZadType.bodySmall.copyWith(
                color: scheme.onPrimaryContainer.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onAccept,
              style: FilledButton.styleFrom(
                minimumSize: const Size(64, 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('تفعيل الترشيحات'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kotlin's `AffiliateLoadingSkeleton`: a 1200ms light-grey shimmer.
class _LoadingSkeleton extends StatefulWidget {
  const new();

  @override
  State<_LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<_LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: ZadListCard(
      padding: const EdgeInsets.all(12),
      child: AnimatedBuilder(
        animation: _t,
        builder: (_, _) {
          final x = Curves.fastOutSlowIn.transform(_t.value) * 1000;
          final brush = LinearGradient(
            colors: <Color>[
              Colors.grey.shade300.withValues(alpha: 0.6),
              Colors.grey.shade300.withValues(alpha: 0.2),
              Colors.grey.shade300.withValues(alpha: 0.6),
            ],
            transform: _Slide(x),
          );
          Widget bone(double w, double h, double r) => Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
              gradient: brush,
              borderRadius: BorderRadius.circular(r),
            ),
          );
          return Row(
            children: <Widget>[
              bone(72, 72, 12),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    FractionallySizedBox(
                      widthFactor: 0.7,
                      child: bone(double.infinity, 16, 4),
                    ),
                    const SizedBox(height: 8),
                    FractionallySizedBox(
                      widthFactor: 0.4,
                      child: bone(double.infinity, 14, 4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              bone(100, 36, 10),
            ],
          );
        },
      ),
    ),
  );
}

class _Slide extends GradientTransform {
  const new(this.x);

  final double x;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(x - 200 - bounds.width / 2, 0, 0);
}

/// Kotlin's `AffiliateProductCard` with its `BuyButton`.
class _ProductCard extends ConsumerWidget {
  const new({required this.product, required this.onBuy});

  final AffiliateProduct product;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final currency = ref.watch(
      budgetControllerProvider.select((v) => v.snapshot?.currency ?? ''),
    );
    const amazon = Color(0xFFFF9900);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GestureDetector(
        onTap: onBuy,
        child: ZadListCard(
          radius: 24,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 88,
                  height: 88,
                  color: context.zadExt.surfaceContainerLow,
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      if ((product.imageUrl ?? '').isNotEmpty)
                        ZadNetworkImage(
                          product.imageUrl!,
                          fit: BoxFit.cover,
                          fallback: const SizedBox.shrink(),
                        )
                      else
                        Icon(
                          Icons.shopping_bag,
                          size: 28,
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                        ),
                      PositionedDirectional(
                        top: 0,
                        start: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: const BoxDecoration(
                            color: amazon,
                            borderRadius: BorderRadiusDirectional.only(
                              bottomEnd: Radius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'أمازون',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      product.nameAr,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: ZadType.titleMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    if (product.averagePriceSar > 0) ...<Widget>[
                      const SizedBox(height: 4),
                      Row(
                        children: <Widget>[
                          Icon(
                            Icons.monetization_on,
                            size: 16,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${_price(product.averagePriceSar)} $currency'
                                .trim(),
                            style: ZadType.bodyLarge.copyWith(
                              fontWeight: FontWeight.bold,
                              color: scheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 40,
                child: FilledButton.icon(
                  onPressed: onBuy,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    backgroundColor: amazon,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.shopping_cart, size: 16),
                  label: const Text(
                    'اشترِ من أمازون',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kotlin's `AffiliateEmptyState`: no curated match, a tagged search.
class _EmptyState extends ConsumerWidget {
  const new({required this.term});

  final String term;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.search_off,
            size: 48,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          Text(
            'لسه بنجهز ترشيحات لـ "$term"',
            textAlign: TextAlign.center,
            style: ZadType.bodyMedium.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            'دوّر على المنتج مباشرة في أمازون',
            textAlign: TextAlign.center,
            style: ZadType.bodySmall.copyWith(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () => unawaited(openAmazonSearch(ref, term)),
            icon: const Icon(Icons.search, size: 18),
            label: const Text('ابحث في أمازون'),
          ),
        ],
      ),
    );
  }
}
