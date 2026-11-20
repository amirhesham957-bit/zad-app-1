/// شيف زاد: what to cook from what is in the kitchen — the chef's world.
///
/// The section opens on the last answer and never asks on its own — the
/// button docked at the bottom does. It says when the pantry has changed
/// since, so an old answer is not mistaken for a current one.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/design/components/zad_empty_state.dart';
import 'package:zad/core/design/components/zad_network_image.dart';
import 'package:zad/core/design/foundation/squircle.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/design/tokens/zad_world_colors.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/recipes/application/recipes_controller.dart';
import 'package:zad/features/recipes/domain/recipe.dart';
import 'package:zad/features/recipes/presentation/chef_world_scene.dart';
import 'package:zad/features/recipes/presentation/recipe_detail_screen.dart';
import 'package:zad/shared/ads/presentation/ai_wait_ad.dart';
import 'package:zad/shared/ads/presentation/inline_ad.dart';
import 'package:zad/shared/ads/presentation/native_ad.dart';
import 'package:zad/shared/affiliate/data/affiliate_repository.dart';
import 'package:zad/shared/budget/application/budget_controller.dart';
import 'package:zad/shared/inventory/application/pantry_controller.dart';
import 'package:zad/shared/inventory/application/shopping_controller.dart';
import 'package:zad/shared/navigation/zad_screens.dart';
import 'package:zad/shared/orb/domain/companion_state.dart';
import 'package:zad/shared/worlds/art/art.dart';
import 'package:zad/shared/worlds/world_card.dart';
import 'package:zad/shared/worlds/world_scaffold.dart';
import 'package:zad/shared/worlds/zad_world.dart';

/// The recipes section.
class RecipesView extends ConsumerWidget {
  /// Creates the section.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final view = ref.watch(recipesControllerProvider);
    final pantry = ref.watch(pantryControllerProvider.select((v) => v.items));
    final stocked = stockedPantry(pantry);
    final hasStock = stocked.isNotEmpty;
    final suggestions = view.suggestions;
    final isStale =
        suggestions != null &&
        suggestions.pantrySignature != pantrySignature(pantry);
    final controller = ref.read(recipesControllerProvider.notifier);

    final stateLine = view.isAsking
        ? l.chefStateThinking
        : !hasStock
        ? l.chefStateEmpty
        : suggestions == null
        ? l.chefStateReady
        : l.chefWorldState(
            suggestions.recipes.length,
            suggestions.recipes.where((r) => r.fromInventory).length,
          );

