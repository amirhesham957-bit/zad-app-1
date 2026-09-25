/// "تعديل المعاملة" — Kotlin's `TransactionEditDialog`: title, amount, kind
/// and category, plus the delete Kotlin offers beside it.
///
/// Both write through the repository: the cache changes at once and the
/// server hears about it through the outbox.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/money/money.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/design/foundation/squircle.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/budget/application/budget_controller.dart';
import 'package:zad/features/scan/domain/scanned_receipt.dart';
import 'package:zad/features/transactions/application/transactions_controller.dart';
import 'package:zad/features/transactions/domain/transaction.dart';

/// Opens the edit sheet for [txn].
Future<void> showEditTransactionSheet(
  BuildContext context,
  ZadTransaction txn,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  backgroundColor: ZadColors.surface,
  shape: zadSquircle(ZadRadii.sheet),
  builder: (_) => EditTransactionSheet(txn: txn),
);

/// Asks before deleting [txn], then deletes it. Returns whether it did.
Future<bool> confirmDeleteTransaction(
  BuildContext context,
  WidgetRef ref,
  ZadTransaction txn,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('حذف'),
      content: Text('هل أنت متأكد من حذف معاملة "${txn.title}"؟'),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('إلغاء'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: ZadColors.terracottaRust,
          ),
          child: const Text('حذف'),
        ),
      ],
    ),
  );
  if (ok != true) return false;
  await ref.read(transactionsRepositoryProvider).delete(txn.id);
  _afterWrite(ref);
  return true;
}

void _afterWrite(WidgetRef ref) {
  ref.read(transactionsControllerProvider.notifier).reloadFromCache();
  ref.read(budgetControllerProvider.notifier).recomputePending();
  unawaited(
    ref.read(outboxProvider).flush().then((_) {}, onError: (Object _) {}),
  );
}

/// The form.
class EditTransactionSheet extends ConsumerStatefulWidget {
  /// Creates the sheet for [txn].
  const new({required this.txn, super.key});

  /// The row being edited.
  final ZadTransaction txn;

  @override
  ConsumerState<EditTransactionSheet> createState() =>
      _EditTransactionSheetState();
}

class _EditTransactionSheetState extends ConsumerState<EditTransactionSheet> {
  late final TextEditingController _title = TextEditingController(
    text: widget.txn.title,
  );
  late final TextEditingController _amount = TextEditingController(
    text: _plain(widget.txn.amount),
  );
  late bool _isExpense = widget.txn.isExpense;
  late String? _category = widget.txn.category;
  bool _saving = false;

  /// Kotlin's list: the standard categories, with the row's own first when it
  /// is something else — so a bank row's odd category is not lost by opening
  /// the sheet.
  late final List<String> _categories = <String>[
    if (widget.txn.category case final c?
        when c.isNotEmpty && !kStandardCategories.contains(c))
      c,
    ...kStandardCategories,
  ];

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  double? get _parsed => parseMoneyInput(_amount.text);

  bool get _canSave =>
      !_saving && _title.text.trim().isNotEmpty && _parsed != null;

  Future<void> _save() async {
    final amount = _parsed;
    if (!_canSave || amount == null) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(transactionsRepositoryProvider)
          .edit(
            widget.txn,
            title: _title.text.trim(),
            amount: amount,
            category: _category,
            isExpense: _isExpense,
          );
      _afterWrite(ref);
      unawaited(HapticFeedback.mediumImpact());
      if (mounted) Navigator.of(context).pop();
    } on Object {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final deleted = await confirmDeleteTransaction(context, ref, widget.txn);
    if (deleted && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final isTransfer = widget.txn.kind == TxnKind.transfer;
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          ZadSpacing.xl,
          0,
          ZadSpacing.xl,
          ZadSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text('تعديل المعاملة', style: ZadType.titleMedium),
            const SizedBox(height: ZadSpacing.lg),
            TextField(
              controller: _title,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'الوصف'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: ZadSpacing.md),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textDirection: TextDirection.ltr,
              style: ZadType.figure(22),
              decoration: const InputDecoration(labelText: 'المبلغ'),
              onChanged: (_) => setState(() {}),
            ),
            if (!isTransfer) ...<Widget>[
              const SizedBox(height: ZadSpacing.lg),
              Text(
                'النوع',
                style: ZadType.labelMedium.copyWith(color: ZadColors.inkMuted),
              ),
              const SizedBox(height: ZadSpacing.sm),
              Wrap(
                spacing: ZadSpacing.sm,
                children: <Widget>[
                  ChoiceChip(
                    label: const Text('مصروف'),
                    selected: _isExpense,
                    onSelected: (_) => setState(() => _isExpense = true),
                  ),
                  ChoiceChip(
                    label: const Text('دخل'),
                    selected: !_isExpense,
                    onSelected: (_) => setState(() => _isExpense = false),
                  ),
                ],
              ),
            ],
            const SizedBox(height: ZadSpacing.lg),
            Text(
              'الفئة',
              style: ZadType.labelMedium.copyWith(color: ZadColors.inkMuted),
            ),
            const SizedBox(height: ZadSpacing.sm),
            Wrap(
              spacing: ZadSpacing.sm,
              runSpacing: ZadSpacing.sm,
              children: <Widget>[
                for (final c in _categories)
                  ChoiceChip(
                    label: Text(c),
                    selected: _category == c,
                    onSelected: (_) => setState(() => _category = c),
                  ),
              ],
            ),
            const SizedBox(height: ZadSpacing.xl),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : _delete,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ZadColors.terracottaRust,
                      minimumSize: const Size(0, 48),
                    ),
                    child: const Text('حذف'),
                  ),
                ),
                const SizedBox(width: ZadSpacing.md),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _canSave ? _save : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    child: const Text('حفظ'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The figure without grouping separators, for an editable field.
String _plain(double value) {
  final rounded = value.asMoney;
  return rounded == rounded.roundToDouble()
      ? rounded.toStringAsFixed(0)
      : rounded.toStringAsFixed(2);
}
