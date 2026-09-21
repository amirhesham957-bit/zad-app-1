/// شيف زاد: what to cook from what is in the kitchen.
///
/// The section opens on the last answer and never asks on its own — the
/// button at the bottom does. It says when the pantry has changed since, so
/// an old answer is not mistaken for a current one.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/design/components/zad_card.dart';
import 'package:zad/design/components/zad_empty_state.dart';
import 'package:zad/design/foundation/squircle.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/budget/application/budget_controller.dart';
import 'package:zad/features/inventory/application/pantry_controller.dart';
import 'package:zad/features/inventory/application/shopping_controller.dart';
import 'package:zad/features/recipes/application/recipes_controller.dart';
import 'package:zad/features/recipes/domain/recipe.dart';

/// The recipes section.
class RecipesView extends ConsumerWidget {
  /// Creates the section.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(recipesControllerProvider);
    final pantry = ref.watch(pantryControllerProvider.select((v) => v.items));
    final hasStock = stockedPantry(pantry).isNotEmpty;
    final suggestions = view.suggestions;
    final isStale =
        suggestions != null &&
        suggestions.pantrySignature != pantrySignature(pantry);

    return Column(
      children: <Widget>[
        Expanded(
          child: CustomScrollView(
            slivers: <Widget>[
              if (view.error != null)
                const _Note(
                  icon: ZadIcons.failed,
                  color: ZadColors.terracottaRust,
                  text: 'مقدرتش أوصل لشيف زاد. جرّب تاني بعد شوية.',
                )
              else if (isStale && hasStock)
                const _Note(
                  icon: ZadIcons.inventory,
                  color: ZadColors.mustardOchre,
                  text: 'مخزنك اتغيّر من آخر اقتراحات — اطلب جديدة لو حابب.',
                ),
              if (suggestions == null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: hasStock
                      ? const ZadEmptyState(
                          icon: ZadIcons.chef,
                          title: 'شيف زاد جاهزة',
                          message:
                              'دوس «وصفات من مخزني» وهتقولك تطبخ إيه من اللي '
                              'عندك، واللي ناقصه حاجة بسيطة.',
                        )
                      : const ZadEmptyState(
                          icon: ZadIcons.chef,
                          title: 'المخزن فاضي',
                          message:
                              'ضيف اللي عندك في المخزن، وشيف زاد تقترح أكلات '
                              'منه.',
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
                ..._group('من مخزونك', suggestions.fromPantry),
                ..._group('وجبات تانية', suggestions.needShopping),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: ZadSpacing.lg)),
            ],
          ),
        ),
        // The one action, in the thumb's reach.
        Padding(
          padding: const EdgeInsets.fromLTRB(
            ZadSpacing.gutter,
            0,
            ZadSpacing.gutter,
            ZadSpacing.lg,
          ),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: view.isAsking || !hasStock
                  ? null
                  : () => unawaited(
                      ref.read(recipesControllerProvider.notifier).ask(),
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
                    ? 'شيف زاد بتفكر…'
                    : suggestions == null
                    ? 'وصفات من مخزني'
                    : 'اقتراحات جديدة',
              ),
            ),
          ),
        ),
      ],
    );
  }

  static List<Widget> _group(String title, List<Recipe> recipes) {
    if (recipes.isEmpty) return const <Widget>[];
    return <Widget>[
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          ZadSpacing.gutter,
          ZadSpacing.xl,
          ZadSpacing.gutter,
          ZadSpacing.sm,
        ),
        sliver: SliverToBoxAdapter(
          child: Text(
            title,
            style: ZadType.labelMedium.copyWith(color: ZadColors.inkMuted),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: ZadSpacing.gutter),
        sliver: SliverList.separated(
          itemCount: recipes.length,
          separatorBuilder: (_, _) => const SizedBox(height: ZadSpacing.sm),
          itemBuilder: (_, i) => _RecipeCard(recipe: recipes[i]),
        ),
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
      child: ZadCard(
        color: color.withValues(alpha: 0.08),
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
  Widget build(BuildContext context) => ZadCard(
    color: ZadColors.mint50,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Icon(ZadIcons.chef, size: 20, color: ZadColors.green700),
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
    return ZadCard(
      onTap: () => unawaited(showRecipeSheet(context, recipe)),
      child: Row(
        children: <Widget>[
          _Dish(recipe: recipe, size: 48),
          const SizedBox(width: ZadSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  recipe.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: ZadType.titleSmall,
                ),
                const SizedBox(height: ZadSpacing.xs),
                Text(
                  _meta(recipe, currency),
                  style: ZadType.labelSmall.copyWith(
                    color: ZadColors.inkMuted,
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
          complete ? 'مكتملة' : 'ناقصك ${recipe.missing.length}',
          style: ZadType.labelSmall.copyWith(color: color),
        ),
      ),
    );
  }
}

/// The dish's photograph when the server found one, its glyph otherwise.
class _Dish extends StatelessWidget {
  const new({required this.recipe, required this.size});

  final Recipe recipe;
  final double size;

  @override
  Widget build(BuildContext context) {
    final glyph = Center(
      child: Text(dishEmoji(recipe.name), style: TextStyle(fontSize: size / 2)),
    );
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
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => glyph,
                ),
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
    final rating = ref.watch(
      recipesControllerProvider.select((v) => v.ratings[recipe.name]),
    );
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
                        _meta(recipe, currency),
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
            if (recipe.used.isNotEmpty) ...<Widget>[
              const SizedBox(height: ZadSpacing.xl),
              const _Heading('من عندك'),
              for (final item in recipe.used)
                _Ingredient(name: item, have: true),
            ],
            if (recipe.missing.isNotEmpty) ...<Widget>[
              const SizedBox(height: ZadSpacing.lg),
              const _Heading('ناقصك'),
              for (final item in recipe.missing)
                _Ingredient(name: item, have: false),
            ],
            if (recipe.steps.isNotEmpty) ...<Widget>[
              const SizedBox(height: ZadSpacing.xl),
              const _Heading('الطريقة'),
              for (final (i, step) in recipe.steps.indexed)
                _Step(number: i + 1, text: step),
            ],
            const SizedBox(height: ZadSpacing.xl),
            if (toBuy.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _addMissing(context, controller),
                  icon: const Icon(ZadIcons.shopping),
                  label: Text('ضيف الناقص لقايمة التسوق (${toBuy.length})'),
                ),
              )
            else if (recipe.missing.isNotEmpty)
              Text(
                'الناقص كله في قايمة التسوق أو المخزن.',
                style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
              ),
            const SizedBox(height: ZadSpacing.lg),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'عجبتك؟ شيف زاد بتفتكر.',
                    style: ZadType.bodySmall.copyWith(
                      color: ZadColors.inkMuted,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () =>
                      unawaited(controller.rate(recipe, liked: true)),
                  isSelected: rating ?? false,
                  color: ZadColors.inkMuted,
                  selectedIcon: const Icon(
                    ZadIcons.like,
                    color: ZadColors.green700,
                  ),
                  icon: const Icon(ZadIcons.like),
                  tooltip: 'عجبتني',
                ),
                IconButton(
                  onPressed: () =>
                      unawaited(controller.rate(recipe, liked: false)),
                  isSelected: rating == false,
                  color: ZadColors.inkMuted,
                  selectedIcon: const Icon(
                    ZadIcons.dislike,
                    color: ZadColors.terracottaRust,
                  ),
                  icon: const Icon(ZadIcons.dislike),
                  tooltip: 'مش لذوقي',
                ),
              ],
            ),
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
    final added = await controller.addMissingToList(recipe);
    // Not awaited: the message must not wait on a vibration motor.
    unawaited(HapticFeedback.lightImpact());
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          added == 1
              ? 'ضفت صنف لقايمة التسوق.'
              : 'ضفت $added أصناف لقايمة التسوق.',
        ),
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
String _meta(Recipe recipe, String currency) => <String>[
  if (recipe.prepMinutes > 0) '${recipe.prepMinutes} دقيقة',
  if (recipe.costEstimate > 0)
    '~${recipe.costEstimate.round()}${currency.isEmpty ? '' : ' $currency'}',
].join(' · ');

/// A dish's glyph, from its name — Kotlin's `dishEmojiFor`, for when there is
/// no photograph. Display only; nothing is stored or matched on it.
String dishEmoji(String name) => switch (name) {
  _ when name.contains('بيض') => '🍳',
  _ when name.contains('تونة') || name.contains('سمك') => '🐟',
  _ when name.contains('دجاج') || name.contains('فراخ') => '🍗',
  _ when name.contains('لحم') || name.contains('كفتة') => '🥩',
  _ when name.contains('أرز') || name.contains('رز') => '🍚',
  _ when name.contains('سلطة') => '🥗',
  _ when name.contains('مكرونة') || name.contains('باستا') => '🍝',
  _ when name.contains('شوربة') => '🍲',
  _ when name.contains('خبز') || name.contains('عيش') => '🍞',
  _ => '🍽️',
};
