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
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/components/zad_celebration.dart';
import 'package:zad/core/design/components/zad_empty_state.dart';
import 'package:zad/core/design/foundation/squircle.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/core/money/money.dart';
import 'package:zad/features/inventory/data/shopping_ai_remote.dart';
import 'package:zad/features/inventory/presentation/art_flight.dart';
import 'package:zad/features/inventory/presentation/shopping_world_scene.dart';
import 'package:zad/shared/ads/presentation/inline_ad.dart';
import 'package:zad/shared/affiliate/application/affiliate_match_controller.dart';
import 'package:zad/shared/affiliate/presentation/amazon_buy_chip.dart';
import 'package:zad/shared/budget/application/budget_controller.dart';
import 'package:zad/shared/inventory/application/pantry_controller.dart';
import 'package:zad/shared/inventory/application/shopping_controller.dart';
import 'package:zad/shared/inventory/domain/product_family.dart';
import 'package:zad/shared/inventory/domain/quantity.dart';
import 'package:zad/shared/inventory/domain/shopping_item.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/market/domain/market.dart';
import 'package:zad/shared/navigation/zad_slots.dart';
import 'package:zad/shared/worlds/art/art.dart';
import 'package:zad/shared/worlds/world_card.dart';
import 'package:zad/shared/worlds/world_row.dart';
import 'package:zad/shared/worlds/world_scaffold.dart';
import 'package:zad/shared/worlds/zad_world.dart';

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

