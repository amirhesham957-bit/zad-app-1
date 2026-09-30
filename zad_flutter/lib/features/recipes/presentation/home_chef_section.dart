/// Kotlin's `SmartChefSection` (`HomeScreen.kt`), `ZadChefCard`
/// (`PremiumHomeComponents.kt`) and `ChefRecipeRow` (`ChefRecipeCards.kt`):
/// شيف زاد on home — the friendly line, then the recipe cards to cook from.
///
/// Kotlin fills this with a model call whenever the pantry changes, and
/// falls back to hard-coded recipes. Both stay out (the owner's standing
/// decision: model calls only on a tap, no invented answers), so the card
/// shows the last suggestions the customer asked for, and a tap with none
/// takes them to ask.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:zad/core/design/components/zad_pressable.dart';
import 'package:zad/core/design/foundation/compose_shadow.dart';
import 'package:zad/core/design/tokens/zad_extended_colors.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/features/household/presentation/household_screen.dart';
import 'package:zad/features/recipes/application/recipes_controller.dart';
import 'package:zad/features/recipes/domain/recipe.dart';
import 'package:zad/features/recipes/presentation/recipe_detail_screen.dart';
import 'package:zad/shared/budget/application/budget_controller.dart';
import 'package:zad/shared/inventory/application/pantry_controller.dart';
import 'package:zad/shared/modes/application/modes_controller.dart';

/// The section, with Kotlin's gap below it.
class HomeChefSection extends ConsumerWidget {
  /// Creates the section.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(recipesControllerProvider);
    final pantry = ref.watch(pantryControllerProvider.select((v) => v.items));
    final brokeActive = ref.watch(
      modesControllerProvider.select((v) => v.broke != null),
    );
    var recipes = view.suggestions?.recipes ?? const <Recipe>[];
    // وضع الطوارئ: only what can be made from the house.
    if (brokeActive) {
      recipes = recipes.where((r) => r.missing.isEmpty).toList();
    }
    final allDepleted =
        pantry.isNotEmpty && pantry.every((i) => i.quantity <= 0);
    final text = view.suggestions?.text;
    final dish = text
        ?.split('\n')
        .map((l) => l.trim())
        .firstWhere((l) => l.isNotEmpty, orElse: () => '')
        .replaceFirst(RegExp(r'^[\d\-•·.]+\s*'), '');

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ZadChefCard(
            suggestion: dish == null || dish.isEmpty ? null : dish,
            emptyHint: allDepleted
                ? 'مخزونك كله خلص — نزّل النواقص في التسوق وأنا أقترحلك أكل.'
                : 'ضيف أصناف لمخزونك عشان شيف زاد يقترح لك طبق اليوم.',
            onTap: () {
              if (recipes.isNotEmpty) {
                unawaited(showRecipeDetail(context, recipes.first));
              } else {
                unawaited(
                  showHouseholdSection(context, HouseholdSection.recipes),
                );
              }
            },
          ),
          if (recipes.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            _ChefRecipeRow(recipes: recipes),
          ],
        ],
      ),
    );
  }
}

/// Kotlin's `ZadChefCard`.
class ZadChefCard extends StatelessWidget {
  /// Creates the card.
  const new({
    required this.suggestion,
    required this.emptyHint,
    required this.onTap,
    super.key,
  });

  /// The dish line, or null.
  final String? suggestion;

  /// What shows without one.
  final String emptyHint;

  /// Opens the recipe, or the recipes.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ZadPressable(
      scale: 0.98,
      haptic: false,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: kZadCardShadow,
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFFDF3E1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.restaurant,
                size: 28,
                color: context.zadExt.secondaryDark,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'شيف زاد (اقتراحات ذكية)',
                    style: ZadType.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    suggestion ?? emptyHint,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: ZadType.bodyMedium.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kotlin's `ChefRecipeRow`: «من مخزونك» first, then the ones missing
/// something.
class _ChefRecipeRow extends StatelessWidget {
  const new({required this.recipes});

  final List<Recipe> recipes;

