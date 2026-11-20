/// Kotlin's `RecipeDetailDialog`: the full recipe — a 200dp header with the
/// dish photo (or its glyph on the brand gradient) and a close button, the
/// ingredients as a checklist, the numbered steps, and the footer's close
/// and «ضيف الناقص لقايمة التسوق» (the ingredients not ticked, or all of
/// them when none are).
///
/// A recipe the chef card already carries steps for shows at once; any other
/// asks `recipe_details` with the pantry, gives up after 12s, and falls back
/// to Kotlin's generic method rather than a spinner that never ends.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/components/zad_network_image.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/design/tokens/zad_world_colors.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/recipes/domain/recipe.dart';
import 'package:zad/features/recipes/presentation/cooked_sheet.dart';
import 'package:zad/features/recipes/presentation/recipes_view.dart';
import 'package:zad/shared/ads/presentation/ai_wait_ad.dart';
import 'package:zad/shared/ads/presentation/inline_ad.dart';
import 'package:zad/shared/affiliate/data/affiliate_repository.dart';
import 'package:zad/shared/chat/application/chat_controller.dart';
import 'package:zad/shared/inventory/application/pantry_controller.dart';
import 'package:zad/shared/inventory/application/shopping_controller.dart';
import 'package:zad/shared/inventory/domain/quantity.dart';
import 'package:zad/shared/navigation/zad_slots.dart';
import 'package:zad/shared/worlds/art/art.dart';
import 'package:zad/shared/worlds/world_card.dart';

/// Opens the full recipe.
Future<void> showRecipeDetail(BuildContext context, Recipe recipe) =>
    showDialog<void>(
      context: context,
      builder: (_) => RecipeDetailDialog(recipe: recipe),
    );

/// A recipe's three sections.
typedef RecipeParts = ({
  List<String> ingredients,
  List<String> steps,
  List<String> secrets,
});

final RegExp _numbered = RegExp(r'^\d+[.)\-]+\s*');

/// Kotlin's `parseRecipeContent`: sections by their Arabic headings, bullets
/// and numbers stripped; everything as steps when no heading is found.
@visibleForTesting
// l10n: data-begin
RecipeParts parseRecipeContent(String text) {
  final lines = text.split('\n');
  final ingredients = <String>[];
  final steps = <String>[];
  final secrets = <String>[];
  var section = '';
  for (final line in lines) {
    final t = line.trim();
    // A heading is a short line: a full step can say «التحضير» too.
    final isHeading = t.length <= 24;
    if (isHeading && t.contains('المقادير')) {
      section = 'ingredients';
      continue;
    }
    if (isHeading && (t.contains('الطريقة') || t.contains('التحضير'))) {
      section = 'steps';
      continue;
    }
    if (isHeading && t.contains('أسرار')) {
      section = 'secrets';
      continue;
    }
    if (t.isEmpty) continue;
    if (section == 'secrets') {
      final c = t.replaceFirst(RegExp(r'^[-•*·]\s*'), '').trim();
      if (c.isNotEmpty) secrets.add(c.replaceFirst(_numbered, ''));
      continue;
    }
    if (section == 'ingredients') {
      var c = t;
      for (final p in const <String>['- ', '• ', '* ', '· ']) {
        if (c.startsWith(p)) c = c.substring(p.length);
      }
      c = c.trim();
      if (c.isNotEmpty && !c.startsWith('#')) ingredients.add(c);
    } else if (section == 'steps') {
      final c = t.replaceFirst(_numbered, '').trim();
      if (c.isNotEmpty && !c.startsWith('#')) steps.add(c);
    }
  }
  if (ingredients.isEmpty && steps.isEmpty) {
    return (
      ingredients: const <String>[],
      steps: <String>[
        for (final line in lines)
          if (line.trim().isNotEmpty && !line.trim().startsWith('#'))
            line.trim().replaceFirst(_numbered, '').trim(),
      ].where((s) => s.isNotEmpty).toList(),
      secrets: const <String>[],
    );
  }
  return (ingredients: ingredients, steps: steps, secrets: secrets);
}

// l10n: data-end

