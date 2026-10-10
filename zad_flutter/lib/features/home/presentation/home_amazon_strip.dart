/// «🛍️ تسوق من أمازون» on home: a card per thing the home is short of.
///
/// The product row (home_amazon_row.dart) is off home since b9251dd3: its
/// seeded products had stock photos and Saudi prices for a customer in Egypt.
/// The strip came back without products (2026-10-05); the owner now wants
/// the shortages themselves side by side (2026-10-10), so the customer sees
/// at a glance what ran out and orders each with a tap:
///
/// - a horizontal row of cards, one per need — a stock that ran out, one
///   running low, then the unbought lines of the shopping list — each with
///   its reason and «اطلبه», a tagged search in the account's own store;
/// - «إضافة» opens the shopping list's add sheet, and the second button is
///   the store's deals page (or, with nothing needed, «اقتراح» as before).
///
/// No pictures and no prices: a card names the need, it does not pretend to
/// know which product or price the store will show.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/shared/affiliate/data/affiliate_repository.dart';
import 'package:zad/shared/affiliate/domain/affiliate.dart';
import 'package:zad/shared/inventory/application/pantry_controller.dart';
import 'package:zad/shared/inventory/application/shopping_controller.dart';
import 'package:zad/shared/inventory/domain/food_emoji.dart';
import 'package:zad/shared/inventory/domain/product_family.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/modes/application/modes_controller.dart';
import 'package:zad/shared/navigation/zad_screens.dart';

/// One card: what is needed and why.
typedef AmazonNeed = ({String name, String reason});

/// How many cards the row holds.
const int kAmazonNeedsShown = 10;

String _key(String raw) => raw
    .trim()
    .toLowerCase()
    .replaceAll(RegExp('[أإآ]'), 'ا')
    .replaceAll('ة', 'ه')
    .replaceAll('ى', 'ي')
    .replaceAll(RegExp(r'\s+'), ' ');

/// What the home is short of, most urgent first: stocks that ran out, then
/// stocks running low (per stock, not per brand — product_family.dart), then
/// the unbought lines of the shopping list. Each name once.
List<AmazonNeed> amazonNeeds(WidgetRef ref) {
  final stock = groupPantry(ref.watch(pantryControllerProvider).items);
  final shopping = ref.watch(shoppingControllerProvider).items;
  final out = <AmazonNeed>[];
  final seen = <String>{};
  void add(String name, String reason) {
    final key = _key(name);
    if (key.isEmpty || !seen.add(key) || out.length >= kAmazonNeedsShown) {
      return;
    }
    out.add((name: name.trim(), reason: reason));
  }

  for (final g in stock) {
    if (g.isOut) add(g.name, 'خلص');
  }
  for (final g in stock) {
    if (!g.isOut && g.isLow) add(g.name, 'قرب يخلص');
  }
  for (final s in shopping) {
    if (!s.isPurchased) add(s.itemName, 'في قايمة التسوق');
  }
  return out;
}

/// The strip.
class HomeAmazonStrip extends ConsumerWidget {
  /// Creates the strip.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // وضع الطوارئ: no buying suggestions at all.
    if (ref.watch(modesControllerProvider.select((v) => v.broke != null))) {
      return const SizedBox.shrink();
    }
    final needs = amazonNeeds(ref);
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
          padding: const EdgeInsets.symmetric(vertical: ZadSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: ZadSpacing.lg),
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
                      switch (needs.length) {
                        0 => 'ضيف اللي ناقصك، أو شوف عروض النهارده',
                        1 => 'ناقصك ${needs.first.name} — اطلبه من أمازون',
                        _ =>
                          'ناقصك ${needs.length} حاجات — اطلب كل واحدة بضغطة',
                      },
                      style: ZadType.bodySmall.copyWith(
                        color: ZadColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (needs.isNotEmpty) ...<Widget>[
                const SizedBox(height: ZadSpacing.md),
                // Cards as tall as the tallest one's content, at any text
                // size — no fixed row height to overflow.
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: ZadSpacing.lg,
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        for (var i = 0; i < needs.length; i++) ...<Widget>[
                          if (i > 0) const SizedBox(width: ZadSpacing.sm),
                          _NeedCard(
                            need: needs[i],
                            onOrder: () => unawaited(
                              openAmazonLink(
                                amazonSuggestUrl(needs[i].name, country),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: ZadSpacing.md),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: ZadSpacing.lg),
                child: Row(
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
                        // The cards already search each need; with none,
                        // the button suggests as it always did.
                        onPressed: () => unawaited(
                          openAmazonLink(amazonSuggestUrl(null, country)),
                        ),
                        icon: const Icon(ZadIcons.assistant, size: 18),
                        label: Text(needs.isEmpty ? 'اقتراح' : 'العروض'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          shape: const StadiumBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One need: its picture, its name, why, and «اطلبه».
class _NeedCard extends StatelessWidget {
  const new({required this.need, required this.onOrder});

  final AmazonNeed need;
  final VoidCallback onOrder;

  @override
  Widget build(BuildContext context) {
    final out = need.reason == 'خلص';
    return SizedBox(
      width: 148,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: ZadColors.surfaceLow,
          borderRadius: BorderRadius.circular(ZadRadii.card),
        ),
        child: Padding(
          padding: const EdgeInsets.all(ZadSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(foodEmoji(need.name), style: ZadType.titleLarge),
              const SizedBox(height: ZadSpacing.xs),
              Text(
                need.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: ZadType.bodyMedium.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                need.reason,
                style: ZadType.labelSmall.copyWith(
                  color: out ? ZadColors.terracottaRust : ZadColors.inkMuted,
                ),
              ),
              const Spacer(),
              const SizedBox(height: ZadSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: onOrder,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: ZadSpacing.sm,
                    ),
                  ),
                  child: const Text('🛒 اطلبه'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
