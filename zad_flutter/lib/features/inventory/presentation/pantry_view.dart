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
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/components/zad_kotlin_surfaces.dart';
import 'package:zad/core/design/foundation/compose_shadow.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_extended_colors.dart';
import 'package:zad/core/design/tokens/zad_palette.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/features/inventory/domain/pantry_categories.dart';
import 'package:zad/shared/affiliate/data/affiliate_repository.dart';
import 'package:zad/shared/chat/application/chat_controller.dart';
import 'package:zad/shared/inventory/application/pantry_controller.dart'
    hide PantryView;
import 'package:zad/shared/inventory/application/shopping_controller.dart';
import 'package:zad/shared/inventory/data/consumption_learner.dart';
import 'package:zad/shared/inventory/domain/food_emoji.dart';
import 'package:zad/shared/inventory/domain/inventory_item.dart';
import 'package:zad/shared/inventory/domain/product_family.dart';
import 'package:zad/shared/navigation/shell_navigation.dart';
import 'package:zad/shared/navigation/zad_screens.dart';

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

/// What the unit menu shows for each of [kPantryUnits].
const List<String> _unitLabels = <String>[
  'حبة',
  'كجم',
  'جرام',
  'لتر',
  'علبة',
  'كيس',
  'قرشة',
  'صندوق',
];

/// Kotlin's `CategoryDef`: the pastel pair and the menu icon per key.
typedef _CategoryDef = ({String key, IconData icon, Color bg, Color fg});

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

_CategoryDef _defFor(String? category, String itemName) {
  final key = pantryCategoryOf(category, itemName);
  return _categoryDefs.firstWhere(
    (d) => d.key == key,
    orElse: () => _categoryDefs.last,
  );
}

Color _bgOf(_CategoryDef d, ColorScheme s) =>
    d.key == 'الكل' ? s.primary : d.bg;

Color _fgOf(_CategoryDef d, ColorScheme s) =>
    d.key == 'الكل' ? s.onPrimary : d.fg;

int _threshold(InventoryItem i) => math.max(i.lowStockThreshold ?? 2, 1);

/// Kotlin's `stockRatio`: full at three times the alert level.
double _stockRatio(InventoryItem i) =>
    (i.quantity / (_threshold(i) * 3)).clamp(0, 1).toDouble();

