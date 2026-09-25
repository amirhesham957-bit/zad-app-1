/// The pantry — Kotlin's `InventoryScreen`: "كل المنتجات" and "النواقص",
/// search, the category chips, what is about to expire (with a recipe ask),
/// and each row's picture, fullness, expiry, −/+, edit and delete.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:zad/app/shell_navigation.dart';
import 'package:zad/core/money/money.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/design/components/zad_card.dart';
import 'package:zad/design/components/zad_empty_state.dart';
import 'package:zad/design/foundation/squircle.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/chat/application/chat_controller.dart';
import 'package:zad/features/inventory/application/pantry_controller.dart'
    hide PantryView;
import 'package:zad/features/inventory/application/pantry_controller.dart'
    as pantry
    show PantryView;
import 'package:zad/features/inventory/application/shopping_controller.dart';
import 'package:zad/features/inventory/domain/inventory_item.dart';
import 'package:zad/features/inventory/domain/pantry_categories.dart';
import 'package:zad/features/inventory/domain/shortage.dart';

/// Units a pantry row may carry.
///
/// **Stored values**, written to `zad_inventory.unit` and matched on by the
/// scanner and the brain, so they stay Arabic whatever the interface
/// language. Flutter's first five, then the ones Kotlin's form writes.
const List<String> kPantryUnits = <String>[
  'قطعة',
  'كجم',
  'جرام',
  'لتر',
  'علبة',
  'حبة',
  'كيس',
  'قرشة',
  'صندوق',
];

/// The pantry.
class PantryView extends ConsumerStatefulWidget {
  /// Creates the view, on the shortages tab when [shortagesFirst].
  const new({this.shortagesFirst = false, super.key});

  /// Open on "النواقص" — how Home's cards reach it.
  final bool shortagesFirst;

  @override
  ConsumerState<PantryView> createState() => _PantryViewState();
}

class _PantryViewState extends ConsumerState<PantryView> {
  late int _tab = widget.shortagesFirst ? 1 : 0;
  String _category = 'الكل';
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(pantryControllerProvider);
    final controller = ref.read(pantryControllerProvider.notifier);
    final today = ref.read(nowProvider)();
    final expiring = <InventoryItem>[
      for (final i in view.items)
        if ((i.daysUntilExpiry(today) ?? 99) <= 3) i,
    ];
    final filtered = <InventoryItem>[
      for (final i in view.items)
        if ((_category == 'الكل' ||
                pantryCategoryOf(i.category, i.itemName) == _category) &&
            (_query.isEmpty || i.itemName.contains(_query)))
          i,
    ];

