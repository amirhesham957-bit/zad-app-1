/// Kotlin's `AddTransactionDialog` (`HomeScreen.kt`, opened from the budget
/// screen's «إضافة عملية»): the quick expense sheet — title with a close
/// button, «خصم (مصروف)» / «إيداع (راتب)», the three grey rounded fields and
/// the full-width green button. Kotlin's save rules: an income's category is
/// «دخل», an empty description is «بدون وصف», the wallet is Kotlin's default
/// card.
///
/// It writes through the repository, which means Hive first and the network
/// never: the row is in the list before this sheet closes, and the outbox
/// carries it up whenever it can. Nothing here waits on a request.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/money/money.dart';
import 'package:zad/features/budget/application/budget_controller.dart';
import 'package:zad/features/transactions/application/transactions_controller.dart';
import 'package:zad/features/transactions/data/transactions_repository.dart';
import 'package:zad/features/transactions/domain/transaction.dart';

/// Opens the sheet.
Future<void> showAddTransactionSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ZadColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const AddTransactionSheet(),
    );

/// The form.
class AddTransactionSheet extends ConsumerStatefulWidget {
  /// Creates the sheet.
  const new({super.key});

  @override
  ConsumerState<AddTransactionSheet> createState() =>
      _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _category = TextEditingController(text: 'عام');

  bool _isExpense = true;
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _title.dispose();
    _category.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final userId = ref.read(signedInUserIdProvider)();
    if (userId == null || _saving) return;
    setState(() => _saving = true);
    final amount = parseMoneyInput(_amount.text) ?? 0;
    final title = _title.text.isEmpty ? 'بدون وصف' : _title.text;
    final category = _isExpense ? _category.text : 'دخل';
    final now = ref.read(nowProvider)();
    try {
      await ref
          .read(transactionsRepositoryProvider)
          .record(
            (id) => _isExpense
                ? ZadTransaction.expense(
                    id: id,
                    userId: userId,
                    amount: amount,
                    title: title,
                    createdAt: now,
                    wallet: Wallet.card,
                    category: category,
                  )
                : ZadTransaction.income(
                    id: id,
                    userId: userId,
                    amount: amount,
                    title: title,
                    createdAt: now,
                    wallet: Wallet.card,
                    category: category,
                  ),
          );
      ref.read(transactionsControllerProvider.notifier).reloadFromCache();
      ref.read(budgetControllerProvider.notifier).recomputePending();
      await HapticFeedback.mediumImpact();
      if (mounted) Navigator.of(context).pop();
    } on Object {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fieldShape = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    );
    InputDecoration field(String label) => InputDecoration(
      labelText: label,
      filled: true,
      fillColor: ZadColors.surfaceVariant,
      border: fieldShape,
      enabledBorder: fieldShape,
      focusedBorder: fieldShape,
    );
    Widget kind(String label, {required bool expense}) => Expanded(
      child: FilterChip(
        label: SizedBox(
          width: double.infinity,
          child: Text(label, textAlign: TextAlign.center),
        ),
        selected: _isExpense == expense,
        onSelected: (_) => setState(() => _isExpense = expense),
        selectedColor: scheme.primary,
        labelStyle: TextStyle(
          color: _isExpense == expense ? scheme.onPrimary : scheme.onSurface,
        ),
        checkmarkColor: scheme.onPrimary,
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 22),
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Text(
                  _isExpense ? 'إضافة مصروف' : 'إضافة دخل/راتب',
                  style: ZadType.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: ZadColors.ink,
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: InkResponse(
                    onTap: () => Navigator.of(context).pop(),
                    radius: 16,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close,
                        size: 20,
                        color: ZadColors.textTertiary,
                        semanticLabel: 'إلغاء',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                kind('خصم (مصروف)', expense: true),
                const SizedBox(width: 8),
                kind('إيداع (راتب)', expense: false),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _title,
              decoration: field('الوصف (مثال: راتب، إيجار)'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              decoration: field('المبلغ'),
            ),
            if (_isExpense) ...<Widget>[
              const SizedBox(height: 14),
              TextField(
                controller: _category,
                decoration: field('التصنيف (سوبرماركت، فواتير...)'),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  _isExpense ? 'خصم المبلغ' : 'إضافة المبلغ',
                  style: ZadType.titleSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.onPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