/// Kotlin's `recipeTextFromKnown`: the card's own steps in the parser's
/// shape, so no network call is needed to show them.
// l10n: data-begin
String? _knownText(Recipe r) {
  if (r.steps.isEmpty) return null;
  final ingredients = <String>[...r.used, ...r.missing];
  final b = StringBuffer();
  if (ingredients.isNotEmpty) {
    b.writeln('المقادير:');
    for (final i in ingredients) {
      b.writeln('• $i');
    }
    b.writeln();
  }
  b.writeln('طريقة التحضير:');
  for (final (i, s) in r.steps.indexed) {
    b.writeln('${i + 1}. $s');
  }
  return b.toString().trim();
}
// l10n: data-end

/// The dialog.
class RecipeDetailDialog extends ConsumerStatefulWidget {
  /// Creates the dialog.
  const new({required this.recipe, super.key});

  /// The recipe.
  final Recipe recipe;

  @override
  ConsumerState<RecipeDetailDialog> createState() => _RecipeDetailState();
}

class _RecipeDetailState extends ConsumerState<RecipeDetailDialog> {
  bool _loading = true;
  String _text = '';
  String? _error;
  int _retry = 0;
  bool _full = false;
  // Counts recipes the model wrote (not the saved text), so each gets a
  // fresh ad (owner, 11/11: one ad per AI request).
  int _aiAnswers = 0;
  final Set<int> _checked = <int>{};

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final known = _knownText(widget.recipe);
    if (known != null && _retry == 0 && !_full) {
      setState(() {
        _text = known;
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final pantry = ref
        .read(pantryControllerProvider)
        .items
        .where((i) => i.quantity > 0)
        .map((i) => '${i.itemName} (${formatQuantity(i.quantity)})')
        .join(', ');
    String text;
    try {
      final client = ref.read(supabaseClientProvider);
      final response = await client.functions
          .invoke(
            'zad-core-intelligence',
            body: <String, dynamic>{
              'action': 'recipe_details',
              'user_id': client.auth.currentUser?.id,
              'payload': <String, dynamic>{
                'recipe_name': widget.recipe.name,
                'inventory': pantry.isEmpty
                    ? 'لا يوجد مخزون حاليا' // l10n: data
                    : pantry,
              },
            },
          )
          .timeout(const Duration(seconds: 30));
      final data = response.data;
      final t = data is Map ? data['text'] : null;
      // An empty answer or a slow one is said as such. Kotlin's template
      // («٢٥ دقيقة تقريباً», «المكونات الأساسية المتوفرة») read as the real
      // recipe of any dish, with nothing real in it (removed 2026-09-29).
      if (t is! String || t.trim().isEmpty) {
        if (!mounted) return;
        setState(() {
          _error = context.l10n.chefDetailEmpty;
          _loading = false;
        });
        return;
      }
      text = t;
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _error = context.l10n.chefDetailSlow;
        _loading = false;
      });
      return;
    } on Object {
      if (!mounted) return;
      setState(() {
        _error = context.l10n.chefDetailFailed;
        _loading = false;
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _text = text;
      _loading = false;
      _aiAnswers++;
    });
  }

  /// The chef answers in the one chat, about this dish (owner, 2026-11-09).
  void _askChef() {
    final navigator = Navigator.of(context);
    ref
        .read(chatPrefillProvider.notifier)
        .offer(context.l10n.chefAskPrefill(widget.recipe.name));
    navigator
      ..pop()
      ..push<void>(
        MaterialPageRoute<void>(builder: (_) => ZadSlots.chatScreen()),
      );
  }

  Future<void> _addToShopping(List<String> ingredients) async {
    final unticked = <String>[
      for (final (i, name) in ingredients.indexed)
        if (!_checked.contains(i)) name,
    ];
    final toAdd = unticked.isEmpty ? ingredients : unticked;
    final shopping = ref.read(shoppingControllerProvider.notifier);
    for (final name in toAdd) {
      await shopping.add(name);
    }
    unawaited(HapticFeedback.lightImpact());
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l = context.l10n;
    Navigator.of(context).pop();
    messenger?.showSnackBar(
      SnackBar(content: Text(l.chefAddedMany(toAdd.length))),
    );
  }

  Future<void> _cooked(List<String> ingredients) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l = context.l10n;
    final taken = await showCookedSheet(context, ref, ingredients);
    if (taken > 0) {
      messenger?.showSnackBar(SnackBar(content: Text(l.cookDoneSnack(taken))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final parsed = _text.isEmpty
        ? (
            ingredients: const <String>[],
            steps: const <String>[],
            secrets: const <String>[],
          )
        : parseRecipeContent(_text);
    final l = context.l10n;
    final source = widget.recipe.sourceUrl;
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: size.width * 0.04,
        vertical: size.height * 0.075,
      ),
      backgroundColor: ZadWorldColors.tint(ZadWorldColors.chef),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          _Header(
            recipe: widget.recipe,
            onClose: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: _loading
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const SizedBox.square(
                        dimension: 48,
                        child: CircularProgressIndicator(
                          strokeWidth: 4,
                          color: ZadWorldColors.chef,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        l.chefDetailLoading,
                        style: ZadType.bodyLarge.copyWith(
                          color: ZadColors.inkMuted,
                        ),
                      ),
                      const SizedBox(height: ZadSpacing.lg),
                      // One ad while the chef works (owner 15/11).
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: ZadSpacing.gutter,
                        ),
                        child: ZadAiWaitAd(),
                      ),
                    ],
                  )
                : _error != null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(
                        ZadIcons.failed,
                        size: 40,
                        color: ZadColors.terracottaRust,
                      ),
                      const SizedBox(height: ZadSpacing.md),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: ZadSpacing.xl,
                        ),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: ZadType.bodyLarge.copyWith(
                            color: ZadColors.terracottaRust,
                          ),
                        ),
                      ),
                      const SizedBox(height: ZadSpacing.lg),
                      OutlinedButton.icon(
                        onPressed: () {
                          _retry++;
                          unawaited(_load());
                        },
                        icon: const Icon(ZadIcons.retry, size: 16),
                        label: Text(l.chefDetailRetry),
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ZadSpacing.lg,
                      vertical: ZadSpacing.md,
                    ),
                    children: <Widget>[
                      if (!_full && widget.recipe.steps.isNotEmpty) ...<Widget>[
                        FilledButton.tonalIcon(
                          onPressed: () {
                            _full = true;
                            // Ticks are positions in the old list.
                            _checked.clear();
                            unawaited(_load());
                          },
                          icon: const Icon(Icons.auto_awesome, size: 18),
                          label: Text(l.chefFullRecipe),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            foregroundColor: ZadWorldColors.chef,
                            backgroundColor: ZadWorldColors.chef.withValues(
                              alpha: 0.12,
                            ),
                          ),
                        ),
                        const SizedBox(height: ZadSpacing.md),
                      ],
                      if (parsed.ingredients.isNotEmpty)
                        _Section(
                          title: l.chefDetailIngredients,
                          art: ZadIconArt.jar,
                          children: <Widget>[
                            for (final (i, item) in parsed.ingredients.indexed)
                              CheckboxListTile(
                                dense: true,
                                activeColor: ZadWorldColors.chef,
                                contentPadding: EdgeInsets.zero,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                value: _checked.contains(i),
                                onChanged: (v) => setState(
                                  () => (v ?? false)
                                      ? _checked.add(i)
                                      : _checked.remove(i),
                                ),
                                title: Text(
                                  item,
                                  style: ZadType.bodyMedium.copyWith(
                                    color: _checked.contains(i)
                                        ? ZadColors.inkMuted
                                        : ZadColors.ink,
                                    decoration: _checked.contains(i)
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      if (parsed.steps.isNotEmpty) ...<Widget>[
                        const SizedBox(height: ZadSpacing.lg),
                        _Section(
                          title: l.chefDetailSteps,
                          art: ZadIconArt.pot,
                          children: <Widget>[
                            for (final (i, step) in parsed.steps.indexed)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: ZadSpacing.xs,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Container(
                                      width: 26,
                                      height: 26,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: ZadWorldColors.chef.withValues(
                                          alpha: 0.12,
                                        ),
                                      ),
                                      child: Text(
                                        '${i + 1}',
                                        style: ZadType.labelSmall.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: ZadWorldColors.chef,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          step,
                                          style: ZadType.bodyMedium.copyWith(
                                            height: 1.7,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                      if (parsed.secrets.isNotEmpty) ...<Widget>[
                        const SizedBox(height: ZadSpacing.lg),
                        _Section(
                          title: l.chefSecrets,
                          art: ZadIconArt.star,
                          children: <Widget>[
                            for (final secret in parsed.secrets)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: ZadSpacing.xs,
                                ),
                                child: Text(
                                  secret,
                                  style: ZadType.bodyMedium.copyWith(
                                    height: 1.7,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                      if (_aiAnswers > 0)
                        ZadInlineAd(key: ValueKey<int>(_aiAnswers)),
                      const SizedBox(height: ZadSpacing.lg),
                      if (source != null)
                        OutlinedButton.icon(
                          onPressed: () => unawaited(openAmazonLink(source)),
                          icon: const Icon(Icons.play_circle_outline, size: 18),
                          label: Text(
                            widget.recipe.sourceHandle == null
                                ? l.chefSourceLink
                                : l.chefSourceHandle(
                                    widget.recipe.sourceHandle!,
                                  ),
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            foregroundColor: ZadWorldColors.chef,
                          ),
                        ),
                      const SizedBox(height: ZadSpacing.sm),
                      OutlinedButton.icon(
                        onPressed: _askChef,
                        icon: const Icon(Icons.chat_bubble_outline, size: 18),
                        label: Text(l.chefAsk),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          foregroundColor: ZadWorldColors.chef,
                        ),
                      ),
                      const SizedBox(height: ZadSpacing.lg),
                      RecipeRatingRow(recipe: widget.recipe),
                    ],
                  ),
          ),
          // The ✕ on the photo closes it; a second close button only squeezed
          // this one until its word vanished (seen on a phone, 2026-11-09).
          if (parsed.ingredients.isNotEmpty)
            DecoratedBox(
              decoration: BoxDecoration(
                color: ZadColors.surface,
                border: const Border(
                  top: BorderSide(color: ZadColors.hairline),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: ZadSpacing.lg,
                  vertical: ZadSpacing.md,
                ),
                child: Row(
                  children: <Widget>[
                    // The primary action, in the thumb zone. ZAD_PLAN 10.1
                    // slice 4c: what the dish used comes off the pantry,
                    // after the customer checks the amounts.
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: ZadWorldColors.chef,
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(ZadRadii.chip),
                          ),
                        ),
                        onPressed: () => unawaited(_cooked(parsed.ingredients)),
                        icon: const Icon(Icons.soup_kitchen_outlined, size: 18),
                        label: Text(l.cookDone, style: ZadType.labelLarge),
                      ),
                    ),
                    const SizedBox(width: ZadSpacing.sm),
                    Expanded(
                      flex: 3,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ZadWorldColors.chef,
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(ZadRadii.chip),
                          ),
                        ),
                        onPressed: () =>
                            unawaited(_addToShopping(parsed.ingredients)),
                        icon: const Icon(ZadIcons.shopping, size: 18),
                        label: Text(
                          l.chefDetailAddToShopping,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ZadType.labelLarge,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const new({required this.recipe, required this.onClose});

  final Recipe recipe;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final glyph = DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[ZadWorldColors.chef, Color(0xFFFF9A5C)],
        ),
      ),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ZadRadii.cardLarge),
          ),
          child: Padding(
            padding: const EdgeInsets.all(ZadSpacing.md),
            child: dishArt(recipe.name, 84),
          ),
        ),
      ),
    );
    final url = recipe.imageUrl ?? recipe.thumbUrl;
    return SizedBox(
      height: 200,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (url == null)
            glyph
          else
            ZadNetworkImage(url, fit: BoxFit.cover, fallback: glyph),
          if (url != null)
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: <double>[0.4, 1],
                  colors: <Color>[Colors.transparent, Color(0x80000000)],
                ),
              ),
            ),
          PositionedDirectional(
            top: ZadSpacing.sm,
            start: ZadSpacing.sm,
            child: IconButton(
              tooltip: context.l10n.chefDetailClose,
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: 0.3),
              ),
              onPressed: onClose,
              icon: const Icon(ZadIcons.dismiss, color: Colors.white),
            ),
          ),
          PositionedDirectional(
            bottom: ZadSpacing.lg,
            start: ZadSpacing.lg,
            end: ZadSpacing.lg,
            child: Text(
              recipe.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: ZadType.titleLarge.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const new({required this.title, required this.art, required this.children});

  final String title;
  final ZadIconArt art;
  final List<Widget> children;

  @override
  // The ingredients are CheckboxListTiles, and a ListTile's ink needs a
  // Material above this box's colour: without one, debug builds threw
  // "ListTile background color or ink splashes may be invisible" for every
  // recipe with ingredients — a red error in place of the list.
  Widget build(BuildContext context) => ZadWorldCard(
    child: Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              ZadArt.icon(art, size: 28),
              const SizedBox(width: ZadSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: ZadType.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    color: ZadWorldColors.chef,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: ZadSpacing.md),
          ...children,
        ],
      ),
    ),
  );
}
