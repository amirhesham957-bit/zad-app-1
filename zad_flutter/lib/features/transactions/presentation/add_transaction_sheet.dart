/// Recording a transaction by hand.
///
/// The bank channel fills the list on its own; this is the other half — the
/// cash purchase no notification will ever mention.
///
/// It writes through the repository, which means Hive first and the network
/// never: the row is in the list before this sheet closes, and the outbox
/// carries it up whenever it can. Nothing here waits on a request.
library;

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
import 'package:zad/features/transactions/application/transactions_controller.dart';
import 'package:zad/features/transactions/domain/transaction.dart';

/// Opens the sheet.
Future<void> showAddTransactionSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ZadColors.surface,
      shape: zadSquircle(ZadRadii.sheet),
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
  final TextEditingController _category = TextEditingController();

  TxnKind _kind = TxnKind.expense;
  Wallet _wallet = Wallet.cash;
  Wallet _transferTo = Wallet.bank;
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _title.dispose();
    _category.dispose();
    super.dispose();
  }

  double? get _parsedAmount => parseMoneyInput(_amount.text);

  bool get _canSave =>
      !_saving &&
      _parsedAmount != null &&
      _title.text.trim().isNotEmpty &&
      // The domain refuses a transfer to the wallet it came from, and it
      // refuses it by throwing. Catching that at the button is the difference
      // between a disabled control and a crash.
      (_kind != TxnKind.transfer || _wallet != _transferTo);

  Future<void> _save() async {
    final amount = _parsedAmount;
    final userId = ref.read(signedInUserIdProvider)();
    if (amount == null || userId == null || !_canSave) return;

    setState(() => _saving = true);
    final title = _title.text.trim();
    final category = _category.text.trim();
    final now = ref.read(nowProvider)();

    try {
      await ref.read(transactionsRepositoryProvider).record((id) {
        return switch (_kind) {
          TxnKind.expense => ZadTransaction.expense(
            id: id,
            userId: userId,
            amount: amount,
            title: title,
            createdAt: now,
            wallet: _wallet,
            category: category.isEmpty ? null : category,
          ),
          TxnKind.income => ZadTransaction.income(
            id: id,
            userId: userId,
            amount: amount,
            title: title,
            createdAt: now,
            wallet: _wallet,
            category: category.isEmpty ? null : category,
          ),
          TxnKind.transfer => ZadTransaction.transfer(
            id: id,
            userId: userId,
            amount: amount,
            title: title,
            createdAt: now,
            from: _wallet,
            to: _transferTo,
          ),
        };
      });

      // The two screens that were already showing figures. Without these the
      // row exists in Hive and neither the list nor the balance knows it.
      ref.read(transactionsControllerProvider.notifier).reloadFromCache();
      ref.read(budgetControllerProvider.notifier).recomputePending();

      // Saved, not sent — and the confirmation says the first, because the
      // second has not happened and may not for a while.
      await HapticFeedback.mediumImpact();
      if (mounted) Navigator.of(context).pop();
    } on Object {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Above the keyboard. Without this the amount field is the thing the
    // keyboard covers.
    final inset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(ZadSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('سجّل عملية', style: ZadType.titleMedium),
            const SizedBox(height: ZadSpacing.lg),

            _KindPicker(
              value: _kind,
              onChanged: (k) => setState(() => _kind = k),
            ),
            const SizedBox(height: ZadSpacing.lg),

            TextField(
              controller: _amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textDirection: TextDirection.ltr,
              style: ZadType.figure(28),
              decoration: const InputDecoration(
                labelText: 'المبلغ',
                hintText: '0',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: ZadSpacing.md),

            TextField(
              controller: _title,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'على إيه؟',
                hintText: 'قهوة، بنزين، إيجار…',
              ),
              onChanged: (_) => setState(() {}),
            ),

            if (_kind != TxnKind.transfer) ...<Widget>[
              const SizedBox(height: ZadSpacing.md),
              TextField(
                controller: _category,
                decoration: const InputDecoration(
                  labelText: 'الفئة (اختياري)',
                  hintText: 'مأكولات، مواصلات…',
                ),
              ),
            ],

            const SizedBox(height: ZadSpacing.lg),
            _WalletPicker(
              label: _kind == TxnKind.transfer ? 'من' : 'من فين؟',
              value: _wallet,
              onChanged: (w) => setState(() => _wallet = w),
            ),

            if (_kind == TxnKind.transfer) ...<Widget>[
              const SizedBox(height: ZadSpacing.md),
              _WalletPicker(
                label: 'إلى',
                value: _transferTo,
                // Excluding the source is what keeps the domain's
                // ArgumentError unreachable from the UI.
                exclude: _wallet,
                onChanged: (w) => setState(() => _transferTo = w),
              ),
            ],

            const SizedBox(height: ZadSpacing.xl),
            // Bottom of the sheet: the thumb is already here.
            // No spinner. The save is a Hive write and an enqueue — it is
            // over in microseconds, and a spinner for a wait that does not
            // exist is a lie about where the work is. `_saving` is here to
            // stop a double tap, which the disabled state already expresses.
            FilledButton(
              onPressed: _canSave ? _save : null,
              child: const Text('احفظ'),
            ),
            const SizedBox(height: ZadSpacing.sm),
            Text(
              'هتتسجّل على طول على تليفونك، وتتبعت أول ما يبقى في نت.',
              style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _KindPicker extends StatelessWidget {
  const new({required this.value, required this.onChanged});

  final TxnKind value;
  final ValueChanged<TxnKind> onChanged;

  @override
  Widget build(BuildContext context) => SegmentedButton<TxnKind>(
    segments: const <ButtonSegment<TxnKind>>[
      ButtonSegment<TxnKind>(value: TxnKind.expense, label: Text('مصروف')),
      ButtonSegment<TxnKind>(value: TxnKind.income, label: Text('دخل')),
      ButtonSegment<TxnKind>(value: TxnKind.transfer, label: Text('تحويل')),
    ],
    selected: <TxnKind>{value},
    onSelectionChanged: (s) => onChanged(s.first),
    showSelectedIcon: false,
  );
}

class _WalletPicker extends StatelessWidget {
  const new({
    required this.label,
    required this.value,
    required this.onChanged,
    this.exclude,
  });

  final String label;
  final Wallet value;
  final ValueChanged<Wallet> onChanged;

  /// A wallet this picker must not offer — the other side of a transfer.
  final Wallet? exclude;

  @override
  Widget build(BuildContext context) {
    final options = Wallet.values.where((w) => w != exclude).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: ZadType.labelMedium.copyWith(color: ZadColors.inkMuted),
        ),
        const SizedBox(height: ZadSpacing.sm),
        Wrap(
          spacing: ZadSpacing.sm,
          children: <Widget>[
            for (final w in options)
              ChoiceChip(
                label: Text(_name(w)),
                selected: w == value,
                onSelected: (_) => onChanged(w),
              ),
          ],
        ),
      ],
    );
  }

  static String _name(Wallet w) => switch (w) {
    Wallet.cash => 'كاش',
    Wallet.card => 'بطاقة',
    Wallet.bank => 'بنك',
  };
}