    return RefreshIndicator(
      onRefresh: () => controller.refresh(force: true),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              ZadSpacing.gutter,
              ZadSpacing.md,
              ZadSpacing.gutter,
              0,
            ),
            sliver: SliverList.list(
              children: <Widget>[
                SegmentedButton<int>(
                  segments: <ButtonSegment<int>>[
                    const ButtonSegment<int>(
                      value: 0,
                      label: Text('كل المنتجات'),
                    ),
                    ButtonSegment<int>(
                      value: 1,
                      label: Text(
                        view.shortages.isEmpty
                            ? 'النواقص'
                            : 'النواقص (${view.shortages.length})',
                      ),
                    ),
                  ],
                  selected: <int>{_tab},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() => _tab = s.first),
                ),
                if (view.addedToList > 0) ...<Widget>[
                  const SizedBox(height: ZadSpacing.md),
                  _AddedNote(count: view.addedToList),
                ],
                if (expiring.isNotEmpty) ...<Widget>[
                  const SizedBox(height: ZadSpacing.md),
                  _ExpiringSoon(items: expiring, today: today),
                ],
              ],
            ),
          ),
          if (_tab == 1)
            ..._shortages(view)
          else ...<Widget>[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  ZadSpacing.gutter,
                  ZadSpacing.md,
                  ZadSpacing.gutter,
                  0,
                ),
                child: TextField(
                  onChanged: (q) => setState(() => _query = q.trim()),
                  decoration: const InputDecoration(
                    hintText: 'دوّر في المخزن',
                    prefixIcon: Icon(ZadIcons.search, size: 18),
                    isDense: true,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 56,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: ZadSpacing.gutter,
                    vertical: ZadSpacing.sm,
                  ),
                  children: <Widget>[
                    for (final c in kPantryCategories) ...<Widget>[
                      ChoiceChip(
                        avatar: Text(c.emoji),
                        label: Text(c.key),
                        selected: _category == c.key,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _category = c.key),
                      ),
                      const SizedBox(width: ZadSpacing.sm),
                    ],
                  ],
                ),
              ),
            ),
            if (view.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: ZadEmptyState(
                  icon: ZadIcons.inventory,
                  title: view.error != null
                      ? 'مقدرتش أجيب المخزن'
                      : 'المخزن فاضي',
                  message: view.error != null
                      ? 'اسحب لتحت نجرب تاني.'
                      : 'ضيف اللي عندك، أو صوّر فاتورة البقالة وأنا أقراها.',
                  tone: view.error != null
                      ? ZadEmptyTone.problem
                      : ZadEmptyTone.calm,
                  action: FilledButton.icon(
                    onPressed: () => showAddPantrySheet(context),
                    icon: const Icon(ZadIcons.add),
                    label: const Text('ضيف صنف'),
                  ),
                ),
              )
            else if (filtered.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: ZadEmptyState(
                  icon: ZadIcons.search,
                  title: 'لا توجد نتائج',
                  message: 'جرّب البحث بكلمة مختلفة',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  ZadSpacing.gutter,
                  ZadSpacing.xs,
                  ZadSpacing.gutter,
                  0,
                ),
                sliver: SliverList.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: ZadSpacing.sm),
                  itemBuilder: (_, i) {
                    final item = filtered[i];
                    return _PantryRow(
                      item: item,
                      today: today,
                      reason: _reasonFor(view.shortages, item),
                    );
                  },
                ),
              ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 88)),
        ],
      ),
    );
  }

  List<Widget> _shortages(pantry.PantryView view) {
    if (view.shortages.isEmpty) {
      return const <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: ZadEmptyState(
            icon: ZadIcons.selected,
            title: 'مفيش نواقص!',
            message: 'كل احتياجاتك متوفرة بكميات كافية',
          ),
        ),
      ];
    }
    return <Widget>[
      SliverPadding(
        padding: const EdgeInsets.all(ZadSpacing.gutter),
        sliver: SliverList.separated(
          itemCount: view.shortages.length,
          separatorBuilder: (_, _) => const SizedBox(height: ZadSpacing.sm),
          itemBuilder: (_, i) => _ShortageRow(shortage: view.shortages[i]),
        ),
      ),
    ];
  }

  static ShortageReason? _reasonFor(List<Shortage> shortages, InventoryItem i) {
    for (final shortage in shortages) {
      if (shortage.item.id == i.id) return shortage.reason;
    }
    return null;
  }
}

