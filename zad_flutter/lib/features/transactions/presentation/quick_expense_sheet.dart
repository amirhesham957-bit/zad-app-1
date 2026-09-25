/// "مصروف سريع" — Kotlin's `ZadQuickExpenseSheet`: name, category, amount,
/// send. Opened from the green card's "خصم سريع" button and its long press.
///
/// The full form (income, transfers, wallets) is `add_transaction_sheet.dart`;
/// this one is the three-field shortcut for the commonest case, an expense.
/// Like the full form, it writes through the repository — Hive first, the
/// outbox after — so the row is in the list before the sheet closes.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/money/money.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/design/foundation/squircle.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/budget/application/budget_controller.dart';
import 'package:zad/features/transactions/application/transactions_controller.dart';
import 'package:zad/features/transactions/domain/transaction.dart';

/// Opens the sheet.
Future<void> showQuickExpenseSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: ZadColors.surface,
      shape: zadSquircle(ZadRadii.hero),
      builder: (_) => const QuickExpenseSheet(),
    );

/// The form.
class QuickExpenseSheet extends ConsumerStatefulWidget {
  /// Creates the sheet.
  const new({super.key});

  @override
  ConsumerState<QuickExpenseSheet> createState() => _QuickExpenseSheetState();
}

class _QuickExpenseSheetState extends ConsumerState<QuickExpenseSheet> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _category = TextEditingController();
  final TextEditingController _amount = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _amount.dispose();
    super.dispose();
  }

  double? get _parsed => parseMoneyInput(_amount.text);

  // parseMoneyInput answers null for anything not above zero, so a null
  // check is the whole of "a real amount".
  bool get _isValid =>
      _name.text.trim().isNotEmpty && _parsed != null && !_sending;

  Future<void> _send() async {
    final amount = _parsed;
    final userId = ref.read(signedInUserIdProvider)();
    if (!_isValid || amount == null || userId == null) return;
    setState(() => _sending = true);
    final category = _category.text.trim();
    try {
      await ref
          .read(transactionsRepositoryProvider)
          .record(
            (id) => ZadTransaction.expense(
              id: id,
              userId: userId,
              amount: amount,
              title: _name.text.trim(),
              createdAt: ref.read(nowProvider)(),
              // Kotlin's quick expense leaves the wallet at its default, the
              // card.
              wallet: Wallet.card,
              category: category.isEmpty ? null : category,
            ),
          );
      ref.read(transactionsControllerProvider.notifier).reloadFromCache();
      ref.read(budgetControllerProvider.notifier).recomputePending();
      unawaited(HapticFeedback.mediumImpact());
      if (mounted) Navigator.of(context).pop();
    } on Object {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          ZadSpacing.lg + 4,
          0,
          ZadSpacing.lg + 4,
          ZadSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: ZadColors.green600.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(ZadRadii.chip),
                  ),
                  child: const SizedBox.square(
                    dimension: 36,
                    child: Icon(
                      ZadIcons.send,
                      size: 18,
                      color: ZadColors.green600,
                    ),
                  ),
                ),
                const SizedBox(width: ZadSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text('مصروف سريع', style: ZadType.titleMedium),
                      Text(
                        'سجّل مصروفك في ثوانٍ',
                        style: ZadType.labelMedium.copyWith(
                          color: ZadColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: ZadSpacing.md),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            const SizedBox(height: ZadSpacing.md),
            _Field(
              label: 'الاسم',
              hint: 'مثال: حلاقة، بقالة',
              controller: _name,
              autofocus: true,
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: ZadSpacing.md),
            _Field(
              label: 'التصنيف',
              hint: 'مثال: مصاريفي، أكلة',
              controller: _category,
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: ZadSpacing.md),
            _Field(
              label: 'المبلغ',
              hint: '0.00',
              controller: _amount,
              number: true,
              action: TextInputAction.send,
              onSubmitted: _send,
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: ZadSpacing.lg),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _isValid ? _send : null,
                style: FilledButton.styleFrom(
                  backgroundColor: ZadColors.green600,
                  disabledBackgroundColor: ZadColors.green600.withValues(
                    alpha: 0.3,
                  ),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ZadRadii.card),
                  ),
                ),
                icon: const Icon(ZadIcons.send, size: 18),
                label: const Text('إرسال'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const new({
    required this.label,
    required this.hint,
    required this.controller,
    required this.onChanged,
    this.autofocus = false,
    this.number = false,
    this.action = TextInputAction.next,
    this.onSubmitted,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final VoidCallback onChanged;
  final bool autofocus;
  final bool number;
  final TextInputAction action;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(ZadRadii.chip),
      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: ZadType.labelMedium.copyWith(color: ZadColors.slate),
        ),
        const SizedBox(height: ZadSpacing.xs),
        TextField(
          controller: controller,
          autofocus: autofocus,
          textInputAction: action,
          keyboardType: number
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          textDirection: number ? TextDirection.ltr : null,
          onChanged: (_) => onChanged(),
          onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            border: border,
            enabledBorder: border,
            focusedBorder: border.copyWith(
              borderSide: const BorderSide(color: ZadColors.green600),
            ),
          ),
        ),
      ],
    );
  }
}