  @override
  Widget build(BuildContext context) {
    final ordered = <Recipe>[
      ...recipes.where((r) => r.missing.isEmpty),
      ...recipes.where((r) => r.missing.isNotEmpty),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      clipBehavior: Clip.none,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (var i = 0; i < ordered.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: 12),
            _ChefRecipeCard(recipe: ordered[i]),
          ],
        ],
      ),
    );
  }
}

class _ChefRecipeCard extends ConsumerWidget {
  const new({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final ext = context.zadExt;
    final liked = ref.watch(
      recipesControllerProvider.select((v) => v.ratings[recipe.name]),
    );
    final currency = ref.watch(
      budgetControllerProvider.select((v) => v.snapshot?.currency ?? ''),
    );
    final controller = ref.read(recipesControllerProvider.notifier);
    final complete = recipe.missing.isEmpty;
    final badgeColor = complete ? scheme.primary : ext.secondaryDark;
    final url = recipe.imageUrl ?? recipe.thumbUrl;
    final fallback = Center(
      child: Icon(Icons.restaurant, size: 32, color: ext.secondaryDark),
    );

    return SizedBox(
      width: 260,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: kZadCardShadow,
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => unawaited(showRecipeDetail(context, recipe)),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    height: 120,
                    width: double.infinity,
                    child: ColoredBox(
                      color: const Color(0xFFFDF3E1),
                      child: url == null
                          ? fallback
                          : Image.network(
                              url,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => fallback,
                            ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Text(
                            complete
                                ? '✓ مكتملة من مخزونك'
                                : 'ناقصك ${recipe.missing.length}',
                            style: ZadType.labelSmall.copyWith(
                              fontWeight: FontWeight.w600,
                              color: badgeColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          recipe.name,
                          style: ZadType.titleSmall.copyWith(
                            fontWeight: FontWeight.bold,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: <Widget>[
                            if (recipe.prepMinutes > 0) ...<Widget>[
                              Icon(
                                Icons.schedule,
                                size: 14,
                                color: scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${recipe.prepMinutes} د',
                                style: ZadType.labelSmall.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            if (recipe.costEstimate > 0)
                              Text(
                                '${_money(recipe.costEstimate)}'
                                '${currency.isEmpty ? '' : ' $currency'}',
                                style: ZadType.labelSmall.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            const Spacer(),
                            // Rates feed the next suggestions (rate_recipe);
                            // the same opinion again clears it.
                            InkWell(
                              onTap: () => unawaited(
                                controller.rate(recipe, liked: true),
                              ),
                              child: Icon(
                                Icons.thumb_up,
                                size: 18,
                                semanticLabel: 'عجبتني',
                                color: liked == true
                                    ? scheme.primary
                                    : scheme.onSurfaceVariant.withValues(
                                        alpha: 0.4,
                                      ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            InkWell(
                              onTap: () => unawaited(
                                controller.rate(recipe, liked: false),
                              ),
                              child: Icon(
                                Icons.thumb_down,
                                size: 18,
                                semanticLabel: 'معجبتنيش',
                                color: liked == false
                                    ? ext.secondaryDark
                                    : scheme.onSurfaceVariant.withValues(
                                        alpha: 0.4,
                                      ),
                              ),
                            ),
                          ],
                        ),
                        if (recipe.missing.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 8),
                          Text(
                            'ناقصك: ${recipe.missing.join('، ')}',
                            style: ZadType.labelSmall.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                            ),
                            onPressed: () =>
                                unawaited(controller.addMissingToList(recipe)),
                            icon: Icon(
                              Icons.add_shopping_cart,
                              size: 16,
                              color: scheme.primary,
                            ),
                            label: Text(
                              'ضيفهم لقائمة التسوق',
                              style: ZadType.labelMedium.copyWith(
                                color: scheme.primary,
                              ),
                            ),
                          ),
                        ],
                        if (recipe.steps.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 6),
                          Text(
                            'اضغط للخطوات',
                            style: ZadType.labelSmall.copyWith(
                              color: scheme.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _money(double v) => NumberFormat('#,##0.##', 'en').format(v);
