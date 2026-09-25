/// Setting the cycle's ceiling.
///
/// This is the one number the rest of the app is derived from: with no
/// confirmed limit `zad_budget_state()` answers `remaining: null`, the balance
/// card refuses to print a figure, and the pace bar has no denominator. Until
/// now there was no way to give it — the card offered `onSetBudget` and
/// `HomeScreen` passed null, so tapping "لسه محددتش ميزانيتك" did nothing at
/// all.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:zad/core/money/money.dart';
import 'package:zad/design/foundation/squircle.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/budget/application/budget_controller.dart';
import 'package:zad/features/settings/application/settings_controller.dart';

/// Opens the sheet.
Future<void> showMonthlyLimitSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ZadColors.surface,
      shape: zadSquircle(ZadRadii.sheet),
      builder: (_) => const MonthlyLimitSheet(),
    );

/// The form.
class MonthlyLimitSheet extends ConsumerStatefulWidget {
  /// Creates the sheet.
  const new({super.key});

  @override
  ConsumerState<MonthlyLimitSheet> createState() => _MonthlyLimitSheetState();
}

class _MonthlyLimitSheetState extends ConsumerState<MonthlyLimitSheet> {
  late final TextEditingController _amount = TextEditingController(
    // Prefilled with the balance as it stands now, not the limit it opened
    // with — Kotlin's `BudgetEditSheet` does the same, and for a reason: the
    // server anchors the figure to the moment it is saved, so saving the old
    // opening figure unchanged would quietly hand back everything spent since.
    text: switch (ref.read(budgetControllerProvider).snapshot?.remaining ??
        ref.read(settingsControllerProvider).settings?.monthlyLimit) {
      final double current when current > 0 => _plain(current),
      _ => '',
    },
  );

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  double? get _parsed => parseMoneyInput(_amount.text);

  Future<void> _save() async {
    final amount = _parsed;
    if (amount == null) return;

    final saved = await ref
        .read(settingsControllerProvider.notifier)
        .setMonthlyLimit(amount);
    if (!mounted) return;

    if (saved) {
      await HapticFeedback.mediumImpact();
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(settingsControllerProvider);
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final currency = view.settings?.currency ?? '';
    final committed =
        ref.watch(budgetControllerProvider).snapshot?.committed ?? 0;

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(ZadSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('تعديل الرصيد', style: ZadType.titleMedium),
            const SizedBox(height: ZadSpacing.sm),
            // What the number means, said before it is asked for. The server
            // anchors the balance to the moment this is written — so it is
            // what is in hand now, not what the salary was. Kotlin's two
            // lines, word for word.
            Text(
              'اكتب رصيدك الحالي وزاد يمشي عليه: كل دخل بيزوّده وكل مصروف '
              'بينقّصه.',
              style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
            ),
            const SizedBox(height: ZadSpacing.xs),
            Text(
              'الرقم ده كلمتك الأخيرة — لو زاد حسب غلط، صحّحه من هنا وهو '
              'هيمشي عليه.',
              style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
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
              decoration: InputDecoration(
                labelText: 'الرصيد',
                hintText: '0',
                suffixText: currency.isEmpty ? null : currency,
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _parsed == null ? null : _save(),
            ),

            if (_parsed case final double typed) ...<Widget>[
              const SizedBox(height: ZadSpacing.md),
              _Preview(
                balance: typed,
                committed: committed,
                currency: currency,
              ),
            ],

            const SizedBox(height: ZadSpacing.xl),
            FilledButton(
              onPressed: _parsed == null || view.isSaving ? null : _save,
              child: view.isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('احفظ'),
            ),
            const SizedBox(height: ZadSpacing.sm),
            Text(
              // Unlike the transaction sheet, this one really does wait on the
              // network for a moment: the value is queued and then flushed, so
              // the home screen can show the new figure straight away. It still
              // saves offline — hence "وهيتبعت"، not "بنبعته".
              'هيتسجّل على تليفونك على طول، وهيتبعت أول ما يبقى في نت.',
              style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
            ),

            if (view.error != null) ...<Widget>[
              const SizedBox(height: ZadSpacing.md),
              Text(
                'اتسجل على التليفون، بس لسه ماوصلش للسيرفر. هنعيد المحاولة.',
                style: ZadType.labelSmall.copyWith(
                  color: ZadColors.terracottaRust,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// What the typed balance leaves spendable once the committed obligations
/// are taken out — Kotlin's two preview lines.
class _Preview extends StatelessWidget {
  const new({
    required this.balance,
    required this.committed,
    required this.currency,
  });

  final double balance;
  final double committed;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final available = balance - committed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'متبقي ${_shown(balance)} $currency · محجوز ${_shown(committed)} '
          '$currency',
          style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
        ),
        Text(
          'متاح: ${_shown(available)} $currency',
          style: ZadType.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: available >= 0
                ? ZadColors.green600
                : ZadColors.terracottaRust,
          ),
        ),
      ],
    );
  }
}

String _shown(double v) => NumberFormat('#,##0.##', 'en').format(v);

/// The figure without grouping separators, for an editable field.
String _plain(double value) {
  final rounded = value.asMoney;
  return rounded == rounded.roundToDouble()
      ? rounded.toStringAsFixed(0)
      : rounded.toStringAsFixed(2);
}
