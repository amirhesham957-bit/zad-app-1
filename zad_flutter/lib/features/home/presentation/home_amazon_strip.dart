/// «🛍️ تسوق من أمازون» on home, without products.
///
/// The product row (home_amazon_row.dart) is off home since b9251dd3: its
/// seeded products had stock photos and Saudi prices for a customer in Egypt.
/// The owner wants the strip back in its empty shape (2026-10-05): two
/// buttons and no product at all.
///
/// - «إضافة» opens the shopping list's add sheet.
/// - «اقتراح» opens an Amazon search in the account's own store for the
///   first real need — a stock that ran out or runs low, else the first line
///   on the shopping list — or that store's deals page when nothing is needed.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/shared/affiliate/domain/affiliate.dart';
import 'package:zad/shared/inventory/application/pantry_controller.dart';
import 'package:zad/shared/inventory/application/shopping_controller.dart';
import 'package:zad/shared/inventory/domain/product_family.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/modes/application/modes_controller.dart';
import 'package:zad/shared/navigation/zad_screens.dart';

/// What «اقتراح» searches for: the first stock that ran out, then one running
/// low, then the first unbought line on the list; null when nothing is needed.
String? amazonSuggestionTerm(WidgetRef ref) {
  final stock = groupPantry(ref.watch(pantryControllerProvider).items);
  for (final g in stock) {
    if (g.isOut) return g.name;
  }
  for (final g in stock) {
    if (g.isLow) return g.name;
  }
  for (final s in ref.watch(shoppingControllerProvider).items) {
    if (!s.isPurchased && s.itemName.trim().isNotEmpty) return s.itemName;
  }
  return null;
}

/// The strip.
class HomeAmazonStrip extends ConsumerWidget {
  /// Creates the strip.
  const new({super.key});

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    // A browser tab, never the Amazon app: the app opens its home page and
    // drops the associate tag (Kotlin's AffiliateHelper.open).
    try {
      if (await launchUrl(uri, mode: LaunchMode.inAppBrowserView)) return;
    } on Object catch (e) {
      debugPrint('amazon tab failed: $e');
    }
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object catch (e) {
      debugPrint('amazon browser failed: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // وضع الطوارئ: no buying suggestions at all.
    if (ref.watch(modesControllerProvider.select((v) => v.broke != null))) {
      return const SizedBox.shrink();
    }
    final term = amazonSuggestionTerm(ref);
    final country = ref.watch(accountCountryProvider);

    return Padding(
      padding: const EdgeInsets.only(bottom: ZadSpacing.lg),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: ZadColors.surface,
          borderRadius: BorderRadius.circular(ZadRadii.card),
          border: Border.all(color: ZadColors.outline.withValues(alpha: 0.4)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(ZadSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                '🛍️ تسوق من أمازون',
                style: ZadType.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: ZadSpacing.xs),
              Text(
                term == null
                    ? 'ضيف اللي ناقصك، أو شوف عروض النهارده'
                    : 'ناقصك $term — دوّر عليه في أمازون',
                style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
              ),
              const SizedBox(height: ZadSpacing.md),
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () =>
                          unawaited(ZadScreens.showAddShoppingSheet(context)),
                      icon: const Icon(ZadIcons.add, size: 18),
                      label: const Text('إضافة'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: ZadSpacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          unawaited(_open(amazonSuggestUrl(term, country))),
                      icon: const Icon(ZadIcons.assistant, size: 18),
                      label: const Text('اقتراح'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        shape: const StadiumBorder(),
                      ),
                    ),
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
