/// Kotlin's `InventoryScreen` (`ui/screens/InventoryScreen.kt`), copied:
/// «كل المنتجات» / «النواقص» segmented tabs, the shortages banner with
/// «نزّلها في التسوق», «ينتهي قريباً» with «اقتراح وصفة», the Amazon search
/// chips and the two-column shortage cards, the category chips, the item
/// cards (emoji tile, «منخفض», expiry · category, stock bar, −/+, edit,
/// delete), the empty states, the two FABs («تصوير المخزون», «إضافة يدوية»),
/// `AddInventoryDialog` and `EditInventoryDialog`.
///
/// The search field is the one addition: Kotlin's query comes from its top
/// header, which this client does not have.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/components/zad_kotlin_surfaces.dart';
import 'package:zad/core/design/components/zad_scroll_away.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_extended_colors.dart';
import 'package:zad/core/design/tokens/zad_motion.dart';
import 'package:zad/core/design/tokens/zad_palette.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/inventory/domain/pantry_categories.dart';
import 'package:zad/features/inventory/presentation/pantry_starter_card.dart';
import 'package:zad/features/inventory/presentation/pantry_world_scene.dart';
import 'package:zad/shared/chat/application/chat_controller.dart';
import 'package:zad/shared/inventory/application/pantry_controller.dart'
    hide PantryView;
import 'package:zad/shared/inventory/application/shopping_controller.dart';
import 'package:zad/shared/inventory/data/pantry_learning.dart';
import 'package:zad/shared/inventory/domain/inventory_item.dart';
import 'package:zad/shared/inventory/domain/product_family.dart';
import 'package:zad/shared/inventory/domain/quantity.dart';
import 'package:zad/shared/inventory/domain/shelf_life.dart';
import 'package:zad/shared/inventory/domain/shortage.dart';
import 'package:zad/shared/inventory/presentation/item_photo.dart';
import 'package:zad/shared/inventory/presentation/quantity_text.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/navigation/destinations.dart';
import 'package:zad/shared/navigation/shell_navigation.dart';
import 'package:zad/shared/orb/domain/companion_state.dart';
import 'package:zad/shared/worlds/art/art.dart';
import 'package:zad/shared/worlds/world_card.dart';
import 'package:zad/shared/worlds/world_scaffold.dart';
import 'package:zad/shared/worlds/zad_world.dart';

// l10n: data-begin
/// Kotlin's stored units — **data** written to `zad_inventory.unit`.
const List<String> kPantryUnits = <String>[
  'حبة',
  'كيلو',
  'جرام',
  'لتر',
  'علبة',
  'كيس',
  'قرشة',
  'صندوق',
];

// l10n: data-end
/// What the unit menu shows for [kPantryUnits] at [i] — same order.
String _unitLabel(ZadL10n l, int i) => switch (i) {
  0 => l.pantryUnitPiece,
  1 => l.pantryUnitKilo,
  2 => l.pantryUnitGram,
  3 => l.pantryUnitLitre,
  4 => l.pantryUnitCan,
  5 => l.pantryUnitBag,
  6 => l.pantryUnitBottle,
  _ => l.pantryUnitCrate,
};

/// Kotlin's `CategoryDef`: the pastel pair and the menu icon per key.
typedef _CategoryDef = ({String key, IconData icon, Color bg, Color fg});

// l10n: data-begin
// Category keys stored in zad_inventory.category.
const List<_CategoryDef> _categoryDefs = <_CategoryDef>[
  (
    key: 'الكل',
    icon: Icons.apps,
    bg: ZadPalette.forestEmerald,
    fg: ZadPalette.onAccent,
  ),
  (
    key: 'البقالة',
    icon: Icons.shopping_basket,
    bg: Color(0xFFFFF3E0),
    fg: Color(0xFFF57C00),
  ),
  (
    key: 'الخضار',
    icon: Icons.eco,
    bg: Color(0xFFE8F5E9),
    fg: Color(0xFF43A047),
  ),
  (
    key: 'الفواكه',
    icon: Icons.fastfood,
    bg: Color(0xFFFCE4EC),
    fg: Color(0xFFD81B60),
  ),
  (
    key: 'اللحوم',
    icon: Icons.set_meal,
    bg: Color(0xFFFFEBEE),
    fg: Color(0xFFC62828),
  ),
  (
    key: 'الألبان',
    icon: Icons.local_drink,
    bg: Color(0xFFE3F2FD),
    fg: Color(0xFF1976D2),
  ),
  (
    key: 'المشروبات',
    icon: Icons.local_cafe,
    bg: Color(0xFFF3E5F5),
    fg: Color(0xFF8E24AA),
  ),
  (
    key: 'العناية',
    icon: Icons.spa,
    bg: Color(0xFFE0F7FA),
    fg: Color(0xFF00838F),
  ),
  (
    key: 'أخرى',
    icon: Icons.more_horiz,
    bg: Color(0xFFF5F5F5),
    fg: Color(0xFF757575),
  ),
];
// l10n: data-end

