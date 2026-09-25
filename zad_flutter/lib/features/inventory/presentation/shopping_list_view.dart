/// The shopping list — Kotlin's `ShoppingListScreen`: the basket against the
/// budget, "تعبئة ذكية" and the WhatsApp share, the priority chips, "قد
/// تحتاج أيضاً", and each line's price, store, days left, tick and delete.
///
/// Kotlin asks the model for suggestions and prices every time the list
/// opens. Here both are one tap on "تعبئة ذكية" — the rule for this client
/// is that no screen calls a model on its own.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:share_plus/share_plus.dart';
import 'package:zad/core/money/money.dart';
import 'package:zad/data/providers.dart';
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
import 'package:zad/features/inventory/data/shopping_ai_remote.dart';
import 'package:zad/features/inventory/domain/shopping_item.dart';

String _money(double v) => NumberFormat('#,##0.##', 'en').format(v);

/// The basket's cost at the prices known, or null when no line has one —
/// Kotlin's distinction between "zero" and "we do not know".
double? basketTotal(Iterable<ShoppingItem> outstanding) {
  var known = false;
  var total = 0.0;
  for (final i in outstanding) {
    if (i.estimatedPrice > 0) {
      known = true;
      total += i.estimatedPrice * i.quantity;
    }
  }
  return known ? total : null;
}

/// The list as text to share — Kotlin's WhatsApp message.
String shoppingShareText(Iterable<ShoppingItem> outstanding, String currency) {
  final lines = <String>[
    for (final i in outstanding)
      '• ${i.itemName}${i.quantity > 1 ? ' × ${i.quantity}' : ''}',
  ];
  final total = basketTotal(outstanding);
  return <String>[
    'قائمة تسوق زاد:',
    ...lines,
    if (total != null) '\nالإجمالي: ${_money(total)} $currency'.trimRight(),
  ].join('\n');
}

/// The shopping list.
class ShoppingListView extends ConsumerStatefulWidget {
  /// Creates the view.
  const new({super.key});

  @override
  ConsumerState<ShoppingListView> createState() => _ShoppingListViewState();
}

