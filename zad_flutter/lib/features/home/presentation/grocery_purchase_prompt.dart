/// Kotlin's grocery purchase question (`ZadViewModel.pendingGroceryPurchase`
/// and `GroceryPurchasePromptDialog`): a new البقالة expense — bank or manual,
/// no difference — asks «اشتريت من X بـ Y — ضيف إيه للمخزون؟» once.
///
/// Chips from the current pantry (a tap is +1, and does not close the
/// dialog, so several items from one purchase can go in) and a field for a
/// new item; «تم» closes it. Every addition goes through the same intake a
/// photographed receipt uses — merged counts, the shopping list ticked off,
/// the learners told — with `purchase` as the observation's source.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:zad/data/providers.dart';
import 'package:zad/design/tokens/zad_extended_colors.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/budget/application/budget_controller.dart';
import 'package:zad/features/inventory/application/pantry_controller.dart';
import 'package:zad/features/inventory/data/consumption_observations.dart';
import 'package:zad/features/inventory/domain/receipt_intake.dart';
import 'package:zad/features/scan/application/scan_controller.dart';
import 'package:zad/features/transactions/application/transactions_controller.dart';
import 'package:zad/features/transactions/domain/transaction.dart';

const String _promptedKey = 'grocery_prompted_tx_ids';

/// The pending question, or null.
class GroceryPurchasePrompt extends Notifier<ZadTransaction?> {
  Set<String>? _previousIds;

  Set<String> _prompted() =>
      (ref.read(localStoreProvider).device.get(_promptedKey) ?? '')
          .split(',')
          .where((s) => s.isNotEmpty)
          .toSet();

  void _savePrompted(Set<String> ids) {
    final keep = ids.length > 200 ? ids.skip(ids.length - 200).toSet() : ids;
    unawaited(
      ref.read(localStoreProvider).device.put(_promptedKey, keep.join(',')),
    );
  }

  @override
  ZadTransaction? build() {
    ref.listen(transactionsControllerProvider.select((v) => v.rows), (_, rows) {
      final ids = <String>{for (final r in rows) r.id};
      final previous = _previousIds;
      _previousIds = ids;
      // The first load is the baseline: old grocery history must not all ask
      // at once.
      if (previous == null) return;
      final now = ref.read(nowProvider)();
      final prompted = _prompted();
      // Forget prompts older than a week.
      final weekAgo = now.subtract(const Duration(days: 7));
      prompted.removeWhere(
        (id) => rows.any((r) => r.id == id && r.createdAt.isBefore(weekAgo)),
      );
      final dayAgo = now.subtract(const Duration(days: 1));
      final fresh = rows
          .where(
            (r) =>
                !previous.contains(r.id) &&
                !prompted.contains(r.id) &&
                r.category == 'البقالة' &&
                r.kind == TxnKind.expense &&
                r.createdAt.isAfter(dayAgo),
          )
          .firstOrNull;
      if (fresh != null) prompted.add(fresh.id);
      _savePrompted(prompted);
      if (fresh != null) state = fresh;
    }, fireImmediately: true);
    return null;
  }

  /// «تم».
  void dismiss() {
    final tx = state;
    if (tx != null) _savePrompted(_prompted()..add(tx.id));
    state = null;
  }

  /// Kotlin's `addGroceryPurchaseItem`.
  Future<void> add(String itemName) async {
    final name = itemName.trim();
    if (name.isEmpty) return;
    await intakeIntoPantry(ref, <IntakeLine>[
      IntakeLine(name: name, quantity: 1),
    ], source: ObservationSource.purchase);
  }
}

/// The pending question.
final groceryPurchasePromptProvider =
    NotifierProvider<GroceryPurchasePrompt, ZadTransaction?>(
      GroceryPurchasePrompt.new,
    );

/// Raises the dialog on home when a question is pending.
class GroceryPurchasePromptHost extends ConsumerWidget {
  /// Creates the host.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(groceryPurchasePromptProvider, (previous, next) {
      if (next == null || next.id == previous?.id) return;
      unawaited(
        showDialog<void>(
          context: context,
          builder: (_) => _GroceryPurchaseDialog(transaction: next),
        ).then(
          (_) => ref.read(groceryPurchasePromptProvider.notifier).dismiss(),
        ),
      );
    });
    return const SizedBox.shrink();
  }
}

class _GroceryPurchaseDialog extends ConsumerStatefulWidget {
  const new({required this.transaction});

  final ZadTransaction transaction;

  @override
  ConsumerState<_GroceryPurchaseDialog> createState() => _DialogState();
}

class _DialogState extends ConsumerState<_GroceryPurchaseDialog> {
  final TextEditingController _name = TextEditingController();
  final Set<String> _added = <String>{};

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _add(String name) {
    unawaited(ref.read(groceryPurchasePromptProvider.notifier).add(name));
    setState(() => _added.add(name));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tx = widget.transaction;
    final inventory = ref.watch(
      pantryControllerProvider.select((v) => v.items),
    );
    final currency = ref.watch(
      budgetControllerProvider.select((v) => v.snapshot?.currency ?? ''),
    );
    final amount =
        '${NumberFormat('#,##0.##', 'en').format(tx.amount)}'
        '${currency.isEmpty ? '' : ' $currency'}';
    return AlertDialog(
      title: Text(
        'اشتريت من ${tx.merchantName ?? tx.title} بـ $amount — ضيف إيه '
        'للمخزون؟',
        style: ZadType.titleMedium.copyWith(fontWeight: FontWeight.bold),
      ),
      // A horizontal ListView inside AlertDialog needs a bounded width.
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (inventory.isNotEmpty) ...<Widget>[
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: inventory.length > 20 ? 20 : inventory.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final item = inventory[i];
                    final added = _added.contains(item.itemName);
                    return ActionChip(
                      onPressed: () {
                        unawaited(HapticFeedback.heavyImpact());
                        _add(item.itemName);
                      },
                      avatar: Icon(
                        added ? Icons.check : Icons.add,
                        size: 16,
                        color: added ? scheme.primary : null,
                      ),
                      label: Text(item.itemName),
                      backgroundColor: added
                          ? scheme.primary.withValues(alpha: 0.12)
                          : null,
                      labelStyle: added
                          ? TextStyle(color: scheme.primary)
                          : null,
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _name,
                    decoration: InputDecoration(
                      hintText: 'اسم منتج تاني…',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'إضافة',
                  onPressed: () {
                    final name = _name.text.trim();
                    if (name.isEmpty) return;
                    _add(name);
                    _name.clear();
                  },
                  icon: Icon(Icons.add, color: scheme.primary),
                ),
              ],
            ),
            if (_added.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'أضفت ${_added.length} أصناف ✅',
                style: ZadType.labelSmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: context.zadExt.success,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('تم'),
        ),
      ],
    );
  }
}
