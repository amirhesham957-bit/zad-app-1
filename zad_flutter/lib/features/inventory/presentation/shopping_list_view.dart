/// The shopping list.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/design/components/zad_card.dart';
import 'package:zad/design/components/zad_empty_state.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/inventory/application/shopping_controller.dart';
import 'package:zad/features/inventory/domain/shopping_item.dart';

/// The shopping list.
class ShoppingListView extends ConsumerStatefulWidget {
  /// Creates the view.
  const new({super.key});

  @override
  ConsumerState<ShoppingListView> createState() => _ShoppingListViewState();
}

class _ShoppingListViewState extends ConsumerState<ShoppingListView> {
  final TextEditingController _entry = TextEditingController();

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

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(shoppingControllerProvider);
    final controller = ref.read(shoppingControllerProvider.notifier);

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
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: controller.refresh,
            child: view.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const <Widget>[
                      SizedBox(height: ZadSpacing.xxl),
                      ZadEmptyState(
                        icon: ZadIcons.shopping,
                        title: 'القايمة فاضية',
                        message:
                            'اكتب اللي محتاجه فوق — وأي صنف يخلص من المخزن '
                            'هيتضاف هنا لوحده.',
                      ),
                    ],
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(ZadSpacing.gutter),
                    children: <Widget>[
                      for (final item in view.outstanding) ...<Widget>[
                        _Line(item: item),
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
                          _Line(item: item),
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

class _Line extends ConsumerWidget {
  const new({required this.item});

  final ShoppingItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(shoppingControllerProvider.notifier);
    final urgent = item.priority == ShoppingPriority.high && !item.isPurchased;

    return Dismissible(
      key: ValueKey<String>(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => unawaited(controller.remove(item.id)),
      child: ZadCard(
        padding: const EdgeInsets.symmetric(horizontal: ZadSpacing.sm),
        child: CheckboxListTile(
          value: item.isPurchased,
          onChanged: (v) =>
              unawaited(controller.toggle(item.id, purchased: v ?? false)),
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(
            item.quantity > 1
                ? '${item.itemName} × ${item.quantity}'
                : item.itemName,
            style: ZadType.titleSmall.copyWith(
              color: item.isPurchased ? ZadColors.inkMuted : ZadColors.ink,
              decoration: item.isPurchased
                  ? TextDecoration.lineThrough
                  : TextDecoration.none,
            ),
          ),
          subtitle: urgent
              ? Text(
                  'خلص من المخزن',
                  style: ZadType.labelSmall.copyWith(
                    color: ZadColors.terracottaRust,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