    return ZadWorldScaffold(
      world: ZadWorld.chef,
      // The household page owns the back button (its app bar).
      showBack: false,
      eyebrow: l.pantryWorldEyebrow(stocked.length),
      title: l.worldLabelChef,
      stateLine: stateLine,
      scene: (loop) => ChefWorldScene(loop, cooking: view.isAsking),
      zado: ZadWorldZado(
        left: 24,
        top: 64,
        size: 128,
        state: view.isAsking
            ? CompanionState.focused
            : !hasStock
            ? CompanionState.hungry
            : CompanionState.happy,
      ),
      // The one action, docked in the thumb's reach — once there is
      // something to cook from; before that the empty state has the way in.
      dockHeight: hasStock ? 88 : 0,
      overlay: hasStock
          ? Positioned(
              left: ZadSpacing.gutter,
              right: ZadSpacing.gutter,
              bottom: ZadSpacing.md,
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: view.isAsking
                          ? null
                          : () => unawaited(
                              controller.ask(fresh: suggestions != null),
                            ),
                      style: FilledButton.styleFrom(
                        backgroundColor: ZadWorldColors.chef,
                        minimumSize: const Size(0, 48),
                      ),
                      icon: view.isAsking
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(ZadIcons.chef),
                      label: Text(
                        view.isAsking
                            ? l.chefAsking
                            : suggestions == null
                            ? l.chefAskCta
                            : l.chefAskAgain,
                      ),
                    ),
                  ),
                  const SizedBox(width: ZadSpacing.sm),
                  OutlinedButton(
                    onPressed: view.isAsking
                        ? null
                        : () => unawaited(
                            controller.ask(fresh: true, week: true),
                          ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      foregroundColor: ZadWorldColors.chef,
                      backgroundColor: Colors.white,
                    ),
                    child: Text(l.recipesWeekAction),
                  ),
                ],
              ),
            )
          : null,
      slivers: <Widget>[
        if (view.error != null)
          _Note(
            icon: ZadIcons.failed,
            color: ZadColors.terracottaRust,
            text: l.chefError,
          )
        else if (isStale && hasStock)
          _Note(
            icon: ZadIcons.inventory,
            color: ZadColors.mustardOchre,
            text: l.chefStale,
          ),
        // The chef is thinking: one ad while the customer waits (owner
        // 15/11), above the list so it is on screen either way.
        if (view.isAsking)
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(
              ZadSpacing.gutter,
              ZadSpacing.md,
              ZadSpacing.gutter,
              0,
            ),
            sliver: SliverToBoxAdapter(child: ZadAiWaitAd()),
          ),
        if (suggestions == null)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              ZadSpacing.gutter,
              ZadSpacing.md,
              ZadSpacing.gutter,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: ZadWorldCard(
                child: hasStock
                    ? ZadEmptyState(
                        icon: ZadIcons.chef,
                        title: l.chefReadyTitle,
                        message: l.chefReadyBody,
                      )
                    // The way in, right here (emulator, 2026-11-10: two
                    // greyed buttons and nothing that led to the pantry).
                    : ZadEmptyState(
                        icon: ZadIcons.chef,
                        title: l.chefEmptyTitle,
                        message: l.chefEmptyBody,
                        action: FilledButton.icon(
                          onPressed: () =>
                              unawaited(ZadScreens.showAddPantrySheet(context)),
                          style: FilledButton.styleFrom(
                            backgroundColor: ZadWorldColors.chef,
                            minimumSize: const Size(0, 48),
                          ),
                          icon: const Icon(ZadIcons.add),
                          label: Text(l.recipesAddToPantry),
                        ),
                      ),
              ),
            ),
          )
        else ...<Widget>[
          if (suggestions.text case final text?)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                ZadSpacing.gutter,
                ZadSpacing.md,
                ZadSpacing.gutter,
                0,
              ),
              sliver: SliverToBoxAdapter(child: _ChefLine(text: text)),
            ),
          ..._group(
            l.recipesWeekGroup,
            suggestions.weekPlan,
            ads: !view.isAsking,
          ),
          ..._group(
            l.chefGroupPantry,
            suggestions.fromPantry,
            ads: !view.isAsking,
          ),
          ..._group(
            l.recipesTrendingGroup,
            suggestions.trending,
            ads: !view.isAsking,
          ),
          ..._group(
            l.chefGroupMore,
            suggestions.needShopping,
            ads: !view.isAsking,
          ),
        ],
      ],
    );
  }

  // [ads] is off while the chef works on a new ask: the waiting ad at the
  // top is the one ad then, never a second from the old list (owner 15/11).
  static List<Widget> _group(
    String title,
    List<Recipe> recipes, {
    required bool ads,
  }) {
    if (recipes.isEmpty) return const <Widget>[];
    return <Widget>[
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          ZadSpacing.gutter,
          ZadSpacing.lg,
          ZadSpacing.gutter,
          ZadSpacing.sm,
        ),
        sliver: SliverToBoxAdapter(
          child: Text(
            title,
            style: ZadType.titleSmall.copyWith(color: ZadWorldColors.chef),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: ZadSpacing.gutter),
        sliver: SliverList.separated(
          itemCount: recipes.length,
          // Between cards, never inside one (owner 11/11).
          separatorBuilder: (_, i) => ads && nativeAdAfter(i)
              ? const Column(
                  children: <Widget>[
                    SizedBox(height: ZadSpacing.sm),
                    ZadNativeAd(),
                    SizedBox(height: ZadSpacing.sm),
                  ],
                )
              : const SizedBox(height: ZadSpacing.sm),
          itemBuilder: (_, i) => _RecipeCard(recipe: recipes[i]),
        ),
      ),
      // A reading page: one banner at its end, after the last card (10.3 e).
      if (ads && recipes.isNotEmpty)
        const SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: ZadSpacing.gutter),
          sliver: SliverToBoxAdapter(child: ZadInlineAd()),
        ),
    ];
  }
}