// l10n: data-begin
/// The drawn picture of a category chip (no Material icons in a world).
Widget _categoryArt(String key, double size) => switch (key) {
  'الكل' => ZadArt.icon(ZadIconArt.house, size: size),
  'البقالة' => ZadArt.icon(ZadIconArt.jar, size: size),
  'الخضار' => ZadArt.icon(ZadIconArt.sprout, size: size),
  'الفواكه' => ZadArt.product(ZadProductArt.tomato, size: size),
  'اللحوم' => ZadArt.product(ZadProductArt.chicken, size: size),
  'الألبان' => ZadArt.product(ZadProductArt.milk, size: size),
  'المشروبات' => ZadArt.product(ZadProductArt.coffee, size: size),
  'العناية' => ZadArt.product(ZadProductArt.shampoo, size: size),
  _ => ZadArt.box(tint: zadCategoryTint(key), size: size),
};
// l10n: data-end

_CategoryDef _defFor(String? category, String itemName) {
  final key = pantryCategoryOf(category, itemName);
  return _categoryDefs.firstWhere(
    (d) => d.key == key,
    orElse: () => _categoryDefs.last,
  );
}

/// What the customer reads for a stored category [key] (ZAD_PLAN ١٠.١٦):
/// the key stays Arabic in `zad_inventory.category`, the label follows the
/// app's language. An unknown key is shown as it is.
String _categoryLabel(ZadL10n l, String key) => switch (key) {
  // l10n: data-begin
  'الكل' => l.pantryCatAll,
  'البقالة' => l.pantryCatGrocery,
  'الخضار' => l.pantryCatVegetables,
  'الفواكه' => l.pantryCatFruit,
  'اللحوم' => l.pantryCatMeat,
  'الألبان' => l.pantryCatDairy,
  'المشروبات' => l.pantryCatDrinks,
  'العناية' => l.pantryCatCare,
  'أخرى' => l.pantryCatOther,
  // l10n: data-end
  _ => key,
};

Color _fgOf(_CategoryDef d, ColorScheme s) =>
    d.key == 'الكل' ? s.onPrimary : d.fg; // l10n: data

double _threshold(InventoryItem i) => i.effectiveThreshold;

/// Kotlin's `stockRatio`: full at three times the alert level.
double _stockRatio(InventoryItem i) =>
    (i.quantity / (_threshold(i) * 3)).clamp(0, 1).toDouble();

Color _stockColor(BuildContext context, InventoryItem i) {
  final scheme = Theme.of(context).colorScheme;
  if (i.isLowStock) return scheme.error;
  if (i.isGettingLow) return scheme.secondary;
  return context.zadExt.success;
}

/// Kotlin's `expiryColor`.
Color _expiryColor(BuildContext context, int? days) {
  final scheme = Theme.of(context).colorScheme;
  if (days == null) return const Color(0xFFBDBDBD);
  if (days <= 3) return scheme.error;
  if (days <= 7) return scheme.secondary;
  return context.zadExt.success;
}

/// The pantry.
class PantryView extends ConsumerStatefulWidget {
  /// Creates the view, on the shortages tab when [shortagesFirst].
  const new({this.shortagesFirst = false, super.key});

  /// Open on «النواقص» — Kotlin's `InventoryNavState.openShortagesTab`.
  final bool shortagesFirst;

  @override
  ConsumerState<PantryView> createState() => _PantryViewState();
}

class _PantryViewState extends ConsumerState<PantryView> {
  String _category = 'الكل'; // l10n: data
  String _query = '';
  // Staples whose brands are open under their card. Closed by default: the
  // house has «مياه: 8», not six rows of one bottle each (owner, 2026-10-01).
  final Set<String> _openFamilies = <String>{};

  DateTime _today() {
    final now = ref.read(nowProvider)();
    return DateTime.utc(now.year, now.month, now.day);
  }

  /// Kotlin's `runAutoReplenish`: every low, non-stagnant item not already
  /// on the list goes onto it.
  Future<void> _replenish(List<InventoryItem> low) async {
    // The server's reading only filters out stagnant rows: none yet filters
    // nothing, rather than leaving the list unwritten.
    final learning = ref.read(pantryLearningViewProvider);
    final shopping = ref.read(shoppingControllerProvider.notifier);
    final onList = ref
        .read(shoppingControllerProvider)
        .outstanding
        .map((s) => s.itemName)
        .toSet();
    for (final i in low) {
      if (learning.isStagnant(i) || onList.contains(i.itemName)) {
        continue;
      }
      await shopping.add(i.itemName);
    }
  }

  void _suggestRecipe(List<InventoryItem> expiring) {
    // l10n: data-begin
    // The customer's own message to the brain, sent in Arabic.
    final names = expiring.map((i) => i.itemName).join('، ');
    unawaited(
      ref
          .read(chatControllerProvider.notifier)
          .send(
            'اقترح لي وصفة سريعة تستخدم هذه المكونات التي تنتهي قريباً: '
            '$names',
          ),
    );
    // l10n: data-end
    Navigator.of(context).popUntil((r) => r.isFirst);
    ref.read(shellNavigationProvider.notifier).open(ShellTab.chat);
  }