class _ShoppingListViewState extends ConsumerState<ShoppingListView> {
  final TextEditingController _entry = TextEditingController();
  ShoppingPriority? _priority;
  List<GrocerySuggestion> _suggestions = const <GrocerySuggestion>[];
  bool _filling = false;

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final text = _entry.text.trim();
    if (text.isEmpty) return;
    _entry.clear();
    setState(() {});
    await ref.read(shoppingControllerProvider.notifier).add(text);
  }

  /// "تعبئة ذكية": what the house may need, and prices for up to five lines
  /// that have none — the two calls Kotlin makes on open.
  Future<void> _smartFill() async {
    final userId = ref.read(signedInUserIdProvider)();
    if (userId == null || _filling) return;
    setState(() => _filling = true);
    final ai = ref.read(shoppingAiRemoteProvider);
    final pantry = ref.read(pantryControllerProvider).items;
    final inventory = pantry.isEmpty
        ? 'لا يوجد'
        : pantry.map((i) => '${i.itemName} (${i.quantity})').join(', ');
    try {
      final suggestions = await ai.suggest(
        userId: userId,
        inventory: inventory,
      );
      final have = <String>{
        for (final i in ref.read(shoppingControllerProvider).items) i.itemName,
      };
      if (mounted) {
        setState(
          () => _suggestions = <GrocerySuggestion>[
            for (final s in suggestions)
              if (!have.contains(s.name)) s,
          ],
        );
      }
      final unpriced = ref
          .read(shoppingControllerProvider)
          .outstanding
          .where((i) => i.estimatedPrice <= 0)
          .take(5)
          .toList();
      for (final item in unpriced) {
        final price = await ai.estimatePrice(
          userId: userId,
          itemName: item.itemName,
        );
        if (price != null) {
          await ref
              .read(shoppingControllerProvider.notifier)
              .setEstimatedPrice(item.id, price);
        }
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('مقدرتش أوصل لزاد دلوقتي. جرّب تاني.')),
        );
      }
    } finally {
      if (mounted) setState(() => _filling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(shoppingControllerProvider);
    final controller = ref.read(shoppingControllerProvider.notifier);
    final budget = ref.watch(budgetControllerProvider);
    final currency = budget.snapshot?.currency ?? '';
    final outstanding = view.outstanding
        .where((i) => _priority == null || i.priority == _priority)
        .toList();

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            ZadSpacing.gutter,
            ZadSpacing.md,
            ZadSpacing.gutter,
            0,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _entry,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => unawaited(_add()),
                  decoration: const InputDecoration(
                    hintText: 'محتاج تشتري إيه؟',
                    filled: true,
                    fillColor: ZadColors.surface,
                  ),
                ),
              ),
              const SizedBox(width: ZadSpacing.sm),
              IconButton.filled(
                onPressed: _entry.text.trim().isEmpty
                    ? null
                    : () => unawaited(_add()),
                icon: const Icon(ZadIcons.add),
                tooltip: 'ضيف',
              ),
              IconButton(
                onPressed: () => unawaited(showAddShoppingSheet(context)),
                icon: const Icon(ZadIcons.edit),
                tooltip: 'إضافة منتج للقائمة',
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: controller.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(ZadSpacing.gutter),
              children: <Widget>[
                _BudgetHeader(
                  total: basketTotal(view.outstanding),
                  remaining: budget.spendable,
                  limit: budget.snapshot?.openingBalance,
                  currency: currency,
                ),
                const SizedBox(height: ZadSpacing.md),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _filling
                            ? null
                            : () => unawaited(_smartFill()),
                        icon: _filling
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(ZadIcons.assistant, size: 16),
                        label: const Text('تعبئة ذكية'),
                        style: OutlinedButton.styleFrom(
                          shape: const StadiumBorder(),
                          minimumSize: const Size(0, 44),
                        ),
                      ),
                    ),
                    const SizedBox(width: ZadSpacing.sm),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: view.outstanding.isEmpty
                            ? null
                            : () => unawaited(
                                SharePlus.instance.share(
                                  ShareParams(
                                    text: shoppingShareText(
                                      view.outstanding,
                                      currency,
                                    ),
                                  ),
                                ),
                              ),
                        icon: const Icon(ZadIcons.send, size: 16),
                        label: const Text('واتساب'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          shape: const StadiumBorder(),
                          minimumSize: const Size(0, 44),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_suggestions.isNotEmpty) ...<Widget>[
                  const SizedBox(height: ZadSpacing.md),
                  _Suggestions(
                    suggestions: _suggestions,
                    onAdd: (s) {
                      setState(
                        () => _suggestions = <GrocerySuggestion>[
                          for (final x in _suggestions)
                            if (x != s) x,
                        ],
                      );
                      unawaited(controller.add(s.name));
                    },
                  ),
                ],
                const SizedBox(height: ZadSpacing.md),
                Wrap(
                  spacing: ZadSpacing.sm,
                  children: <Widget>[
                    for (final (p, label) in <(ShoppingPriority?, String)>[
                      (null, 'الكل'),
                      (ShoppingPriority.high, 'حرج'),
                      (ShoppingPriority.medium, 'متوسط'),
                      (ShoppingPriority.low, 'منخفض'),
                    ])
                      ChoiceChip(
                        label: Text(label),
                        selected: _priority == p,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _priority = p),
                      ),
                  ],
                ),
                const SizedBox(height: ZadSpacing.md),
                if (view.isEmpty)
                  const ZadEmptyState(
                    icon: ZadIcons.shopping,
                    title: 'قائمة التسوق فارغة',
                    message: 'زاد سيضيف النواقص تلقائياً!',
                  )
                else if (outstanding.isEmpty && view.outstanding.isNotEmpty)
                  const ZadEmptyState(
                    icon: ZadIcons.search,
                    title: 'لا توجد عناصر بهذا التصنيف',
                    message: 'جرّب أولوية تانية.',
                  ),
                for (final item in outstanding) ...<Widget>[
                  _Line(item: item, currency: currency),
                  const SizedBox(height: ZadSpacing.sm),
                ],
                if (view.bought.isNotEmpty) ...<Widget>[
                  const SizedBox(height: ZadSpacing.lg),
                  Text(
                    'اتشترى',
                    style: ZadType.labelMedium.copyWith(
                      color: ZadColors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: ZadSpacing.sm),
                  for (final item in view.bought) ...<Widget>[
                    _Line(item: item, currency: currency),
                    const SizedBox(height: ZadSpacing.sm),
                  ],
                ],
                const SizedBox(height: 88),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// "سلة زاد الذكية": the basket, what is left to spend, the share of the
/// budget, and a warning when the basket is more than is left.
class _BudgetHeader extends StatelessWidget {
  const new({
    required this.total,
    required this.remaining,
    required this.limit,
    required this.currency,
  });

  final double? total;
  final double? remaining;
  final double? limit;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final basket = total;
    final left = remaining;
    final cap = limit;
    final pct = basket != null && cap != null && cap > 0
        ? (basket / cap * 100).clamp(0, 100).toInt()
        : 0;
    final over = basket != null && left != null && basket > left;
    return Container(
      padding: const EdgeInsets.all(ZadSpacing.lg),
      decoration: ShapeDecoration(
        gradient: ZadColors.wallet,
        shape: zadSquircle(ZadRadii.cardLarge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'سلة زاد الذكية',
            style: ZadType.labelLarge.copyWith(
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: ZadSpacing.xs),
          Text(
            basket == null
                ? '— $currency'.trim()
                : '${_money(basket)} $currency',
            style: ZadType.figure(28).copyWith(color: Colors.white),
          ),
          const SizedBox(height: ZadSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  left == null
                      ? 'الميزانية المتبقية: —'
                      : 'الميزانية المتبقية: ${_money(left)} $currency',
                  style: ZadType.labelMedium.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ),
              if (basket != null && cap != null && cap > 0)
                Text(
                  '$pct% من الميزانية',
                  style: ZadType.labelMedium.copyWith(color: Colors.white),
                ),
            ],
          ),
          if (over) ...<Widget>[
            const SizedBox(height: ZadSpacing.sm),
            Text(
              'هذه القائمة تتجاوز الميزانية المتبقية!',
              style: ZadType.labelMedium.copyWith(
                color: const Color(0xFFFFA69E),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Suggestions extends StatelessWidget {
  const new({required this.suggestions, required this.onAdd});

  final List<GrocerySuggestion> suggestions;
  final ValueChanged<GrocerySuggestion> onAdd;

  @override
  Widget build(BuildContext context) => ZadCard(
    color: ZadColors.mint50,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('قد تحتاج أيضاً', style: ZadType.titleSmall),
        const SizedBox(height: ZadSpacing.sm),
        for (final s in suggestions)
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      s.quantity.isEmpty ? s.name : '${s.name} · ${s.quantity}',
                      style: ZadType.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (s.reason.isNotEmpty)
                      Text(
                        s.reason,
                        style: ZadType.bodySmall.copyWith(
                          color: ZadColors.inkMuted,
                        ),
                      ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => onAdd(s),
                child: const Text('إضافة للقائمة'),
              ),
            ],
          ),
      ],
    ),
  );
}

class _Line extends ConsumerWidget {
  const new({required this.item, required this.currency});

  final ShoppingItem item;
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(shoppingControllerProvider.notifier);
    final (tag, tagColor) = switch (item.priority) {
      ShoppingPriority.high => ('حرج', ZadColors.terracottaRust),
      ShoppingPriority.medium => ('متوسط', ZadColors.mustardOchre),
      ShoppingPriority.low => ('منخفض', ZadColors.green600),
    };
    final details = <String>[
      if (item.estimatedPrice > 0)
        '${_money(item.estimatedPrice * item.quantity)} $currency'.trim(),
      if (item.store case final s? when s.isNotEmpty) s,
      if (item.predictedDaysLeft case final d? when !item.isPurchased)
        'ينفد بعد $d أيام',
    ];

    return Dismissible(
      key: ValueKey<String>(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => unawaited(controller.remove(item.id)),
      child: ZadCard(
        padding: const EdgeInsets.symmetric(horizontal: ZadSpacing.sm),
        // The tile paints its ink on the nearest Material; the card is a
        // decorated box, so one is put between them.
        child: Material(
          type: MaterialType.transparency,
          child: Row(
            children: <Widget>[
              Expanded(
                child: CheckboxListTile(
                  value: item.isPurchased,
                  onChanged: (v) {
                    final bought = v ?? false;
                    unawaited(controller.toggle(item.id, purchased: bought));
                    if (bought) {
                      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                        SnackBar(content: Text('تم شراء ${item.itemName}')),
                      );
                    }
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          item.quantity > 1
                              ? '${item.itemName} × ${item.quantity}'
                              : item.itemName,
                          style: ZadType.titleSmall.copyWith(
                            color: item.isPurchased
                                ? ZadColors.inkMuted
                                : ZadColors.ink,
                            decoration: item.isPurchased
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                        ),
                      ),
                      if (!item.isPurchased) ...<Widget>[
                        const SizedBox(width: ZadSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: tagColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(ZadRadii.pill),
                          ),
                          child: Text(
                            tag,
                            style: ZadType.labelSmall.copyWith(color: tagColor),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: details.isEmpty
                      ? null
                      : Text(
                          details.join(' · '),
                          style: ZadType.labelSmall.copyWith(
                            color: ZadColors.inkMuted,
                          ),
                        ),
                ),
              ),
              IconButton(
                onPressed: () => unawaited(controller.remove(item.id)),
                tooltip: 'حذف',
                icon: const Icon(
                  ZadIcons.delete,
                  size: 18,
                  color: ZadColors.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kotlin's `AddShoppingItemDialog`: name, count, estimated price, store.
Future<void> showAddShoppingSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ZadColors.surface,
      shape: zadSquircle(ZadRadii.sheet),
      builder: (_) => const _AddSheet(),
    );

class _AddSheet extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends ConsumerState<_AddSheet> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _qty = TextEditingController(text: '1');
  final TextEditingController _price = TextEditingController();
  final TextEditingController _store = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _qty.dispose();
    _price.dispose();
    _store.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _name.text.trim().isNotEmpty &&
      (parseMoneyInput(_qty.text)?.round() ?? 0) > 0;

  Future<void> _save() async {
    if (!_canSave) return;
    await ref
        .read(shoppingControllerProvider.notifier)
        .add(
          _name.text,
          quantity: parseMoneyInput(_qty.text)!.round(),
          estimatedPrice: parseMoneyInput(_price.text) ?? 0,
          store: _store.text,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(ZadSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text('إضافة منتج للقائمة', style: ZadType.titleMedium),
          const SizedBox(height: ZadSpacing.lg),
          TextField(
            controller: _name,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'اسم المنتج'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: ZadSpacing.md),
          TextField(
            controller: _qty,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(labelText: 'الكمية'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: ZadSpacing.md),
          TextField(
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(labelText: 'السعر التقديري'),
          ),
          const SizedBox(height: ZadSpacing.md),
          TextField(
            controller: _store,
            decoration: const InputDecoration(labelText: 'المتجر (اختياري)'),
          ),
          const SizedBox(height: ZadSpacing.xl),
          FilledButton(
            onPressed: _canSave ? _save : null,
            child: const Text('إضافة'),
          ),
        ],
      ),
    ),
  );
}