class _Note extends StatelessWidget {
  const new({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => SliverPadding(
    padding: const EdgeInsets.fromLTRB(
      ZadSpacing.gutter,
      ZadSpacing.md,
      ZadSpacing.gutter,
      0,
    ),
    sliver: SliverToBoxAdapter(
      child: ZadWorldCard(
        child: Row(
          children: <Widget>[
            Icon(icon, size: 18, color: color),
            const SizedBox(width: ZadSpacing.md),
            Expanded(
              child: Text(
                text,
                style: ZadType.bodySmall.copyWith(color: ZadColors.slate),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ChefLine extends StatelessWidget {
  const new({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => ZadWorldCard(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ZadArt.icon(ZadIconArt.pot, size: 28),
        const SizedBox(width: ZadSpacing.md),
        Expanded(
          child: Text(
            text,
            style: ZadType.bodySmall.copyWith(color: ZadColors.slate),
          ),
        ),
      ],
    ),
  );
}

class _RecipeCard extends ConsumerWidget {
  const new({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(
      budgetControllerProvider.select((v) => v.snapshot?.currency ?? ''),
    );
    return ZadWorldCard(
      onTap: () => unawaited(showRecipeSheet(context, recipe)),
      child: Row(
        children: <Widget>[
          _Dish(recipe: recipe, size: 48),
          const SizedBox(width: ZadSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (recipe.day case final day?)
                  Text(
                    context.l10n.recipesWeekDay(day),
                    style: ZadType.labelSmall.copyWith(
                      color: ZadWorldColors.chef,
                    ),
                  ),
                Text(
                  recipe.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: ZadType.titleSmall,
                ),
                const SizedBox(height: ZadSpacing.xs),
                Text(
                  _meta(context, recipe, currency),
                  style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
                ),
                if (recipe.deals.isNotEmpty)
                  Text(
                    context.l10n.recipesOnDeal,
                    style: ZadType.labelSmall.copyWith(
                      color: ZadColors.green700,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: ZadSpacing.sm),
          _Completeness(recipe: recipe),
        ],
      ),
    );
  }
}

/// "مكتملة" or "ناقصك ٢" — the one fact that decides whether it is dinner.
class _Completeness extends StatelessWidget {
  const new({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final complete = recipe.fromInventory;
    final color = complete ? ZadColors.green700 : ZadColors.mustardOchre;
    final l = context.l10n;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: color.withValues(alpha: 0.10),
        shape: zadSquircle(ZadRadii.chip),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ZadSpacing.sm,
          vertical: ZadSpacing.xs,
        ),
        child: Text(
          complete ? l.chefComplete : l.chefMissingCount(recipe.missing.length),
          style: ZadType.labelSmall.copyWith(color: color),
        ),
      ),
    );
  }
}

/// The dish's photograph when the server found one, its drawing otherwise.
class _Dish extends StatelessWidget {
  const new({required this.recipe, required this.size});

  final Recipe recipe;
  final double size;

  @override
  Widget build(BuildContext context) {
    final glyph = Center(child: dishArt(recipe.name, size * 0.7));
    final url = size > 64
        ? (recipe.imageUrl ?? recipe.thumbUrl)
        : (recipe.thumbUrl ?? recipe.imageUrl);
    return SizedBox.square(
      dimension: size,
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: zadSquircle(ZadRadii.chip)),
        child: ColoredBox(
          color: ZadColors.surfaceVariant,
          child: url == null
              ? glyph
              : ZadNetworkImage(url, fit: BoxFit.cover, fallback: glyph),
        ),
      ),
    );
  }
}

/// Opens one recipe.
Future<void> showRecipeSheet(BuildContext context, Recipe recipe) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: ZadColors.surface,
      shape: zadSquircle(ZadRadii.sheet),
      builder: (_) => RecipeSheet(recipe: recipe),
    );

/// One recipe: what it takes, what is missing, how to make it.
class RecipeSheet extends ConsumerWidget {
  /// Creates the sheet.
  const new({required this.recipe, super.key});

  /// The recipe.
  final Recipe recipe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(recipesControllerProvider.notifier);
    // Rebuilt when the list or the pantry changes, so the button counts what
    // is still left to add — and disappears once it is all on the list.
    ref
      ..watch(shoppingControllerProvider.select((v) => v.items))
      ..watch(pantryControllerProvider.select((v) => v.items));
    final toBuy = controller.toBuy(recipe);
    final currency = ref.watch(
      budgetControllerProvider.select((v) => v.snapshot?.currency ?? ''),
    );

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(ZadSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                _Dish(recipe: recipe, size: 72),
                const SizedBox(width: ZadSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(recipe.name, style: ZadType.titleMedium),
                      const SizedBox(height: ZadSpacing.xs),
                      Text(
                        _meta(context, recipe, currency),
                        style: ZadType.labelSmall.copyWith(
                          color: ZadColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                _Completeness(recipe: recipe),
              ],
            ),
            if (recipe.chefSecret case final secret?) ...<Widget>[
              const SizedBox(height: ZadSpacing.lg),
              _ChefSecret(secret),
            ],
            if (recipe.used.isNotEmpty) ...<Widget>[
              const SizedBox(height: ZadSpacing.xl),
              _Heading(context.l10n.chefHaveHeading),
              for (final item in recipe.used)
                _Ingredient(name: item, have: true),
            ],
            if (recipe.missing.isNotEmpty) ...<Widget>[
              const SizedBox(height: ZadSpacing.lg),
              _Heading(context.l10n.chefMissingHeading),
              for (final item in recipe.missing)
                _Ingredient(name: item, have: false),
            ],
            if (recipe.deals.isNotEmpty) ...<Widget>[
              const SizedBox(height: ZadSpacing.lg),
              _Heading(context.l10n.recipesOnDeal),
              for (final d in recipe.deals)
                InkWell(
                  onTap: d.url == null
                      ? null
                      : () => unawaited(openAmazonLink(d.url!)),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        '${d.item} · ${d.store} · '
                        '${d.price % 1 == 0 ? d.price.toInt() : d.price} '
                        '${d.currency}',
                        style: ZadType.bodySmall,
                      ),
                    ),
                  ),
                ),
            ],
            if (recipe.sourceUrl case final url?) ...<Widget>[
              const SizedBox(height: ZadSpacing.sm),
              TextButton(
                onPressed: () => unawaited(openAmazonLink(url)),
                child: Text(
                  context.l10n.recipesFromCreator(recipe.sourceHandle ?? ''),
                ),
              ),
            ],
            if (recipe.steps.isNotEmpty) ...<Widget>[
              const SizedBox(height: ZadSpacing.xl),
              _Heading(context.l10n.chefMethodHeading),
              for (final (i, step) in recipe.steps.indexed)
                _Step(number: i + 1, text: step),
            ],
            const SizedBox(height: ZadSpacing.xl),
            // Kotlin's RecipeDetailDialog: the full recipe, step by step.
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => unawaited(showRecipeDetail(context, recipe)),
                icon: const Icon(ZadIcons.chef),
                label: Text(context.l10n.chefStepByStep),
              ),
            ),
            const SizedBox(height: ZadSpacing.sm),
            if (toBuy.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _addMissing(context, controller),
                  icon: const Icon(ZadIcons.shopping),
                  label: Text(context.l10n.chefAddMissing(toBuy.length)),
                ),
              )
            else if (recipe.missing.isNotEmpty)
              Text(
                context.l10n.chefNothingToAdd,
                style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
              ),
            const SizedBox(height: ZadSpacing.lg),
            RecipeRatingRow(recipe: recipe),
          ],
        ),
      ),
    );
  }

  Future<void> _addMissing(
    BuildContext context,
    RecipesController controller,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l = context.l10n;
    final added = await controller.addMissingToList(recipe);
    // Not awaited: the message must not wait on a vibration motor.
    unawaited(HapticFeedback.lightImpact());
    messenger?.showSnackBar(
      SnackBar(
        content: Text(added == 1 ? l.chefAddedOne : l.chefAddedMany(added)),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const new(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: ZadSpacing.sm),
    child: Text(text, style: ZadType.titleSmall),
  );
}

class _Ingredient extends StatelessWidget {
  const new({required this.name, required this.have});

  final String name;
  final bool have;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: ZadSpacing.xs),
    child: Row(
      children: <Widget>[
        Icon(
          have ? ZadIcons.selected : ZadIcons.shopping,
          size: 16,
          color: have ? ZadColors.green600 : ZadColors.mustardOchre,
        ),
        const SizedBox(width: ZadSpacing.sm),
        Expanded(
          child: Text(
            name,
            style: ZadType.bodySmall.copyWith(color: ZadColors.slate),
          ),
        ),
      ],
    ),
  );
}

