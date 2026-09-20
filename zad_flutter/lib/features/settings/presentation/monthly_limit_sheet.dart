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
import 'package:zad/core/money/money.dart';
import 'package:zad/design/foundation/squircle.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';
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
    // Prefilled when there is a limit already, because the common reason to
    // open this a second time is to adjust a number, not to retype it.
    text: switch (ref.read(settingsControllerProvider).settings?.monthlyLimit) {
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

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(ZadSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('كام معاك للشهر ده؟', style: ZadType.titleMedium),
            const SizedBox(height: ZadSpacing.sm),
            // What the number means, said before it is asked for. The server
            // anchors the balance to the moment this is written — so it is
            // what is in hand now, not what the salary was.
            Text(
              'اكتب اللي معاك دلوقتي فعلاً. زاد هيحسب المتاح ليك منه، '
              'وهيطرح الالتزامات اللي لسه جاية قبل ما يقولك تصرف كام.',
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
                labelText: 'المبلغ',
                hintText: '0',
                suffixText: currency.isEmpty ? null : currency,
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _parsed == null ? null : _save(),
            ),

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

/// The figure without grouping separators, for an editable field.
String _plain(double value) {
  final rounded = value.asMoney;
  return rounded == rounded.roundToDouble()
      ? rounded.toStringAsFixed(0)
      : rounded.toStringAsFixed(2);
}