class _AddedNote extends StatelessWidget {
  const new({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => ZadCard(
    color: ZadColors.mint50,
    child: Row(
      children: <Widget>[
        const Icon(ZadIcons.shopping, size: 18, color: ZadColors.green700),
        const SizedBox(width: ZadSpacing.md),
        Expanded(
          child: Text(
            // Said once, and only when it happened. The shopping list is the
            // one place this app writes on its own, so it should never do it
            // without a word.
            count == 1
                ? 'ضفت صنف خلص لقايمة التسوق.'
                : 'ضفت $count أصناف خلصت لقايمة التسوق.',
            style: ZadType.bodySmall.copyWith(color: ZadColors.slate),
          ),
        ),
      ],
    ),
  );
}

/// "ينتهي قريباً": what goes off within three days, and Kotlin's button that
/// asks زاد for a recipe using them — sent as the customer's own message.
class _ExpiringSoon extends ConsumerWidget {
  const new({required this.items, required this.today});

  final List<InventoryItem> items;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ZadCard(
    color: ZadColors.mustardOchre.withValues(alpha: 0.08),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Icon(
              ZadIcons.duration,
              size: 18,
              color: ZadColors.mustardOchre,
            ),
            const SizedBox(width: ZadSpacing.sm),
            Expanded(
              child: Text(
                'ينتهي قريباً',
                style: ZadType.titleSmall.copyWith(
                  color: ZadColors.mustardOchre,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () {
                final names = items.map((i) => i.itemName).join('، ');
                ref.read(shellNavigationProvider.notifier).open(ShellTab.chat);
                Navigator.of(context).popUntil((r) => r.isFirst);
                unawaited(
                  ref
                      .read(chatControllerProvider.notifier)
                      .send(
                        'اقترح لي وصفة سريعة تستخدم هذه المكونات التي تنتهي '
                        'قريباً: $names',
                      ),
                );
              },
              icon: const Icon(ZadIcons.chef, size: 16),
              label: const Text('اقتراح وصفة'),
            ),
          ],
        ),
        const SizedBox(height: ZadSpacing.xs),
        Wrap(
          spacing: ZadSpacing.sm,
          runSpacing: ZadSpacing.xs,
          children: <Widget>[
            for (final i in items)
              Chip(
                label: Text(
                  '${i.itemName} · ${_expiryText(i.daysUntilExpiry(today)!)}',
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

String _expiryText(int days) => days < 0 ? 'منتهي الصلاحية' : 'باقي $days يوم';

class _PantryRow extends ConsumerWidget {
  const new({required this.item, required this.today, required this.reason});

  final InventoryItem item;
  final DateTime today;
  final ShortageReason? reason;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(pantryControllerProvider.notifier);
    final (accent, label) = switch (reason) {
      ShortageReason.outOfStock => (ZadColors.terracottaRust, 'خلص'),
      ShortageReason.expired => (ZadColors.terracottaRust, 'انتهى'),
      ShortageReason.runningLow => (ZadColors.mustardOchre, 'قرب يخلص'),
      ShortageReason.expiringSoon => (ZadColors.mustardOchre, 'قرب ينتهي'),
      null => (ZadColors.green600, null),
    };
    final days = item.daysUntilExpiry(today);
    final threshold = item.effectiveThreshold;
    final fill = item.quantity <= threshold
        ? ZadColors.terracottaRust
        : item.quantity <= threshold * 2
        ? ZadColors.mustardOchre
        : ZadColors.green600;

    return Dismissible(
      key: ValueKey<String>(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => unawaited(controller.remove(item.id)),
      background: const _DeleteBackground(),
      child: ZadCard(
        onTap: () => unawaited(showEditPantrySheet(context, item)),
        padding: const EdgeInsets.symmetric(
          horizontal: ZadSpacing.lg,
          vertical: ZadSpacing.md,
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(ZadRadii.chip),
              ),
              child: Text(
                pantryEmojiOf(item.itemName, item.category),
                style: const TextStyle(fontSize: 20),
              ),
            ),
            const SizedBox(width: ZadSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(item.itemName, style: ZadType.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    <String>[
                      '${item.quantity} ${item.unit ?? ''}'.trim(),
                      ?label,
                      if (days != null) _expiryText(days),
                      if (item.isPending) 'لسه ما اتبعتش',
                    ].join(' · '),
                    style: ZadType.bodySmall.copyWith(
                      color: label == null ? ZadColors.inkMuted : accent,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(ZadRadii.pill),
                    child: LinearProgressIndicator(
                      value: stockRatio(item.quantity, threshold),
                      minHeight: 4,
                      color: fill,
                      backgroundColor: ZadColors.outlineVariant,
                    ),
                  ),
                ],
              ),
            ),
            _Stepper(
              onMinus: item.quantity > 0
                  ? () => unawaited(controller.adjust(item.id, -1))
                  : null,
              onPlus: () => unawaited(controller.adjust(item.id, 1)),
            ),
          ],
        ),
      ),
    );
  }
}

/// A short item and Kotlin's "نزّلها في التسوق".
class _ShortageRow extends ConsumerWidget {
  const new({required this.shortage});

  final Shortage shortage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = shortage.item;
    final onList = ref
        .watch(shoppingControllerProvider)
        .outstanding
        .any((s) => s.itemName == item.itemName);
    return ZadCard(
      child: Row(
        children: <Widget>[
          Text(
            pantryEmojiOf(item.itemName, item.category),
            style: const TextStyle(fontSize: 22),
          ),
          const SizedBox(width: ZadSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(item.itemName, style: ZadType.titleSmall),
                Text(
                  switch (shortage.reason) {
                    ShortageReason.outOfStock => 'خلص',
                    ShortageReason.expired => 'انتهى',
                    ShortageReason.runningLow => 'منخفض',
                    ShortageReason.expiringSoon => 'قرب ينتهي',
                  },
                  style: ZadType.bodySmall.copyWith(
                    color: ZadColors.terracottaRust,
                  ),
                ),
              ],
            ),
          ),
          if (onList)
            Text(
              'في قائمة التسوق',
              style: ZadType.labelMedium.copyWith(color: ZadColors.green600),
            )
          else
            TextButton.icon(
              onPressed: () => unawaited(
                ref
                    .read(shoppingControllerProvider.notifier)
                    .add(item.itemName),
              ),
              icon: const Icon(ZadIcons.shopping, size: 16),
              label: const Text('نزّلها في التسوق'),
            ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const new({required this.onMinus, required this.onPlus});

  final VoidCallback? onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      IconButton(
        onPressed: onMinus,
        icon: const Icon(Icons.remove, size: 18),
        tooltip: 'استهلاك واحدة',
      ),
      IconButton(
        onPressed: onPlus,
        icon: const Icon(ZadIcons.add, size: 18),
        tooltip: 'زيادة واحدة',
      ),
    ],
  );
}

class _DeleteBackground extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: ShapeDecoration(
      color: ZadColors.terracottaRust.withValues(alpha: 0.12),
      shape: zadSquircle(ZadRadii.card),
    ),
    child: const Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: ZadSpacing.xl),
        child: Icon(ZadIcons.dismiss, color: ZadColors.terracottaRust),
      ),
    ),
  );
}