class _Step extends StatelessWidget {
  const new({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: ZadSpacing.xs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 24,
          child: Text(
            '$number.',
            style: ZadType.labelMedium.copyWith(color: ZadColors.green700),
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: ZadType.bodySmall.copyWith(color: ZadColors.slate),
          ),
        ),
      ],
    ),
  );
}

/// "٢٠ دقيقة · ~٤٥ ج.م", leaving out whatever the chef did not say.
String _meta(BuildContext context, Recipe recipe, String currency) => <String>[
  if (recipe.prepMinutes > 0) context.l10n.chefMinutes(recipe.prepMinutes),
  if (recipe.costEstimate > 0)
    '~${recipe.costEstimate.round()}${currency.isEmpty ? '' : ' $currency'}',
].join(' · ');

/// A dish's drawing, from its name — Kotlin's `dishEmojiFor`, drawn instead
/// of an emoji, for when there is no photograph. Display only; nothing is
/// stored on it.
Widget dishArt(String name, double size) {
  // l10n: data-begin
  final kind = switch (name) {
    _ when name.contains('كشري') => ZadProductArt.koshari,
    _ when name.contains('بيض') => ZadProductArt.eggs,
    _ when name.contains('تونة') || name.contains('سمك') => ZadProductArt.fish,
    _ when name.contains('دجاج') || name.contains('فراخ') =>
      ZadProductArt.chicken,
    _ when name.contains('لحم') || name.contains('كفتة') => ZadProductArt.meat,
    _ when name.contains('أرز') || name.contains('رز') => ZadProductArt.rice,
    _ when name.contains('سلطة') => ZadProductArt.salad,
    _ when name.contains('مكرونة') || name.contains('باستا') =>
      ZadProductArt.pasta,
    _ when name.contains('خبز') || name.contains('عيش') => ZadProductArt.bread,
    _ => null,
  };
  // l10n: data-end
  return kind == null
      ? ZadArt.icon(ZadIconArt.pot, size: size)
      : ZadArt.product(kind, size: size);
}