/// The list as text to share — Kotlin's WhatsApp message. A staple's brands
/// are one bullet: «• مياه (إيلان / داساني)». The words around the lines
/// follow the app's language ([l]); the item names are the customer's own.
String shoppingShareText(
  ZadL10n l,
  Iterable<ShoppingItem> outstanding,
  String currency,
) {
  String bullet(ShoppingGroup g) {
    if (g.isFamily) {
      final brands = g.lines.map((l) => brandWithinFamily(l.itemName)).toSet();
      return '• ${g.name} (${brands.join(' / ')})';
    }
    final qty = g.lines.first.quantity;
    return '• ${g.name}${qty > 1 ? ' × $qty' : ''}';
  }

  final lines = <String>[
    for (final g in groupShoppingLines(outstanding)) bullet(g),
  ];
  final total = basketTotal(outstanding);
  final priced = outstanding.where((i) => i.estimatedPrice > 0).length;
  final all = outstanding.length;
  return <String>[
    l.shopShareHeader,
    ...lines,
    if (total != null)
      '\n${l.shopShareTotal(_money(total), currency)}'.trimRight() +
          // A total over some of the lines is not the basket's.
          (priced < all ? ' ${l.shopShareEstimate(priced, all)}' : ''),
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
  // Where a bought item's drawing lands: the pantry counter.
  final GlobalKey _counter = GlobalKey();
  ShoppingPriority? _priority;
  List<GrocerySuggestion> _suggestions = const <GrocerySuggestion>[];
  bool _filling = false;
  // Counts smart fills that brought suggestions, so each gets a fresh ad.
  int _fills = 0;

  @override
  void initState() {
    super.initState();
    // The list is kept alive across tabs, so opening it again only showed the
    // cache. A line the bot wrote while a live change was missed stayed
    // hidden until a restart (a tester, 2026-10-31: four lines on the server,
    // an empty list on two opens). One read each time the list is opened.
    unawaited(
      Future<void>.microtask(() async {
        if (mounted) {
          await ref.read(shoppingControllerProvider.notifier).refresh();
        }
      }),
    );
  }

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
        ? 'لا يوجد' // l10n: data
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
        setState(() {
          _suggestions = <GrocerySuggestion>[
            for (final s in suggestions)
              if (!have.contains(s.name)) s,
          ];
          if (_suggestions.isNotEmpty) _fills++;
        });
      }
      final unpriced = ref
          .read(shoppingControllerProvider)
          .outstanding
          .where((i) => i.estimatedPrice <= 0)
          .take(5)
          .toList();
      // In the customer's country and currency: an Egyptian basket was
      // priced from whatever the web answered, riyals included, and the
      // total came out wrong (owner, 2026-10-01).
      final country = ref.read(accountCountryProvider);
      final currency =
          ref.read(budgetControllerProvider).snapshot?.currency ?? '';
      for (final item in unpriced) {
        final price = await ai.estimatePrice(
          userId: userId,
          itemName: item.itemName,
          location: marketFor(country)?.nameAr ?? '',
          currency: currency,
        );
        if (price != null) {
          await ref
              .read(shoppingControllerProvider.notifier)
              .setEstimatedPrice(item.id, price);
        }
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)
            ?.showSnackBar(SnackBar(content: Text(context.l10n.shopNoReach)));
      }
    } finally {
      if (mounted) setState(() => _filling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // The last line ticked off: confetti, once, for that list.
    ref.listen(shoppingControllerProvider, (previous, next) {
      if (shoppingJustFinished(previous, next)) celebrate(context);
    });
    final view = ref.watch(shoppingControllerProvider);
    final controller = ref.read(shoppingControllerProvider.notifier);
    final budget = ref.watch(budgetControllerProvider);
    final currency = budget.snapshot?.currency ?? '';
    final outstanding = view.outstanding
        .where((i) => _priority == null || i.priority == _priority)
        .toList();
    // What the house already holds, beside each line: the list is read
    // against the pantry, not on its own (owner, 2026-10-01: «لازم يعرف ان
    // عندي الماية قد إيه»).
    final pantry = ref.watch(pantryControllerProvider.select((v) => v.items));

    // The lines by the shop each one is bought at; a line with no shop
    // waits under «أي محل» at the end.
    final byStore = <String, List<ShoppingGroup>>{};
    for (final g in groupShoppingLines(outstanding)) {
      final store = g.lines
          .map((i) => (i.store ?? '').trim())
          .firstWhere((s) => s.isNotEmpty, orElse: () => '');
      (byStore[store] ??= <ShoppingGroup>[]).add(g);
    }
    final stores = <String>[
      for (final s in byStore.keys)
        if (s.isNotEmpty) s,
    ]..sort((a, b) => byStore[b]!.length.compareTo(byStore[a]!.length));
    if (byStore.containsKey('')) stores.add('');
    final storeCount = view.outstanding
        .map((i) => (i.store ?? '').trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .length;

    final slivers = <Widget>[
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: ZadSpacing.gutter),
        sliver: SliverList.list(
          children: <Widget>[
            _BudgetCard(
              total: basketTotal(view.outstanding),
              priced: view.outstanding
                  .where((i) => i.estimatedPrice > 0)
                  .length,
              lines: view.outstanding.length,
              remaining: budget.spendable,
              limit: budget.snapshot?.openingBalance,
              currency: currency,
            ),
            const SizedBox(height: ZadSpacing.md),
            // The pantry counter: a bought item's drawing lands here.
            Row(
              key: _counter,
              children: <Widget>[
                ZadArt.icon(ZadIconArt.pantry, size: 24),
                const SizedBox(width: ZadSpacing.sm),
                Text(
                  l.shopPantryCount(pantry.length),
                  style: ZadType.labelMedium.copyWith(
                    color: ZadColors.inkMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: ZadSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _filling ? null : () => unawaited(_smartFill()),
                    icon: _filling
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(ZadIcons.assistant, size: 16),
                    label: Text(l.shopSmartFill),
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
                                  l,
                                  view.outstanding,
                                  currency,
                                ),
                              ),
                            ),
                          ),
                    icon: const Icon(ZadIcons.send, size: 16),
                    label: Text(l.shopWhatsApp),
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
              // One ad per AI request (owner, 11/11), under the card.
              ZadInlineAd(key: ValueKey<int>(_fills)),
            ],
            const SizedBox(height: ZadSpacing.md),
            Wrap(
              spacing: ZadSpacing.sm,
              children: <Widget>[
                for (final (p, label) in <(ShoppingPriority?, String)>[
                  (null, l.txFilterAll),
                  (ShoppingPriority.high, l.shopPriorityHigh),
                  (ShoppingPriority.medium, l.shopPriorityMedium),
                  (ShoppingPriority.low, l.shopPriorityLow),
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
              ZadEmptyState(
                icon: ZadIcons.shopping,
                title: l.shopEmptyTitle,
                message: l.shopEmptyBody,
              )
            else if (outstanding.isEmpty && view.outstanding.isNotEmpty)
              ZadEmptyState(
                icon: ZadIcons.search,
                title: l.shopFilterEmptyTitle,
                message: l.shopFilterEmptyBody,
              ),
            if (outstanding.isNotEmpty) const AmazonChipsNote(),
            for (final store in stores) ...<Widget>[
              _StoreHeader(
                name: store.isEmpty ? l.shopGroupAnyStore : store,
                count: byStore[store]!.length,
              ),
              ZadWorldCard(
                child: Column(
                  children: <Widget>[
                    for (final (i, group)
                        in byStore[store]!.indexed) ...<Widget>[
                      if (i > 0) const ZadWorldDivider(),
                      if (group.isFamily)
                        _FamilyLine(
                          group: group,
                          currency: currency,
                          stock: pantryStockFor(group.name, pantry),
                          pantryCounter: _counter,
                        )
                      else
                        _Line(
                          item: group.lines.first,
                          currency: currency,
                          stock: pantryStockFor(group.name, pantry),
                          pantryCounter: _counter,
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: ZadSpacing.md),
            ],
            ZadSlots.affiliateSuggestionSection(),
            // The live deals for what is short, next to the list it is
            // short on — it used to sit under «الديون».
            const SizedBox(height: ZadSpacing.md),
            ZadSlots.liveDealsCard(),
            if (view.bought.isNotEmpty) ...<Widget>[
              const SizedBox(height: ZadSpacing.lg),
              Text(
                l.shopBought,
                style: ZadType.labelMedium.copyWith(color: ZadColors.inkMuted),
              ),
              const SizedBox(height: ZadSpacing.sm),
              ZadWorldCard(
                child: Column(
                  children: <Widget>[
                    for (final (i, item) in view.bought.indexed) ...<Widget>[
                      if (i > 0) const ZadWorldDivider(),
                      _Line(
                        item: item,
                        currency: currency,
                        pantryCounter: _counter,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ];

    return ZadWorldScaffold(
      world: ZadWorld.shop,
      // The household page owns the back button (its app bar).
      showBack: false,
      eyebrow: l.shopWorldEyebrow(view.outstanding.length),
      title: l.worldLabelShop,
      stateLine: view.outstanding.isEmpty
          ? l.shopWorldDone
          : storeCount > 0
          ? l.shopWorldStores(storeCount)
          : l.shopWorldAnyStore,
      scene: (loop) =>
          ShopWorldScene(loop, filled: view.outstanding.isNotEmpty),
      zado: const ZadWorldZado(left: 30, top: 50, size: 140),
      onRefresh: controller.refresh,
      // The add row docks in its own strip under the list (the thumb zone),
      // so it never covers a line.
      dockHeight: 72,
      overlay: Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: _AddBar(
          controller: _entry,
          onChanged: () => setState(() {}),
          onAdd: () => unawaited(_add()),
          onManual: () => unawaited(showAddShoppingSheet(context)),
        ),
      ),
      slivers: slivers,
    );
  }
}

/// The add row, docked at the bottom: a name and «+», or the full sheet.
class _AddBar extends StatelessWidget {
  const new({
    required this.controller,
    required this.onChanged,
    required this.onAdd,
    required this.onManual,
  });

  final TextEditingController controller;
  final VoidCallback onChanged;
  final VoidCallback onAdd;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      ZadSpacing.gutter,
      ZadSpacing.sm,
      ZadSpacing.gutter,
      ZadSpacing.md,
    ),
    child: Row(
      children: <Widget>[
        Expanded(
          child: TextField(
            controller: controller,
            textInputAction: TextInputAction.done,
            onChanged: (_) => onChanged(),
            onSubmitted: (_) => onAdd(),
            // A rounded box like the cards over it, as tall as the buttons
            // beside it (owner, 2026-10-05).
            decoration: InputDecoration(
              hintText: context.l10n.shopAddHint,
              filled: true,
              fillColor: ZadColors.surface,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: ZadSpacing.lg,
                vertical: ZadSpacing.md,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(ZadRadii.card),
                borderSide: BorderSide(
                  color: ZadColors.outline.withValues(alpha: 0.4),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(ZadRadii.card),
                borderSide: BorderSide(
                  color: ZadColors.forestEmerald,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: ZadSpacing.sm),
        IconButton.filled(
          onPressed: controller.text.trim().isEmpty ? null : onAdd,
          icon: const Icon(ZadIcons.add),
          tooltip: context.l10n.shopAddTooltip,
        ),
        IconButton(
          onPressed: onManual,
          icon: const Icon(ZadIcons.edit),
          tooltip: context.l10n.shopAddProduct,
        ),
      ],
    ),
  );
}

/// A shop's name over the lines bought there.
class _StoreHeader extends StatelessWidget {
  const new({required this.name, required this.count});

  final String name;
  final int count;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: ZadSpacing.sm),
    child: Row(
      children: <Widget>[
        ZadArt.icon(ZadIconArt.store, size: 20),
        const SizedBox(width: ZadSpacing.sm),
        Expanded(
          child: Text(
            name,
            style: ZadType.labelMedium.copyWith(
              color: ZadWorld.shop.color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          '$count',
          style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
        ),
      ],
    ),
  );
}

/// "سلة زاد الذكية": the basket, what is left to spend, the share of the
/// budget, and a warning when the basket is more than is left.
class _BudgetCard extends StatelessWidget {
  const new({
    required this.total,
    required this.remaining,
    required this.limit,
    required this.currency,
    this.priced = 0,
    this.lines = 0,
  });

  /// Lines with a known price, and all outstanding lines: a total over two
  /// of eight lines is not the basket.
  final int priced;
  final int lines;

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
    final color = over ? ZadColors.terracottaRust : ZadWorld.shop.color;
    return ZadWorldCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            context.l10n.shopBasketTitle,
            style: ZadType.labelMedium.copyWith(color: ZadColors.inkMuted),
          ),
          const SizedBox(height: ZadSpacing.xs),
          // An empty list says so instead of «— EGP» (emulator, 2026-11-10).
          if (basket == null && lines == 0)
            Text(context.l10n.shoppingBasketEmpty, style: ZadType.titleMedium)
          else
            Text(
              basket == null
                  ? '— $currency'.trim()
                  : '${_money(basket)} $currency',
              style: ZadType.figure(28).copyWith(color: color),
            ),
          if (basket != null && priced < lines)
            Text(
              context.l10n.shopBasketPartial(priced, lines),
              style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
            ),
          if (basket != null && cap != null && cap > 0) ...<Widget>[
            const SizedBox(height: ZadSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(ZadRadii.pill),
              child: LinearProgressIndicator(
                value: pct / 100,
                minHeight: 6,
                color: color,
                backgroundColor: color.withValues(alpha: 0.14),
              ),
            ),
          ],
          const SizedBox(height: ZadSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  left == null
                      ? context.l10n.shopBudgetLeftUnknown
                      : context.l10n.shopBudgetLeft(
                          '${_money(left)} $currency',
                        ),
                  style: ZadType.labelMedium.copyWith(
                    color: ZadColors.inkMuted,
                  ),
                ),
              ),
              if (basket != null && cap != null && cap > 0)
                Text(
                  context.l10n.shopBudgetPct(pct),
                  style: ZadType.labelMedium.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          if (over) ...<Widget>[
            const SizedBox(height: ZadSpacing.sm),
            Text(
              context.l10n.shopOverBudget,
              style: ZadType.labelMedium.copyWith(
                color: ZadColors.terracottaRust,
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
  Widget build(BuildContext context) => ZadWorldCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(context.l10n.shopMayNeed, style: ZadType.titleSmall),
        const SizedBox(height: ZadSpacing.sm),
        for (final s in suggestions)
          Row(
            children: <Widget>[
              ZadWorldTile(
                color: ZadWorld.shop.color,
                size: 36,
                child: zadItemArt(s.name, size: 28),
              ),
              const SizedBox(width: ZadSpacing.md),
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
                child: Text(context.l10n.shopAddToList),
              ),
            ],
          ),
      ],
    ),
  );
}

/// «في البيت 6», and whether that is still short — the list line read
/// against the pantry.
String? _stockNote(ZadL10n l, ({double total, bool isLow})? stock) =>
    stock == null
    ? null
    : stock.isLow
    ? l.shopStockLow(formatQuantity(stock.total))
    : l.shopStockEnough(formatQuantity(stock.total));

Color _priorityColor(ShoppingPriority p) => switch (p) {
  ShoppingPriority.high => ZadColors.terracottaRust,
  ShoppingPriority.medium => ZadColors.mustardOchre,
  ShoppingPriority.low => ZadColors.green700,
};

String _priorityLabel(ZadL10n l, ShoppingPriority p) => switch (p) {
  ShoppingPriority.high => l.shopPriorityHigh,
  ShoppingPriority.medium => l.shopPriorityMedium,
  ShoppingPriority.low => l.shopPriorityLow,
};

/// The round tick of a line: a real checkbox, so a screen reader hears it.
class _Tick extends StatelessWidget {
  const new({
    required this.value,
    required this.onChanged,
    required this.label,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: SizedBox.square(
      dimension: 44,
      child: Checkbox(
        value: value,
        shape: const CircleBorder(),
        onChanged: (v) => onChanged(v ?? false),
      ),
    ),
  );
}

class _Line extends ConsumerWidget {
  const new({
    required this.item,
    required this.currency,
    required this.pantryCounter,
    this.stock,
    this.showBuy = true,
  });

  /// Whether an unticked line offers «من أمازون» (off for the brands inside
  /// a staple's group, which has its own).
  final bool showBuy;

  final ShoppingItem item;
  final String currency;

  /// The pantry counter a bought line's drawing flies to.
  final GlobalKey pantryCounter;

  /// The pantry's stock of it, when the pantry has any.
  final ({double total, bool isLow})? stock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final controller = ref.read(shoppingControllerProvider.notifier);
    final bought = item.isPurchased;
    final color = bought ? ZadColors.inkMuted : _priorityColor(item.priority);
    final details = <String>[
      if (!bought) _priorityLabel(l, item.priority),
      if (item.estimatedPrice > 0)
        '${_money(item.estimatedPrice * item.quantity)} $currency'.trim(),
      if (item.store case final s? when s.isNotEmpty) s,
      if (item.predictedDaysLeft case final d? when !bought) l.shopRunsOutIn(d),
      if (!bought) ?_stockNote(l, stock),
    ];

    void toggle({required bool purchased}) {
      unawaited(controller.toggle(item.id, purchased: purchased));
      if (purchased) {
        // The drawing goes to the pantry counter.
        flyArt(context, pantryCounter, zadItemArt(item.itemName, size: 32));
        // Kotlin's onCheck: matchProduct on the tick.
        unawaited(
          ref.read(affiliateMatchProvider.notifier).onPurchased(item.itemName),
        );
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(l.shopBoughtItem(item.itemName))),
        );
      }
    }

    return Dismissible(
      key: ValueKey<String>(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => unawaited(controller.remove(item.id)),
      child: Column(
        children: <Widget>[
          ZadWorldRow(
            leading: ZadWorldTile(
              color: color,
              child: zadItemArt(item.itemName, size: 32),
            ),
            title: item.quantity > 1
                ? '${item.itemName} × ${item.quantity}'
                : item.itemName,
            titleStyle: ZadType.titleSmall.copyWith(
              color: bought ? ZadColors.inkMuted : ZadColors.ink,
              decoration: bought
                  ? TextDecoration.lineThrough
                  : TextDecoration.none,
            ),
            subtitle: details.isEmpty ? null : details.join(' · '),
            stateColor: color,
            onTap: () => toggle(purchased: !bought),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                IconButton(
                  onPressed: () => unawaited(controller.remove(item.id)),
                  tooltip: l.commonDelete,
                  icon: Icon(
                    ZadIcons.delete,
                    size: 18,
                    color: ZadColors.inkMuted,
                  ),
                ),
                _Tick(
                  value: bought,
                  onChanged: (v) => toggle(purchased: v),
                  label: item.itemName,
                ),
              ],
            ),
          ),
          if (!bought && showBuy)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: AmazonBuyChip(
                itemName: item.itemName,
                sourceScreen: 'shopping_row',
              ),
            ),
        ],
      ),
    );
  }
}

/// A staple's lines as one: «مياه · 7 أنواع», one tick for all of them, the
/// house's stock, and the brands on a tap.
class _FamilyLine extends ConsumerStatefulWidget {
  const new({
    required this.group,
    required this.currency,
    required this.pantryCounter,
    this.stock,
  });

  final ShoppingGroup group;
  final String currency;
  final GlobalKey pantryCounter;
  final ({double total, bool isLow})? stock;

  @override
  ConsumerState<_FamilyLine> createState() => _FamilyLineState();
}

class _FamilyLineState extends ConsumerState<_FamilyLine> {
  bool _open = false;

  Future<void> _removeAll() async {
    final group = widget.group;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.shopRemoveGroupTitle(group.name)),
        content: Text(context.l10n.shopRemoveGroupBody(group.lines.length)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.shopRemoveThem),
          ),
        ],
      ),
    );
    if (sure != true) return;
    final controller = ref.read(shoppingControllerProvider.notifier);
    for (final line in group.lines) {
      await controller.remove(line.id);
    }
  }

  void _tickAll({required bool bought}) {
    final controller = ref.read(shoppingControllerProvider.notifier);
    for (final line in widget.group.lines) {
      if (line.isPurchased != bought) {
        unawaited(controller.toggle(line.id, purchased: bought));
      }
    }
    if (bought) {
      flyArt(
        context,
        widget.pantryCounter,
        zadItemArt(widget.group.name, size: 32),
      );
      unawaited(
        ref
            .read(affiliateMatchProvider.notifier)
            .onPurchased(widget.group.name),
      );
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(context.l10n.shopBoughtItem(widget.group.name))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final group = widget.group;
    final brands = group.lines
        .map((l) => brandWithinFamily(l.itemName))
        .toSet()
        .toList();
    final shown = brands.take(3).join(' · ');
    final more = brands.length > 3 ? ' +${brands.length - 3}' : '';
    final note = _stockNote(l, widget.stock);
    final urgent = group.lines.any((l) => l.priority == ShoppingPriority.high);
    final color = group.allPurchased
        ? ZadColors.inkMuted
        : urgent
        ? ZadColors.terracottaRust
        : ZadWorld.shop.color;
    return Column(
      children: <Widget>[
        ZadWorldRow(
          leading: ZadWorldTile(
            color: color,
            child: zadItemArt(group.name, size: 32),
          ),
          title: l.shopGroupKinds(group.name, group.lines.length),
          subtitle: <String>[
            if (urgent) l.shopPriorityHigh,
            '$shown$more',
            ?note,
          ].join(' · '),
          stateColor: color,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconButton(
                onPressed: () => setState(() => _open = !_open),
                tooltip: _open ? l.shopHideKinds : l.shopShowKinds,
                icon: Icon(
                  _open ? Icons.expand_less : Icons.expand_more,
                  color: ZadColors.inkMuted,
                ),
              ),
              IconButton(
                onPressed: () => unawaited(_removeAll()),
                tooltip: l.commonDelete,
                icon: Icon(
                  ZadIcons.delete,
                  size: 18,
                  color: ZadColors.inkMuted,
                ),
              ),
              _Tick(
                value: group.allPurchased,
                onChanged: (v) => _tickAll(bought: v),
                label: group.name,
              ),
            ],
          ),
        ),
        if (!group.allPurchased)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: AmazonBuyChip(
              itemName: group.name,
              sourceScreen: 'shopping_row',
            ),
          ),
        if (_open)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: ZadSpacing.xl,
              top: ZadSpacing.sm,
            ),
            child: Column(
              children: <Widget>[
                for (final line in group.lines) ...<Widget>[
                  _Line(
                    item: line,
                    currency: widget.currency,
                    pantryCounter: widget.pantryCounter,
                    showBuy: false,
                  ),
                  const SizedBox(height: ZadSpacing.xs),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// Kotlin's `AddShoppingItemDialog`: name, count, estimated price, store.
Future<void> showAddShoppingSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
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
          Text(context.l10n.shopAddProduct, style: ZadType.titleMedium),
          const SizedBox(height: ZadSpacing.lg),
          TextField(
            controller: _name,
            autofocus: true,
            decoration: InputDecoration(labelText: context.l10n.shopFieldName),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: ZadSpacing.md),
          TextField(
            controller: _qty,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(labelText: context.l10n.shopFieldQty),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: ZadSpacing.md),
          TextField(
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(labelText: context.l10n.shopFieldPrice),
          ),
          const SizedBox(height: ZadSpacing.md),
          TextField(
            controller: _store,
            decoration: InputDecoration(labelText: context.l10n.shopFieldStore),
          ),
          const SizedBox(height: ZadSpacing.xl),
          FilledButton(
            onPressed: _canSave ? _save : null,
            child: Text(context.l10n.commonAdd),
          ),
        ],
      ),
    ),
  );
}