/// Opens the add-to-pantry sheet.
Future<void> showAddPantrySheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ZadColors.surface,
      shape: zadSquircle(ZadRadii.sheet),
      builder: (_) => const _PantrySheet(),
    );

/// Opens Kotlin's "تعديل الصنف" for [item]: name, count, unit — and delete.
Future<void> showEditPantrySheet(BuildContext context, InventoryItem item) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ZadColors.surface,
      shape: zadSquircle(ZadRadii.sheet),
      builder: (_) => _PantrySheet(editing: item),
    );

class _PantrySheet extends ConsumerStatefulWidget {
  const new({this.editing});

  final InventoryItem? editing;

  @override
  ConsumerState<_PantrySheet> createState() => _PantrySheetState();
}

class _PantrySheetState extends ConsumerState<_PantrySheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.editing?.itemName ?? '',
  );
  late final TextEditingController _quantity = TextEditingController(
    text: '${widget.editing?.quantity ?? 1}',
  );
  late String _unit = widget.editing?.unit ?? kPantryUnits.first;
  String? _category;
  DateTime? _expiry;
  bool _saving = false;

  bool get _isEdit => widget.editing != null;

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    super.dispose();
  }

  int? get _parsedQuantity {
    final raw = _quantity.text.trim();
    // Zero is a real count when editing: "I have none left".
    if (_isEdit && (raw == '0' || raw == '٠')) return 0;
    return parseMoneyInput(raw)?.round();
  }

  bool get _canSave {
    final q = _parsedQuantity;
    return !_saving &&
        _name.text.trim().isNotEmpty &&
        q != null &&
        (q > 0 || _isEdit);
  }

  Future<void> _save() async {
    final quantity = _parsedQuantity;
    if (!_canSave || quantity == null) return;
    setState(() => _saving = true);
    final controller = ref.read(pantryControllerProvider.notifier);
    final editing = widget.editing;
    if (editing != null) {
      await controller.edit(
        editing,
        itemName: _name.text,
        quantity: quantity,
        unit: _unit,
      );
    } else {
      await controller.add(
        itemName: _name.text,
        quantity: quantity,
        unit: _unit,
        category: _category,
        expiryDate: _expiry,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickExpiry() async {
    final now = ref.read(nowProvider)();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiry ?? now.add(const Duration(days: 7)),
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(
        () => _expiry = DateTime.utc(picked.year, picked.month, picked.day),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(ZadSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _isEdit ? 'تعديل الصنف' : 'ضيف للمخزن',
            style: ZadType.titleMedium,
          ),
          const SizedBox(height: ZadSpacing.lg),
          TextField(
            controller: _name,
            autofocus: !_isEdit,
            decoration: const InputDecoration(
              labelText: 'اسم المنتج',
              hintText: 'مثلاً: حليب',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: ZadSpacing.md),
          TextField(
            controller: _quantity,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(labelText: 'الكمية'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: ZadSpacing.lg),
          Text(
            'الوحدة',
            style: ZadType.labelMedium.copyWith(color: ZadColors.inkMuted),
          ),
          const SizedBox(height: ZadSpacing.sm),
          Wrap(
            spacing: ZadSpacing.sm,
            runSpacing: ZadSpacing.sm,
            children: <Widget>[
              for (final unit in <String>{...kPantryUnits, _unit})
                ChoiceChip(
                  label: Text(unit),
                  selected: unit == _unit,
                  onSelected: (_) => setState(() => _unit = unit),
                ),
            ],
          ),
          if (!_isEdit) ...<Widget>[
            const SizedBox(height: ZadSpacing.lg),
            Text(
              'القسم',
              style: ZadType.labelMedium.copyWith(color: ZadColors.inkMuted),
            ),
            const SizedBox(height: ZadSpacing.sm),
            Wrap(
              spacing: ZadSpacing.sm,
              runSpacing: ZadSpacing.sm,
              children: <Widget>[
                for (final c in kPantryCategories.skip(1))
                  ChoiceChip(
                    avatar: Text(c.emoji),
                    label: Text(c.key),
                    selected: _category == c.key,
                    onSelected: (_) => setState(
                      () => _category = _category == c.key ? null : c.key,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: ZadSpacing.lg),
            OutlinedButton.icon(
              onPressed: () => unawaited(_pickExpiry()),
              icon: const Icon(ZadIcons.duration, size: 18),
              label: Text(
                _expiry == null
                    ? 'تاريخ الصلاحية (اختياري)'
                    : DateFormat('d MMMM y', 'ar').format(_expiry!),
              ),
            ),
          ],
          const SizedBox(height: ZadSpacing.xl),
          Row(
            children: <Widget>[
              if (_isEdit) ...<Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      unawaited(
                        ref
                            .read(pantryControllerProvider.notifier)
                            .remove(widget.editing!.id),
                      );
                      Navigator.of(context).pop();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ZadColors.terracottaRust,
                    ),
                    child: const Text('حذف'),
                  ),
                ),
                const SizedBox(width: ZadSpacing.md),
              ],
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _canSave ? _save : null,
                  child: const Text('احفظ'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