Color _stockColor(BuildContext context, InventoryItem i) {
  final scheme = Theme.of(context).colorScheme;
  final t = _threshold(i);
  if (i.quantity <= t) return scheme.error;
  if (i.quantity <= t * 2) return scheme.secondary;
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
  late int _tab = widget.shortagesFirst ? 1 : 0;
  String _category = 'الكل';
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
    final learner = ref.read(consumptionLearnerProvider);
    final shopping = ref.read(shoppingControllerProvider.notifier);
    final onList = ref
        .read(shoppingControllerProvider)
        .outstanding
        .map((s) => s.itemName)
        .toSet();
    for (final i in low) {
      if (learner.isStagnant(i) || onList.contains(i.itemName)) continue;
      await shopping.add(i.itemName);
    }
  }

  void _suggestRecipe(List<InventoryItem> expiring) {
    final names = expiring.map((i) => i.itemName).join('، ');
    unawaited(
      ref
          .read(chatControllerProvider.notifier)
          .send(
            'اقترح لي وصفة سريعة تستخدم هذه المكونات التي تنتهي قريباً: '
            '$names',
          ),
    );
    Navigator.of(context).popUntil((r) => r.isFirst);
    ref.read(shellNavigationProvider.notifier).open(ShellTab.chat);
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
    // A staple under several brands is one stock (product_family.dart):
    // low once, under the staple's name, when the whole house is low.
    final low = <InventoryItem>[
      for (final g in groupPantry(all))
        if (g.isFamily
            ? g.isLow
            : g.members.single.quantity <=
                  (g.members.single.lowStockThreshold ?? 2))
          g.representative,
    ];
    final shortages = <InventoryItem>[
      ...low,
      for (final e in expiring)
        if (!low.any((l) => l.id == e.id)) e,
    ];
    final filtered = <InventoryItem>[
      for (final i in all)
        if ((_category == 'الكل' ||
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

    final header = <Widget>[
      ZadSegmentedTabs(
        tabs: <String>[
          'كل المنتجات',
          if (shortages.isEmpty) 'النواقص' else 'النواقص (${shortages.length})',
        ],
        selectedIndex: _tab,
        onSelect: (i) => setState(() => _tab = i),
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      ),
      if (low.isNotEmpty)
        _LowStockBanner(
          count: low.length,
          onShop: () => unawaited(_replenish(low)),
        ),
      if (expiring.isNotEmpty)
        _ExpiringSoonSection(
          items: expiring,
          today: today,
          onSuggest: () => _suggestRecipe(expiring),
        ),
    ];

    final Widget body;
    if (_tab == 1) {
      body = shortages.isEmpty
          ? ListView(
              children: <Widget>[
                ...header,
                Padding(
                  padding: const EdgeInsets.only(top: 48, bottom: 110),
                  child: KtEmptyState(
                    icon: Icons.check_circle,
                    title: 'مفيش نواقص!',
                    subtitle: 'كل احتياجاتك متوفرة بكميات كافية',
                    iconTint: context.zadExt.success,
                    iconBackground: context.zadExt.success.withValues(
                      alpha: 0.1,
                    ),
                  ),
                ),
              ],
            )
          : CustomScrollView(
              slivers: <Widget>[
                SliverList.list(children: header),
                SliverToBoxAdapter(
                  child: SizedBox(
                    // Two lines at 1.3× text: 76 left the chip 3px short.
                    height: 84,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: shortages.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 4),
                      itemBuilder: (_, i) => _AmazonSearchChip(
                        itemName: shortages[i].itemName,
                        onTap: () =>
                            unawaited(openAmazonSearch(shortages[i].itemName)),
                      ),
                    ),
                  ),
                ),
                // Two columns, each cell as tall as its content.
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                  sliver: SliverList.separated(
                    itemCount: (shortages.length + 1) ~/ 2,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, row) {
                      Widget cell(int i) => i < shortages.length
                          ? _ShortageItemCard(
                              item: shortages[i],
                              today: today,
                              onAdd: () => unawaited(
                                ref
                                    .read(shoppingControllerProvider.notifier)
                                    .add(shortages[i].itemName),
                              ),
                            )
                          : const SizedBox.shrink();
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(child: cell(row * 2)),
                          const SizedBox(width: 12),
                          Expanded(child: cell(row * 2 + 1)),
                        ],
                      );
                    },
                  ),
                ),
              ],
            );
    } else {
      body = CustomScrollView(
        slivers: <Widget>[
          SliverList.list(
            children: <Widget>[
              ...header,
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  onChanged: (q) => setState(() => _query = q.trim()),
                  decoration: const InputDecoration(
                    hintText: 'اسم المنتج',
                    prefixIcon: Icon(Icons.search, size: 18),
                    isDense: true,
                  ),
                ),
              ),
              SizedBox(
                height: 56,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: kPantryCategories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final c = kPantryCategories[i];
                    final on = _category == c.key;
                    return FilterChip(
                      selected: on,
                      onSelected: (_) => setState(() => _category = c.key),
                      showCheckmark: false,
                      avatar: Text(
                        c.emoji,
                        style: const TextStyle(fontSize: 14),
                      ),
                      label: Text(
                        c.key,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: on ? FontWeight.bold : FontWeight.w500,
                          color: on ? scheme.primary : null,
                        ),
                      ),
                      selectedColor: scheme.primaryContainer,
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          if (all.isEmpty && _query.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 110),
                child: KtEmptyState(
                  icon: Icons.inventory_2,
                  title: 'المخزون فارغ',
                  subtitle: 'ابدأ بإضافة منتجات لتنظم مخزون منزلك',
                  action: OutlinedButton.icon(
                    onPressed: () =>
                        unawaited(ZadScreens.openZadCamera(context)),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    icon: const Icon(Icons.camera_alt, size: 16),
                    label: const Text('تصوير', style: ZadType.bodySmall),
                  ),
                ),
              ),
            )
          else if (filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 110),
                child: KtEmptyState(
                  icon: Icons.search_off,
                  title: 'لا توجد نتائج',
                  subtitle: 'جرّب البحث بكلمة مختلفة',
                  iconTint: scheme.outline,
                  iconBackground: scheme.outlineVariant,
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
              sliver: SliverList.separated(
                itemCount: rows.length,
                separatorBuilder: (_, i) => SizedBox(
                  // A family's rows sit close under its header.
                  height:
                      rows[i].$2 != null &&
                          i + 1 < rows.length &&
                          rows[i + 1].$1 != null &&
                          rows[i + 1].$3
                      ? 6
                      : 12,
                ),
                itemBuilder: (_, i) {
                  final (item, group, grouped) = rows[i];
                  final Widget child;
                  if (group != null) {
                    final open = _openFamilies.contains(group.family);
                    child = _FamilyCard(
                      group: group,
                      open: open,
                      onToggle: () => setState(
                        () => open
                            ? _openFamilies.remove(group.family)
                            : _openFamilies.add(group.family!),
                      ),
                      // One bottle drunk comes off the fullest brand; one
                      // bought goes on the one there is most of.
                      onConsume: group.total <= 0
                          ? null
                          : () => unawaited(
                              controller.adjust(
                                group.members
                                    .firstWhere((m) => m.quantity > 0)
                                    .id,
                                -1,
                              ),
                            ),
                      onRestock: () => unawaited(
                        controller.adjust(group.members.first.id, 1),
                      ),
                    );
                  } else {
                    final row = item!;
                    child = _InventoryItemCard(
                      item: row,
                      today: today,
                      grouped: grouped,
                      onConsume: () => unawaited(controller.adjust(row.id, -1)),
                      onRestock: () => unawaited(controller.adjust(row.id, 1)),
                      onEdit: () =>
                          unawaited(showEditPantrySheet(context, row)),
                      onDelete: () => unawaited(controller.remove(row.id)),
                    );
                  }
                  return ZadAppearOnEntryDelay(
                    delayMs: math.min(i * 20, 250),
                    child: child,
                  );
                },
              ),
            ),
        ],
      );
    }

    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: RefreshIndicator(
            onRefresh: () => controller.refresh(force: true),
            child: body,
          ),
        ),
        PositionedDirectional(
          end: 16,
          bottom: 24,
          child: Row(
            children: <Widget>[
              FloatingActionButton(
                heroTag: 'pantry-photo',
                onPressed: () => unawaited(ZadScreens.openZadCamera(context)),
                tooltip: 'تصوير المخزون',
                backgroundColor: scheme.secondary,
                foregroundColor: scheme.onSecondary,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.document_scanner),
              ),
              const SizedBox(width: 10),
              FloatingActionButton(
                heroTag: 'pantry-add',
                onPressed: () => unawaited(showAddPantrySheet(context)),
                tooltip: 'إضافة يدوية',
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.add),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Kotlin's `AppearOnEntry(delayMs)`, for the list rows.
class ZadAppearOnEntryDelay extends StatefulWidget {
  /// Creates the wrapper.
  const new({required this.delayMs, required this.child, super.key});

  /// When to start.
  final int delayMs;

  /// The row.
  final Widget child;

  @override
  State<ZadAppearOnEntryDelay> createState() => _AppearState();
}

class _AppearState extends State<ZadAppearOnEntryDelay> {
  bool _shown = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(Duration(milliseconds: widget.delayMs), () {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: _shown ? 1 : 0,
    duration: const Duration(milliseconds: 300),
    child: AnimatedSlide(
      offset: _shown ? Offset.zero : const Offset(0, 0.08),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: widget.child,
    ),
  );
}

/// Kotlin's `floatingIdle`: a 2200ms bob of [amplitude] pixels.
class _FloatingIdle extends StatefulWidget {
  const new({required this.amplitude, required this.child});

  final double amplitude;
  final Widget child;

  @override
  State<_FloatingIdle> createState() => _FloatingIdleState();
}

class _FloatingIdleState extends State<_FloatingIdle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final px = widget.amplitude / MediaQuery.devicePixelRatioOf(context);
    return AnimatedBuilder(
      animation: _t,
      builder: (_, child) => Transform.translate(
        offset: Offset(
          0,
          -px + 2 * px * Curves.fastOutSlowIn.transform(_t.value),
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// Kotlin's `LowStockBanner`.
class _LowStockBanner extends StatelessWidget {
  const new({required this.count, required this.onShop});

  final int count;
  final VoidCallback onShop;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: scheme.error.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.shopping_cart_checkout,
              size: 11,
              color: scheme.error,
            ),
          ),
          const SizedBox(width: 6),
          // One line of two spans, ellipsized together: the title alone was
          // a fixed Text, and at large text it pushed the row 44px off screen.
          Expanded(
            child: Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(
                    text: 'نواقص المخزون ($count)',
                    style: ZadType.bodySmall.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: scheme.onErrorContainer,
                    ),
                  ),
                  TextSpan(
                    text: ' (غير محدد)',
                    style: ZadType.labelSmall.copyWith(
                      fontSize: 11,
                      color: scheme.onErrorContainer.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onShop,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text(
                'نزّلها في التسوق',
                style: ZadType.labelSmall.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: scheme.error,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kotlin's `ExpiringSoonSection`.
class _ExpiringSoonSection extends StatelessWidget {
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
    final scheme = Theme.of(context).colorScheme;
    final warning = scheme.secondary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: warning.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.timer, size: 11, color: warning),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'ينتهي قريباً',
                    style: ZadType.bodySmall.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: onSuggest,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: Row(
                    children: <Widget>[
                      Text(
                        'اقتراح وصفة',
                        style: ZadType.labelSmall.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.auto_awesome, size: 11, color: scheme.primary),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: 2),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 4),
              itemBuilder: (_, i) {
                final item = items[i];
                final days = item.daysUntilExpiry(today);
                final color = _expiryColor(context, days);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: ZadListCard(
                    padding: EdgeInsets.zero,
                    fillWidth: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Text(
                                item.itemName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: ZadType.bodySmall.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: scheme.onSurface,
                                ),
                              ),
                              Text(
                                days != null && days <= 0
                                    ? 'منتهي الصلاحية'
                                    : 'باقي ${days ?? '?'} يوم',
                                style: ZadType.labelSmall.copyWith(
                                  fontSize: 9.5,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Kotlin's `ZadAmazonSearchChip` with «اشتريه من أمازون».
class _AmazonSearchChip extends StatelessWidget {
  const new({required this.itemName, required this.onTap});

  final String itemName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: context.zadExt.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.search, size: 16, color: context.zadExt.secondaryDark),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    itemName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ZadType.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  Text(
                    'اشتريه من أمازون',
                    maxLines: 1,
                    style: ZadType.labelSmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurfaceVariant,
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

/// Kotlin's `InventoryItemCard`.
class _InventoryItemCard extends StatelessWidget {
  const new({
    required this.item,
    required this.today,
    required this.onConsume,
    required this.onRestock,
    required this.onEdit,
    required this.onDelete,
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
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final days = item.daysUntilExpiry(today);
    final def = _defFor(item.category, item.itemName);
    final isLow = !grouped && item.quantity <= (item.lowStockThreshold ?? 2);

    Widget small(IconData icon, String label, Color tint, VoidCallback? tap) =>
        SizedBox.square(
          dimension: 26,
          child: IconButton(
            padding: EdgeInsets.zero,
            tooltip: label,
            onPressed: tap,
            icon: Icon(icon, size: 16, color: tint),
          ),
        );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: composeShadow(
          elevation: 2,
          ambient: Colors.black,
          spot: Colors.black,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scheme.outline, width: 0.5),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _bgOf(def, scheme),
                borderRadius: BorderRadius.circular(14),
              ),
              child: _FloatingIdle(
                amplitude: 1.2,
                child: Text(
                  foodEmoji(item.itemName),
                  style: const TextStyle(fontSize: 22),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          item.itemName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      if (isLow) ...<Widget>[
                        const SizedBox(width: 6),
                        // Flexible and scaled down, not fixed: on a 320dp
                        // phone the stepper leaves this column narrower than
                        // the badge, which overflowed by 30px.
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: const Text(
                                'منخفض',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFDC2626),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: <Widget>[
                      if (days != null) ...<Widget>[
                        Text(
                          days <= 0 ? 'منتهي' : '$days يوم',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: _expiryColor(context, days),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          '•',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          def.key,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  FractionallySizedBox(
                    widthFactor: 0.85,
                    alignment: AlignmentDirectional.centerStart,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(end: _stockRatio(item)),
                        duration: const Duration(milliseconds: 450),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, _) => LinearProgressIndicator(
                          value: v,
                          minHeight: 3,
                          color: _stockColor(context, item),
                          backgroundColor: const Color(0xFFF1F5F9),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  small(
                    Icons.remove_circle_outline,
                    'استهلاك واحدة',
                    item.quantity > 0 ? scheme.error : scheme.outline,
                    item.quantity > 0 ? onConsume : null,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '${item.quantity} ${item.unit ?? ''}'.trim(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  small(
                    Icons.add_circle_outline,
                    'زيادة واحدة',
                    scheme.primary,
                    onRestock,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            SizedBox.square(
              dimension: 26,
              child: IconButton(
                padding: EdgeInsets.zero,
                tooltip: 'تعديل الصنف',
                onPressed: onEdit,
                icon: const Icon(
                  Icons.edit,
                  size: 15,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ),
            SizedBox.square(
              dimension: 26,
              child: IconButton(
                padding: EdgeInsets.zero,
                tooltip: 'حذف',
                onPressed: onDelete,
                icon: const Icon(
                  Icons.delete_outline,
                  size: 15,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A staple as one stock: the house total across its brands, − and +, and
/// whether it is low. A tap opens the brands under it.
class _FamilyCard extends StatelessWidget {
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
    final scheme = Theme.of(context).colorScheme;
    final units = group.members.map((m) => m.unit).toSet();
    final unit = units.length == 1 ? (units.single ?? '') : '';
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(ZadRadii.cardLarge),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.all(ZadSpacing.lg),
          child: Row(
            children: <Widget>[
              Text(foodEmoji(group.name), style: ZadType.titleLarge),
              const SizedBox(width: ZadSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            group.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ZadType.titleMedium,
                          ),
                        ),
                        if (group.isLow) ...<Widget>[
                          const SizedBox(width: ZadSpacing.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.errorContainer,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              group.isOut ? 'خلص' : 'منخفض',
                              style: ZadType.labelSmall.copyWith(
                                fontWeight: FontWeight.bold,
                                color: scheme.error,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${group.members.length} أنواع · '
                      '${open ? 'اخفي الأنواع' : 'اعرض الأنواع'}',
                      style: ZadType.labelSmall.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'استهلكت واحدة',
                onPressed: onConsume,
                icon: Icon(
                  Icons.remove_circle_outline,
                  color: onConsume == null
                      ? scheme.outlineVariant
                      : ZadColors.terracottaRust,
                ),
              ),
              Text(
                '${group.total} $unit'.trim(),
                style: ZadType.titleSmall.copyWith(color: scheme.primary),
              ),
              IconButton(
                tooltip: 'زوّد واحدة',
                onPressed: onRestock,
                icon: Icon(Icons.add_circle_outline, color: scheme.primary),
              ),
              Icon(
                open ? Icons.expand_less : Icons.expand_more,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kotlin's `ShortageItemCard`.
class _ShortageItemCard extends StatefulWidget {
  const new({required this.item, required this.today, required this.onAdd});

  final InventoryItem item;
  final DateTime today;
  final VoidCallback onAdd;

  @override
  State<_ShortageItemCard> createState() => _ShortageItemCardState();
}

class _ShortageItemCardState extends State<_ShortageItemCard> {
  bool _added = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final success = context.zadExt.success;
    final item = widget.item;
    final days = item.daysUntilExpiry(widget.today);
    final def = _defFor(item.category, item.itemName);
    return ZadListCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _bgOf(def, scheme),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _FloatingIdle(
                    amplitude: 1.5,
                    child: Text(
                      pantryEmojiOf(item.itemName, item.category),
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        item.itemName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ZadType.bodySmall.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurface,
                        ),
                      ),
                      Text(
                        days != null && days <= 0
                            ? 'منتهي'
                            : days != null
                            ? '$days يوم'
                            : 'الكمية: ${item.quantity}',
                        style: ZadType.labelSmall.copyWith(
                          fontSize: 9.5,
                          color: days != null
                              ? _expiryColor(context, days)
                              : scheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: _stockRatio(item),
                minHeight: 3,
                color: _stockColor(context, item),
                backgroundColor: scheme.outlineVariant,
              ),
            ),
            const SizedBox(height: 4),
            FilledButton(
              onPressed: _added
                  ? null
                  : () {
                      setState(() => _added = true);
                      widget.onAdd();
                    },
              style: FilledButton.styleFrom(
                backgroundColor: _added ? success : scheme.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: success,
                disabledForegroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 4),
                minimumSize: const Size.fromHeight(28),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    _added ? Icons.check : Icons.add_shopping_cart,
                    size: 12,
                  ),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      _added ? 'أُضيفت' : 'نزّلها في التسوق',
                      maxLines: 1,
                      style: const TextStyle(fontSize: 10.5),
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
  final TextEditingController _expiry = TextEditingController();
  int _unit = 0;
  int _category = 0;

  @override
  void dispose() {
    _name.dispose();
    _qty.dispose();
    _expiry.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final navigator = Navigator.of(context);
    final raw = _expiry.text.trim();
    final parsed = raw.isEmpty ? null : DateTime.tryParse(raw);
    await ref
        .read(pantryControllerProvider.notifier)
        .add(
          itemName: name,
          quantity: int.tryParse(_qty.text) ?? 1,
          unit: kPantryUnits[_unit],
          category: _categoryDefs[_category + 1].key,
          expiryDate: parsed == null
              ? null
              : DateTime.utc(parsed.year, parsed.month, parsed.day),
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
                    'إضافة منتج جديد',
                    style: ZadType.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),
                  SizedBox.square(
                    dimension: 28,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      tooltip: 'إغلاق',
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
              Text('اسم المنتج', style: label),
              const SizedBox(height: 6),
              TextField(
                controller: _name,
                decoration: field(hint: 'مثلاً: حليب'),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text('الكمية', style: label),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _qty,
                          keyboardType: TextInputType.number,
                          decoration: field(),
                          onChanged: (v) {
                            final digits = v.replaceAll(RegExp(r'\D'), '');
                            if (digits != v) _qty.text = digits;
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
                        Text('الوحدة', style: label),
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
                            for (var i = 0; i < _unitLabels.length; i++)
                              DropdownMenuEntry<int>(
                                value: i,
                                label: _unitLabels[i],
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text('القسم', style: label),
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
                      label: _categoryDefs[i].key,
                      leadingIcon: Icon(
                        _categoryDefs[i].icon,
                        size: 18,
                        color: _fgOf(_categoryDefs[i], scheme),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text('تاريخ الصلاحية (اختياري)', style: label),
              const SizedBox(height: 6),
              TextField(
                controller: _expiry,
                decoration: field(hint: '2025-12-31'),
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
                      child: const Text('إلغاء'),
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
                      label: const Text('حفظ'),
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
    text: '${widget.item.quantity}',
  );
  late final TextEditingController _unit = TextEditingController(
    text: widget.item.unit ?? '',
  );

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
    final quantity = int.tryParse(_qty.text);
    final canSave =
        _name.text.trim().isNotEmpty && quantity != null && quantity >= 0;
    return AlertDialog(
      title: Text(
        'تعديل الصنف',
        style: ZadType.titleLarge.copyWith(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'اسم المنتج',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _qty,
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final digits = v.replaceAll(RegExp(r'\D'), '');
                      if (digits != v) _qty.text = digits;
                    },
                    decoration: InputDecoration(
                      labelText: 'الكمية',
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
                    decoration: const InputDecoration(
                      labelText: 'الوحدة',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: canSave
              ? () async {
                  final navigator = Navigator.of(context);
                  final unit = _unit.text.trim();
                  await ref
                      .read(pantryControllerProvider.notifier)
                      .edit(
                        widget.item,
                        itemName: _name.text.trim(),
                        quantity: quantity,
                        unit: unit.isEmpty ? null : unit,
                      );
                  navigator.pop();
                }
              : null,
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}
