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
import 'package:zad/data/providers.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/inventory/application/pantry_controller.dart';
import 'package:zad/features/inventory/application/shopping_controller.dart';
import 'package:zad/features/recipes/domain/recipe.dart';
import 'package:zad/features/recipes/presentation/recipes_view.dart';

/// Opens the full recipe.
Future<void> showRecipeDetail(BuildContext context, Recipe recipe) =>
    showDialog<void>(
      context: context,
      builder: (_) => RecipeDetailDialog(recipe: recipe),
    );

typedef _Parsed = ({List<String> ingredients, List<String> steps});

final RegExp _numbered = RegExp(r'^\d+[.)\-]+\s*');

/// Kotlin's `parseRecipeContent`: sections by their Arabic headings, bullets
/// and numbers stripped; everything as steps when no heading is found.
_Parsed _parse(String text) {
  final lines = text.split('\n');
  final ingredients = <String>[];
  final steps = <String>[];
  var section = '';
  for (final line in lines) {
    final t = line.trim();
    if (t.contains('المقادير')) {
      section = 'ingredients';
      continue;
    }
    if (t.contains('طريقة التحضير') ||
        t.contains('الطريقة') ||
        t.contains('التحضير')) {
      section = 'steps';
      continue;
    }
    if (t.isEmpty) continue;
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
    );
  }
  return (ingredients: ingredients, steps: steps);
}

/// Kotlin's `recipeTextFromKnown`: the card's own steps in the parser's
/// shape, so no network call is needed to show them.
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

String _deterministic(String name) =>
    '''
🍲 **طريقة تحضير $name**

⏱️ **وقت التحضير**: ٢٥ دقيقة تقريباً

🥗 **المكونات والمقادير**:
• المكونات الأساسية المتوفرة بمخزون المنزل
• ملعقة زيت طهي أو زبدة
• بهارات حسب الرغبة (ملح، فلفل أسود، كمون)

👩‍🍳 **خطوات التحضير السريعة**:
1. جهّز المكونات المتاحة وقم بغسلها وتقطيعها إلى قطع متساوية.
2. ضع المقلاة أو القدر على نار متوسطة مع قليل من الزيت أو الزبدة.
3. شوّح المكونات تدريجياً حتى تكتسب لوناً ذهبياً شهياً وتنضج بالكامل.
4. أضف البهارات والملح واضبط النكهة حسب رغبتك.
5. ارفع الطبق عن النار وقدّمه ساخناً بالهناء والشفاء! ✨''';

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
  final Set<int> _checked = <int>{};

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final known = _knownText(widget.recipe);
    if (known != null && _retry == 0) {
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
        .map((i) => '${i.itemName} (${i.quantity})')
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
                'inventory': pantry.isEmpty ? 'لا يوجد مخزون حاليا' : pantry,
              },
            },
          )
          .timeout(const Duration(seconds: 12));
      final data = response.data;
      final t = data is Map ? data['text'] : null;
      text = t is String && t.trim().isNotEmpty
          ? t
          : _deterministic(widget.recipe.name);
    } on TimeoutException {
      text = _deterministic(widget.recipe.name);
    } on Object {
      if (!mounted) return;
      setState(() {
        _error = 'عذراً، حدث خطأ أثناء تحميل الوصفة';
        _loading = false;
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _text = text;
      _loading = false;
    });
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
    Navigator.of(context).pop();
    messenger?.showSnackBar(
      SnackBar(content: Text('ضفت ${toAdd.length} أصناف لقايمة التسوق.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final parsed = _text.isEmpty
        ? (ingredients: const <String>[], steps: const <String>[])
        : _parse(_text);
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: size.width * 0.04,
        vertical: size.height * 0.075,
      ),
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
                        child: CircularProgressIndicator(strokeWidth: 4),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'شيف زاد يجهز لك الوصفة…',
                        style: ZadType.bodyLarge.copyWith(
                          color: ZadColors.inkMuted,
                        ),
                      ),
                    ],
                  )
                : _error != null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const Text('⚠️', style: ZadType.headlineLarge),
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
                        label: const Text('إعادة المحاولة'),
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ZadSpacing.lg,
                      vertical: ZadSpacing.md,
                    ),
                    children: <Widget>[
                      if (parsed.ingredients.isNotEmpty)
                        _Section(
                          title: '🥐 المقادير',
                          color: ZadColors.green700,
                          children: <Widget>[
                            for (final (i, item) in parsed.ingredients.indexed)
                              CheckboxListTile(
                                dense: true,
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
                          title: '👨‍🍳 طريقة التحضير',
                          color: ZadColors.mustardOchre,
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
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: ZadColors.mint100,
                                      ),
                                      child: Text(
                                        '${i + 1}',
                                        style: ZadType.labelSmall.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: ZadColors.green800,
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
                    ],
                  ),
          ),
          DecoratedBox(
            decoration: const BoxDecoration(
              color: ZadColors.surface,
              border: Border(top: BorderSide(color: ZadColors.outlineVariant)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ZadSpacing.lg,
                vertical: ZadSpacing.md,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ZadColors.inkMuted,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          'إغلاق',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                  if (parsed.ingredients.isNotEmpty) ...<Widget>[
                    const SizedBox(width: ZadSpacing.md),
                    Expanded(
                      flex: 13,
                      child: SizedBox(
                        height: 48,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () =>
                              unawaited(_addToShopping(parsed.ingredients)),
                          icon: const Icon(ZadIcons.shopping, size: 18),
                          label: const Text(
                            'إضافة النواقص لقائمة التسوق',
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
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
          colors: <Color>[
            ZadColors.green800,
            ZadColors.green700,
            ZadColors.mintGlow,
          ],
        ),
      ),
      child: Center(
        child: Text(
          dishEmoji(recipe.name),
          style: const TextStyle(fontSize: 72),
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
            Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => glyph,
            ),
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
              tooltip: 'إغلاق',
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
  const new({required this.title, required this.color, required this.children});

  final String title;
  final Color color;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: ZadColors.surface,
      borderRadius: BorderRadius.circular(20),
      boxShadow: const <BoxShadow>[
        BoxShadow(
          color: ZadColors.shadowSpot,
          blurRadius: 6,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: ZadType.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: ZadSpacing.md),
          ...children,
        ],
      ),
    ),
  );
}
