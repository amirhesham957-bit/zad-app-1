/// The pantry.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/money/money.dart';
import 'package:zad/design/components/zad_card.dart';
import 'package:zad/design/components/zad_empty_state.dart';
import 'package:zad/design/foundation/squircle.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/inventory/application/pantry_controller.dart';
import 'package:zad/features/inventory/domain/inventory_item.dart';
import 'package:zad/features/inventory/domain/shortage.dart';

/// Units a pantry row may carry.
///
/// **Stored values**, written to `zad_inventory.unit` and matched on by the
/// scanner and the brain, so they stay Arabic whatever the interface language.
const List<String> kPantryUnits = <String>[
  'قطعة',
  'كجم',
  'جرام',
  'لتر',
  'علبة',
];

/// The pantry list.
class PantryView extends ConsumerWidget {
  /// Creates the view.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(pantryControllerProvider);
    final controller = ref.read(pantryControllerProvider.notifier);

    return RefreshIndicator(
      onRefresh: () => controller.refresh(force: true),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          if (view.addedToList > 0)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                ZadSpacing.gutter,
                ZadSpacing.md,
                ZadSpacing.gutter,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: _AddedNote(count: view.addedToList),
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
          else
            SliverPadding(
              padding: const EdgeInsets.all(ZadSpacing.gutter),
              sliver: SliverList.separated(
                itemCount: view.items.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: ZadSpacing.sm),
                itemBuilder: (_, i) {
                  final item = view.items[i];
                  return _PantryRow(
                    item: item,
                    reason: _reasonFor(view.shortages, item),
                  );
                },
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 88)),
        ],
      ),
    );
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

class _PantryRow extends ConsumerWidget {
  const new({required this.item, required this.reason});

  final InventoryItem item;
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

    return Dismissible(
      key: ValueKey<String>(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => unawaited(controller.remove(item.id)),
      background: const _DeleteBackground(),
      child: ZadCard(
        padding: const EdgeInsets.symmetric(
          horizontal: ZadSpacing.lg,
          vertical: ZadSpacing.md,
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 4,
              height: 36,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(2),
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
                      if (item.isPending) 'لسه ما اتبعتش',
                    ].join(' · '),
                    style: ZadType.bodySmall.copyWith(
                      color: label == null ? ZadColors.inkMuted : accent,
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
        tooltip: 'قلّل',
      ),
      IconButton(
        onPressed: onPlus,
        icon: const Icon(ZadIcons.add, size: 18),
        tooltip: 'زوّد',
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
      builder: (_) => const _AddPantrySheet(),
    );

class _AddPantrySheet extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_AddPantrySheet> createState() => _AddPantrySheetState();
}

class _AddPantrySheetState extends ConsumerState<_AddPantrySheet> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _quantity = TextEditingController(text: '1');
  String _unit = kPantryUnits.first;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    super.dispose();
  }

  int? get _parsedQuantity => parseMoneyInput(_quantity.text)?.round();

  bool get _canSave =>
      !_saving && _name.text.trim().isNotEmpty && (_parsedQuantity ?? 0) > 0;

  Future<void> _save() async {
    final quantity = _parsedQuantity;
    if (!_canSave || quantity == null) return;
    setState(() => _saving = true);
    await ref
        .read(pantryControllerProvider.notifier)
        .add(itemName: _name.text, quantity: quantity, unit: _unit);
    if (mounted) Navigator.of(context).pop();
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
          const Text('ضيف للمخزن', style: ZadType.titleMedium),
          const SizedBox(height: ZadSpacing.lg),
          TextField(
            controller: _name,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'إيه هو؟',
              hintText: 'لبن، أرز، زيت…',
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
          Wrap(
            spacing: ZadSpacing.sm,
            children: <Widget>[
              for (final unit in kPantryUnits)
                ChoiceChip(
                  label: Text(unit),
                  selected: unit == _unit,
                  onSelected: (_) => setState(() => _unit = unit),
                ),
            ],
          ),
          const SizedBox(height: ZadSpacing.xl),
          FilledButton(
            onPressed: _canSave ? _save : null,
            child: const Text('احفظ'),
          ),
        ],
      ),
    ),
  );
}