  /// «خلص»: the row to zero as one use, so the learner hears it like the −
  /// it replaces, with a way back.
  Future<void> _finish(InventoryItem item) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l = context.l10n;
    final amount = item.quantity;
    final controller = ref.read(pantryControllerProvider.notifier);
    await controller.adjust(item.id, -amount);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l.pantryFinishedSnack(item.itemName)),
          action: SnackBarAction(
            label: l.pantryUndo,
            onPressed: () => unawaited(controller.adjust(item.id, amount)),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final view = ref.watch(pantryControllerProvider);
    final controller = ref.read(pantryControllerProvider.notifier);
    final all = view.items;
    final today = _today();
    final expiring = <InventoryItem>[
      for (final i in all)
        if (i.daysUntilExpiry(today) case final d? when d <= 3) i,
    ];
    // What the controller counts as short — the house's own use when it is
    // known, never on the day a row was added, a staple's brands as one
    // stock (shortage.dart). The banner used to apply a threshold of its own.
    final low = <InventoryItem>[
      for (final sh in view.shortages)
        if (sh.reason == ShortageReason.outOfStock ||
            sh.reason == ShortageReason.runningLow)
          sh.item,
    ];
    final filtered = <InventoryItem>[
      for (final i in all)
        if ((_category == 'الكل' || // l10n: data
                pantryCategoryOf(i.category, i.itemName) == _category) &&
            (_query.isEmpty ||
                i.itemName.toLowerCase().contains(_query.toLowerCase())))
          i,
    ];

    // The list as stock: a staple's brands under one header with the house
    // total, then its rows; everything else one row each.
    final rows = <(InventoryItem?, PantryGroup?, bool)>[
      for (final g in groupPantry(filtered))
        if (g.isFamily) ...<(InventoryItem?, PantryGroup?, bool)>[
          (null, g, false),
          if (_openFamilies.contains(g.family))
            for (final m in g.members) (m, null, true),
        ] else
          (g.members.single, null, false),
    ];

    // What is fine: everything not short and not about to spoil.
    final attention = <String>{
      for (final i in low) i.id,
      for (final i in expiring) i.id,
    };
    final stock = <Widget>[
      for (var i = 0; i < rows.length; i++)
        if (rows[i].$2 case final group?)
          _FamilyRow(
            group: group,
            open: _openFamilies.contains(group.family),
            onToggle: () => setState(
              () => _openFamilies.contains(group.family)
                  ? _openFamilies.remove(group.family)
                  : _openFamilies.add(group.family!),
            ),
            // One bottle drunk comes off the fullest brand; one bought goes
            // on the one there is most of.
            onConsume: group.total <= 0
                ? null
                : () => unawaited(
                    controller.adjust(
                      group.members.firstWhere((m) => m.quantity > 0).id,
                      -1,
                    ),
                  ),
            onRestock: () =>
                unawaited(controller.adjust(group.members.first.id, 1)),
          )
        else
          _StockRow(
            item: rows[i].$1!,
            today: today,
            grouped: rows[i].$3,
            onConsume: () => unawaited(controller.adjust(rows[i].$1!.id, -1)),
            onRestock: () => unawaited(controller.adjust(rows[i].$1!.id, 1)),
            onEdit: () => unawaited(showEditPantrySheet(context, rows[i].$1!)),
            onFinish: () => unawaited(_finish(rows[i].$1!)),
          ),
    ];

    final body = ZadWorldScaffold(
      world: ZadWorld.inv,
      // The household page owns the back button (its app bar).
      showBack: false,
      eyebrow: context.l10n.pantryWorldEyebrow(all.length),
      title: context.l10n.worldLabelInv,
      stateLine: context.l10n.pantryWorldState(low.length),
      scene: (loop) => PantryWorldScene(loop, running: low.isNotEmpty),
      zado: ZadWorldZado(
        state: low.isNotEmpty ? CompanionState.alert : CompanionState.happy,
      ),
      onRefresh: () => controller.refresh(force: true),
      // The add button docks in its own strip under the list, so it never
      // covers a row.
      dockHeight: 80,
      // One button, on the right where a right thumb rests (owner,
      // 2026-11-12; the bar's camera is the one way to scan).
      overlay: Positioned(
        right: 16,
        bottom: 12,
        child: ZadStepsAside(
          child: FloatingActionButton(
            heroTag: 'pantry-add',
            onPressed: () => unawaited(showAddPantrySheet(context)),
            tooltip: context.l10n.pantryAddManual,
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.add),
          ),
        ),
      ),
      slivers: <Widget>[
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: ZadSpacing.gutter),
          sliver: SliverList.list(
            children: <Widget>[
              if (low.isNotEmpty) ...<Widget>[
                _LowStockCard(
                  names: <String>[for (final i in low) i.itemName],
                  // The shortages live on the shopping list — one list, not
                  // a tab here and a list there (the owner, 2026-11-04).
                  onShop: () {
                    unawaited(_replenish(low));
                    const OpenHouseholdSection(HouseholdSection.shopping)
                        .dispatch(context);
                  },
                ),
                const SizedBox(height: ZadSpacing.md),
              ],
              if (expiring.isNotEmpty) ...<Widget>[
                _ExpiringCard(
                  items: expiring,
                  today: today,
                  onSuggest: () => _suggestRecipe(expiring),
                ),
                const SizedBox(height: ZadSpacing.md),
              ],
              TextField(
                onChanged: (q) => setState(() => _query = q.trim()),
                decoration: InputDecoration(
                  hintText: context.l10n.shopFieldName,
                  prefixIcon: const Icon(Icons.search, size: 18),
                  isDense: true,
                  filled: true,
                  fillColor: ZadColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(ZadRadii.card),
                    borderSide: const BorderSide(color: ZadColors.hairline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(ZadRadii.card),
                    borderSide: const BorderSide(color: ZadColors.hairline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(ZadRadii.card),
                    borderSide: const BorderSide(color: ZadColors.green600),
                  ),
                ),
              ),
              SizedBox(
                height: 56,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(vertical: ZadSpacing.sm),
                  itemCount: kPantryCategories.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: ZadSpacing.sm),
                  itemBuilder: (_, i) {
                    final key = kPantryCategories[i].key;
                    final on = _category == key;
                    return FilterChip(
                      selected: on,
                      onSelected: (_) => setState(() => _category = key),
                      showCheckmark: false,
                      avatar: _categoryArt(key, 20),
                      label: Text(
                        _categoryLabel(context.l10n, key),
                        style: ZadType.labelMedium.copyWith(
                          color: on ? scheme.primary : null,
                        ),
                      ),
                      selectedColor: scheme.primaryContainer,
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(ZadRadii.chip),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        if (all.isEmpty && _query.isEmpty)
          // The staples in one tap instead of «المخزون فارغ» and a camera
          // button (ZAD_PLAN ١٠.١ slice 5).
          const SliverToBoxAdapter(child: PantryStarterCard())
        else if (filtered.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: KtEmptyState(
              icon: Icons.search_off,
              title: context.l10n.pantrySearchEmptyTitle,
              subtitle: context.l10n.pantrySearchEmptyBody,
              iconTint: scheme.outline,
              iconBackground: scheme.outlineVariant,
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: ZadSpacing.gutter),
            sliver: SliverList.list(
              children: <Widget>[
                ZadWorldCard(
                  child: Column(
                    children: <Widget>[
                      for (var i = 0; i < stock.length; i++) ...<Widget>[
                        if (i > 0 &&
                            !(rows[i].$3 ||
                                rows[i - 1].$2 != null && rows[i].$3))
                          const Divider(height: ZadSpacing.lg),
                        stock[i],
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: ZadSpacing.md),
                _Legend(
                  low: low.length,
                  expiring: expiring.length,
                  ok: math.max(0, all.length - attention.length),
                ),
              ],
            ),
          ),
      ],
    );

    return ZadScrollAwayScope(child: body);
  }
}

/// «نواقص المخزون»: what is short, and the one tap that puts it on the list.
class _LowStockCard extends StatelessWidget {
  const new({required this.names, required this.onShop});

  /// What is short, so the card says it.
  final List<String> names;
  final VoidCallback onShop;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ZadWorldCard(
      child: Row(
        children: <Widget>[
          _Tile(
            icon: Icons.shopping_cart_checkout,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: ZadSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // One text of two spans, so a long list ellipsizes with its
                // title and large type cannot push the row off screen.
                Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      TextSpan(
                        text: l.pantryLowBanner(names.length),
                        style: ZadType.titleSmall,
                      ),
                      TextSpan(
                        text: '\n${names.join(l.listSeparator)}',
                        style: ZadType.bodySmall.copyWith(
                          color: ZadColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onShop,
            style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
            child: Text(l.pantryToShopping),
          ),
        ],
      ),
    );
  }
}

/// «ينتهي قريباً» with «اقتراح وصفة».
class _ExpiringCard extends StatelessWidget {
  const new({
    required this.items,
    required this.today,
    required this.onSuggest,
  });

  final List<InventoryItem> items;
  final DateTime today;
  final VoidCallback onSuggest;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ZadWorldCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _Tile(
                icon: Icons.timer,
                color: Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(width: ZadSpacing.md),
              Expanded(
                child: Text(l.pantryExpiringSoon, style: ZadType.titleSmall),
              ),
              TextButton.icon(
                onPressed: onSuggest,
                style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: Text(l.pantrySuggestRecipe),
              ),
            ],
          ),
          const SizedBox(height: ZadSpacing.sm),
          Wrap(
            spacing: ZadSpacing.sm,
            runSpacing: ZadSpacing.sm,
            children: <Widget>[
              for (final item in items)
                _ExpiryPill(
                  name: item.itemName,
                  days: item.daysUntilExpiry(today),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExpiryPill extends StatelessWidget {
  const new({required this.name, required this.days});

  final String name;
  final int? days;

  @override
  Widget build(BuildContext context) {
    final color = _expiryColor(context, days);
    final l = context.l10n;
    final d = days;
    final when = d != null && d <= 0
        ? l.pantryExpired
        : l.pantryDaysLeft(d?.toString() ?? '?');
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(ZadRadii.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ZadSpacing.md,
          vertical: ZadSpacing.xs,
        ),
        child: Text(
          '$name · $when',
          style: ZadType.labelMedium.copyWith(color: color),
        ),
      ),
    );
  }
}

/// A tinted rounded square with a glyph.
class _Tile extends StatelessWidget {
  const new({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(ZadRadii.chip),
    ),
    child: Icon(icon, size: 22, color: color),
  );
}

/// «قربت تخلص / هتبوظ قريب / تمام», each with its state colour.
class _Legend extends StatelessWidget {
  const new({required this.low, required this.expiring, required this.ok});

  final int low;
  final int expiring;
  final int ok;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget dot(Color c, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: ZadSpacing.xs),
        Text(text, style: ZadType.labelMedium.copyWith(color: ZadColors.slate)),
      ],
    );
    return Wrap(
      spacing: ZadSpacing.lg,
      runSpacing: ZadSpacing.xs,
      children: <Widget>[
        dot(Theme.of(context).colorScheme.error, l.pantryLegendLow(low)),
        dot(
          Theme.of(context).colorScheme.secondary,
          l.pantryLegendExpiring(expiring),
        ),
        dot(context.zadExt.success, l.pantryLegendOk(ok)),
      ],
    );
  }
}

/// «خلص» or the days left, for a row's state line.
String _daysText(ZadL10n l, int days) =>
    days <= 0 ? l.pantryExpiredShort : l.pantryDays(days);

/// A stepper button at the 44dp tap target.
Widget _step(
  IconData icon,
  String label,
  Color tint,
  VoidCallback? tap, {
  Key? key,
}) => SizedBox.square(
  dimension: 44,
  child: IconButton(
    key: key,
    padding: EdgeInsets.zero,
    tooltip: label,
    onPressed: tap,
    icon: Icon(icon, size: 22, color: tint),
  ),
);

/// One item: its picture, name and state line, the «how much is left» bar in
/// its state colour, the quantity, and −, +, «خلص». A tap opens the edit.
class _StockRow extends StatelessWidget {
  const new({
    required this.item,
    required this.today,
    required this.onConsume,
    required this.onRestock,
    required this.onEdit,
    required this.onFinish,
    this.grouped = false,
  });

  final InventoryItem item;
  final DateTime today;

  /// One brand of a staple under its family header, which says whether the
  /// house is low — a single bottle of one brand is not «منخفض» when there
  /// are seven of the others.
  final bool grouped;
  final VoidCallback onConsume;
  final VoidCallback onRestock;

  /// The whole row: edit, and delete from there.
  final VoidCallback onEdit;

  /// «خلص»: down to zero in one tap.
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final days = item.daysUntilExpiry(today);
    final def = _defFor(item.category, item.itemName);
    // Bought every couple of months (ZAD_PLAN ٣.١٠): at zero it is not low,
    // it is simply not in the house right now.
    final isLow = !grouped && !item.isOccasional && item.isLowStock;
    final state = _stockColor(context, item);
    return Semantics(
      button: true,
      label: l.pantryEditItem,
      child: Padding(
        padding: EdgeInsetsDirectional.only(start: grouped ? ZadSpacing.xl : 0),
        child: Column(
          children: <Widget>[
            GestureDetector(
              key: ValueKey<String>('pantry-card-${item.id}'),
              behavior: HitTestBehavior.opaque,
              onTap: onEdit,
              child: Row(
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: state.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(ZadRadii.chip),
                    ),
                    child: ZadItemPhoto(
                      item.itemName,
                      width: 44,
                      height: 44,
                      placeholder: Center(
                        child: zadItemArt(
                          item.itemName,
                          size: 36,
                          category: item.category,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: ZadSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          item.itemName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: ZadType.titleSmall,
                        ),
                        Text.rich(
                          TextSpan(
                            children: <InlineSpan>[
                              if (isLow)
                                TextSpan(
                                  text: '${l.pantryLow} · ',
                                  style: TextStyle(
                                    color: scheme.error,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              if (days != null)
                                TextSpan(
                                  text: '${_daysText(l, days)} · ',
                                  style: TextStyle(
                                    color: _expiryColor(context, days),
                                  ),
                                ),
                              TextSpan(text: _categoryLabel(l, def.key)),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ZadType.labelSmall.copyWith(
                            color: ZadColors.inkMuted,
                          ),
                        ),
                        const SizedBox(height: ZadSpacing.xs),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(ZadRadii.pill),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(end: _stockRatio(item)),
                            duration: ZadDuration.settle,
                            curve: ZadCurves.standard,
                            builder: (_, v, _) => LinearProgressIndicator(
                              value: v,
                              minHeight: 6,
                              color: state,
                              backgroundColor: state.withValues(alpha: 0.14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: ZadSpacing.md),
                  Text(
                    quantityText(context, item.quantity, item.unit),
                    style: ZadType.titleSmall.copyWith(color: state),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                if (item.quantity > 0)
                  _step(
                    Icons.task_alt_rounded,
                    l.pantryFinish,
                    scheme.error,
                    onFinish,
                    key: ValueKey<String>('pantry-finish-${item.id}'),
                  ),
                _step(
                  Icons.remove_circle_outline,
                  l.pantryUseOne,
                  item.quantity > 0 ? scheme.error : scheme.outline,
                  item.quantity > 0 ? onConsume : null,
                ),
                _step(
                  Icons.add_circle_outline,
                  l.pantryAddOne,
                  scheme.primary,
                  onRestock,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A staple as one stock: the house total across its brands, − and +, and
/// whether it is low. A tap opens the brands under it.
class _FamilyRow extends StatelessWidget {
  const new({
    required this.group,
    required this.open,
    required this.onToggle,
    required this.onRestock,
    this.onConsume,
  });

  final PantryGroup group;
  final bool open;
  final VoidCallback onToggle;
  final VoidCallback? onConsume;
  final VoidCallback onRestock;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final units = group.members.map((m) => m.unit).toSet();
    final unit = units.length == 1 ? (units.single ?? '') : '';
    final state = group.isShortLow ? scheme.error : context.zadExt.success;
    return Column(
      children: <Widget>[
        InkWell(
          onTap: onToggle,
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: state.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(ZadRadii.chip),
                ),
                child: ZadItemPhoto(
                  group.name,
                  width: 44,
                  height: 44,
                  placeholder: Center(child: zadItemArt(group.name, size: 36)),
                ),
              ),
              const SizedBox(width: ZadSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ZadType.titleSmall,
                    ),
                    Text(
                      <String>[
                        if (group.isOut)
                          l.pantryOut
                        else if (group.isShortLow)
                          l.pantryLow,
                        l.pantryKinds(group.members.length),
                        if (open) l.shopHideKinds else l.pantryShowKinds,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ZadType.labelSmall.copyWith(
                        color: group.isShortLow
                            ? scheme.error
                            : ZadColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: ZadSpacing.md),
              Text(
                quantityText(context, group.total, unit),
                style: ZadType.titleSmall.copyWith(color: state),
              ),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            _step(
              Icons.remove_circle_outline,
              l.pantryUsedOne,
              onConsume == null ? scheme.outlineVariant : scheme.error,
              onConsume,
            ),
            _step(
              Icons.add_circle_outline,
              l.pantryIncreaseOne,
              scheme.primary,
              onRestock,
            ),
            _step(
              open ? Icons.expand_less : Icons.expand_more,
              open ? l.shopHideKinds : l.pantryShowKinds,
              scheme.onSurfaceVariant,
              onToggle,
            ),
          ],
        ),
      ],
    );
  }
}

/// Opens Kotlin's `AddInventoryDialog`.
Future<void> showAddPantrySheet(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => const _AddInventoryDialog(),
);

/// Opens Kotlin's `EditInventoryDialog` for [item].
Future<void> showEditPantrySheet(BuildContext context, InventoryItem item) =>
    showDialog<void>(
      context: context,
      builder: (_) => _EditInventoryDialog(item: item),
    );

class _AddInventoryDialog extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_AddInventoryDialog> createState() => _AddState();
}

class _AddState extends ConsumerState<_AddInventoryDialog> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _qty = TextEditingController(text: '1');
  int _unit = 0;
  int _category = 0;

  /// What the customer picked; null = the estimate, or no date at all.
  DateTime? _expiry;
  late final DateTime _today = _accountToday(ref);

  @override
  void initState() {
    super.initState();
    // The estimate follows the name as it is typed.
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _qty.dispose();
    super.dispose();
  }

  /// The usual shelf life for what is typed, shown as an estimate and saved
  /// when the customer picks nothing.
  DateTime? get _estimate => guessExpiryDate(
    category: _categoryDefs[_category + 1].key,
    itemName: _name.text,
    today: _today,
  );

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final navigator = Navigator.of(context);
    final expiry = _expiry ?? _estimate;
    await ref
        .read(pantryControllerProvider.notifier)
        .add(
          itemName: name,
          quantity: parseQuantity(_qty.text) ?? 1,
          unit: kPantryUnits[_unit],
          category: _categoryDefs[_category + 1].key,
          expiryDate: expiry,
        );
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = ZadType.labelMedium.copyWith(
      fontWeight: FontWeight.w600,
      color: scheme.onSurfaceVariant,
    );
    InputDecoration field({String? hint, Widget? suffix}) => InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: scheme.outline),
      suffixIcon: suffix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary),
      ),
    );

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      backgroundColor: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 520 + 48),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    context.l10n.pantryAddTitle,
                    style: ZadType.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),
                  SizedBox.square(
                    dimension: 28,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      tooltip: context.l10n.pantryClose,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close,
                        size: 18,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(context.l10n.shopFieldName, style: label),
              const SizedBox(height: 6),
              TextField(
                controller: _name,
                decoration: field(hint: context.l10n.pantryNameHint),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(context.l10n.shopFieldQty, style: label),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _qty,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: field(),
                          onChanged: (v) {
                            final kept = v.replaceAll(
                              RegExp('[^0-9٠-٩.,٫½¼¾]'), // l10n: data
                              '',
                            );
                            if (kept != v) _qty.text = kept;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(context.l10n.pantryUnit, style: label),
                        const SizedBox(height: 6),
                        DropdownMenu<int>(
                          initialSelection: _unit,
                          expandedInsets: EdgeInsets.zero,
                          inputDecorationTheme: InputDecorationTheme(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onSelected: (i) {
                            if (i != null) setState(() => _unit = i);
                          },
                          dropdownMenuEntries: <DropdownMenuEntry<int>>[
                            for (var i = 0; i < kPantryUnits.length; i++)
                              DropdownMenuEntry<int>(
                                value: i,
                                label: _unitLabel(context.l10n, i),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(context.l10n.pantryCategory, style: label),
              const SizedBox(height: 6),
              DropdownMenu<int>(
                initialSelection: _category,
                expandedInsets: EdgeInsets.zero,
                inputDecorationTheme: InputDecorationTheme(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onSelected: (i) {
                  if (i != null) setState(() => _category = i);
                },
                dropdownMenuEntries: <DropdownMenuEntry<int>>[
                  for (var i = 1; i < _categoryDefs.length; i++)
                    DropdownMenuEntry<int>(
                      value: i - 1,
                      label: _categoryLabel(context.l10n, _categoryDefs[i].key),
                      leadingIcon: Icon(
                        _categoryDefs[i].icon,
                        size: 18,
                        color: _fgOf(_categoryDefs[i], scheme),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(context.l10n.pantryExpiryField, style: label),
              const SizedBox(height: 6),
              _ExpiryField(
                value: _expiry,
                estimate: _estimate,
                today: _today,
                onChanged: (d) => setState(() => _expiry = d),
              ),
              const SizedBox(height: 24),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: scheme.onSurfaceVariant,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(context.l10n.commonCancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => unawaited(_save()),
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.primary,
                        foregroundColor: scheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.check, size: 18),
                      label: Text(context.l10n.commonSave),
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

class _EditInventoryDialog extends ConsumerStatefulWidget {
  const new({required this.item});

  final InventoryItem item;

  @override
  ConsumerState<_EditInventoryDialog> createState() => _EditState();
}

class _EditState extends ConsumerState<_EditInventoryDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.item.itemName,
  );
  late final TextEditingController _qty = TextEditingController(
    text: formatQuantity(widget.item.quantity),
  );
  late final TextEditingController _unit = TextEditingController(
    text: widget.item.unit ?? '',
  );

  /// «بشتريها على فترات» — starts at what Zad already thinks, and is only
  /// written when the customer changes it, so the history keeps deciding for
  /// anyone who never touched it.
  late bool _occasional = widget.item.isOccasional;

  /// The row's expiry as it stands in the dialog; written only if changed.
  late DateTime? _expiry = widget.item.expiryDate;
  late final DateTime _today = _accountToday(ref);

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
    _qty.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _qty.dispose();
    _unit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Zero is a count here — an item that ran out is still renamed or marked
    // «على فترات» — while parseQuantity, built for purchases, refuses it.
    final quantity =
        RegExp(r'^[0٠]+([.,٫][0٠]*)?$').hasMatch(_qty.text.trim()) // l10n: data
        ? 0.0
        : parseQuantity(_qty.text);
    final canSave =
        _name.text.trim().isNotEmpty && quantity != null && quantity >= 0;
    return AlertDialog(
      title: Text(
        context.l10n.pantryEditItem,
        style: ZadType.titleLarge.copyWith(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _name,
              decoration: InputDecoration(
                labelText: context.l10n.shopFieldName,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _qty,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (v) {
                      // Digits and the fraction marks formatQuantity writes:
                      // stripping «.» and «½» made a half kilo unsavable.
                      final kept = v.replaceAll(
                        RegExp('[^0-9٠-٩.,٫½¼¾]'), // l10n: data
                        '',
                      );
                      if (kept != v) _qty.text = kept;
                    },
                    decoration: InputDecoration(
                      labelText: context.l10n.shopFieldQty,
                      border: const OutlineInputBorder(),
                      errorText: _qty.text.isNotEmpty && quantity == null
                          ? ''
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _unit,
                    decoration: InputDecoration(
                      labelText: context.l10n.pantryUnit,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: ZadSpacing.md),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                context.l10n.pantryExpiryField,
                style: ZadType.labelMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: ZadSpacing.xs),
            _ExpiryField(
              value: _expiry,
              today: _today,
              onChanged: (d) => setState(() => _expiry = d),
            ),
            const SizedBox(height: ZadSpacing.sm),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _occasional,
              onChanged: (v) => setState(() => _occasional = v),
              title: Text(
                context.l10n.pantryOccasional,
                style: ZadType.bodyMedium,
              ),
              subtitle: Text(
                context.l10n.pantryOccasionalBody,
                style: ZadType.bodySmall,
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        // Delete lives here now that the card's own button is «خلص».
        TextButton(
          key: const ValueKey<String>('pantry-edit-delete'),
          onPressed: () async {
            final navigator = Navigator.of(context);
            await ref
                .read(pantryControllerProvider.notifier)
                .remove(widget.item.id);
            navigator.pop();
          },
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: Text(context.l10n.pantryDeleteItem),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.commonCancel),
        ),
        FilledButton(
          onPressed: canSave
              ? () async {
                  final navigator = Navigator.of(context);
                  final unit = _unit.text.trim();
                  final said = _occasional == widget.item.isOccasional
                      ? null
                      : (_occasional ? restockOccasional : restockStaple);
                  final expiry = _expiry;
                  final expiryChanged = expiry != widget.item.expiryDate;
                  await ref
                      .read(pantryControllerProvider.notifier)
                      .edit(
                        widget.item,
                        itemName: _name.text.trim(),
                        quantity: quantity,
                        unit: unit.isEmpty ? null : unit,
                        restockMode: said,
                        expiryDate: expiryChanged ? expiry : null,
                        clearExpiry: expiryChanged && expiry == null,
                      );
                  navigator.pop();
                }
              : null,
          child: Text(context.l10n.commonSave),
        ),
      ],
    );
  }
}

/// Today in the account's market zone — what the expiry field counts from.
DateTime _accountToday(WidgetRef ref) =>
    civilDayIn(ref.read(nowProvider)(), ref.read(accountTimeZoneProvider));

/// The expiry field: a tap opens the calendar, three chips set the usual
/// spans, × clears it. Replaces a free-text `YYYY-MM-DD` box nobody filled
/// (0 of 40 rows had a date, 2026-11-12).
///
/// [estimate], when given and nothing is picked, is shown as «تقديري: …» —
/// a guess from the kind of item, never presented as the real date.
class _ExpiryField extends StatelessWidget {
  const new({
    required this.value,
    required this.today,
    required this.onChanged,
    this.estimate,
  });

  final DateTime? value;
  final DateTime? estimate;
  final DateTime today;
  final ValueChanged<DateTime?> onChanged;

  Future<void> _pick(BuildContext context) async {
    final first = DateTime(today.year, today.month, today.day);
    final last = DateTime(today.year + 10, today.month, today.day);
    final seed = value ?? estimate ?? civilDatePlusDays(today, 7);
    var initial = DateTime(seed.year, seed.month, seed.day);
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) {
      onChanged(DateTime.utc(picked.year, picked.month, picked.day));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final format = DateFormat('d MMMM y', context.dateLocale);
    final picked = value;
    final guess = estimate;
    final text = picked != null
        ? format.format(picked)
        : guess != null
        ? l10n.pantryExpiryEstimate(format.format(guess))
        : l10n.pantryExpiryPick;
    final chips = <(int, String)>[
      (kExpiryQuickDays[0], l10n.pantryExpiryIn3Days),
      (kExpiryQuickDays[1], l10n.pantryExpiryInWeek),
      (kExpiryQuickDays[2], l10n.pantryExpiryInMonth),
    ];
    final radius = BorderRadius.circular(ZadRadii.chip);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: () => unawaited(_pick(context)),
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsetsDirectional.only(
                start: ZadSpacing.md,
                end: ZadSpacing.xs,
              ),
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(color: scheme.outline),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.event_outlined,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: ZadSpacing.sm),
                  Expanded(
                    child: Text(
                      text,
                      style: ZadType.bodyLarge.copyWith(
                        color: picked == null
                            ? scheme.onSurfaceVariant
                            : scheme.onSurface,
                      ),
                    ),
                  ),
                  if (picked != null)
                    IconButton(
                      tooltip: l10n.pantryExpiryClear,
                      onPressed: () => onChanged(null),
                      icon: Icon(
                        Icons.close,
                        size: 18,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (picked == null && guess != null) ...<Widget>[
          const SizedBox(height: ZadSpacing.xs),
          Text(
            l10n.pantryExpiryEstimateNote,
            style: ZadType.bodySmall.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: ZadSpacing.sm),
        Wrap(
          spacing: ZadSpacing.sm,
          children: <Widget>[
            for (final (days, label) in chips)
              ChoiceChip(
                label: Text(label),
                selected: picked == civilDatePlusDays(today, days),
                onSelected: (_) => onChanged(civilDatePlusDays(today, days)),
              ),
          ],
        ),
      ],
    );
  }
}