/// «عجبتك؟»: like or dislike, sent through the outbox to `rate_recipe`, which
/// the next «شيف زاد» suggestions read. On the recipe sheet and on the full
/// recipe — the dialog is where the dish is actually cooked from, and with the
/// row only on the sheet 98 suggestions got no opinion at all (2026-09-29).
class RecipeRatingRow extends ConsumerWidget {
  /// Creates the row.
  const new({required this.recipe, super.key});

  /// The recipe rated.
  final Recipe recipe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(recipesControllerProvider.notifier);
    final rating = ref.watch(
      recipesControllerProvider.select((v) => v.ratings[recipe.name]),
    );
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            context.l10n.chefRatePrompt,
            style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
          ),
        ),
        IconButton(
          onPressed: () => unawaited(controller.rate(recipe, liked: true)),
          isSelected: rating ?? false,
          color: ZadColors.inkMuted,
          selectedIcon: const Icon(ZadIcons.like, color: ZadColors.green700),
          icon: const Icon(ZadIcons.like),
          tooltip: context.l10n.chefLike,
        ),
        IconButton(
          onPressed: () => unawaited(controller.rate(recipe, liked: false)),
          isSelected: rating == false,
          color: ZadColors.inkMuted,
          selectedIcon: Icon(ZadIcons.dislike, color: ZadColors.terracottaRust),
          icon: const Icon(ZadIcons.dislike),
          tooltip: context.l10n.chefDislike,
        ),
      ],
    );
  }
}

/// «سر الشيف»: the one trick that makes this dish, on a warm card.
class _ChefSecret extends StatelessWidget {
  const new(this.secret);

  final String secret;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey<String>('recipe-chef-secret'),
    padding: const EdgeInsets.all(ZadSpacing.md),
    decoration: BoxDecoration(
      color: ZadColors.mustardLight.withValues(alpha: 0.22),
      borderRadius: BorderRadius.circular(ZadRadii.chip),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(
          Icons.auto_awesome_rounded,
          size: 20,
          color: ZadColors.mustardOchre,
        ),
        const SizedBox(width: ZadSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                context.l10n.recipesChefSecret,
                style: ZadType.labelMedium.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: ZadSpacing.xs),
              Text(secret, style: ZadType.bodyMedium),
            ],
          ),
        ),
      ],
    ),
  );
}
