/// Kotlin's `BudgetGateScreen`: before any money screen, a signed-in account
/// with no confirmed monthly ceiling is asked for one — with the country and
/// currency Zad will count it in, changeable right there. No skip button, by
/// the owner's decision: without the ceiling there is no «متبقي» or «متاح»,
/// only guesses.
///
/// Shown only once the server has answered (never on a cold start with no
/// figures yet), and never in kids mode — a child does not set the family's
/// ceiling.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/money/money.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/market/domain/market.dart';
import 'package:zad/features/profile/presentation/profile_screen.dart';
import 'package:zad/features/settings/application/settings_controller.dart';

/// The gate.
class BudgetGateScreen extends ConsumerStatefulWidget {
  /// Creates the gate.
  const new({super.key});

  @override
  ConsumerState<BudgetGateScreen> createState() => _BudgetGateState();
}

class _BudgetGateState extends ConsumerState<BudgetGateScreen> {
  final TextEditingController _amount = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final amount = parseMoneyInput(_amount.text);
    if (amount == null || amount <= 0) return;
    final saved = await ref
        .read(settingsControllerProvider.notifier)
        .setMonthlyLimit(amount);
    if (saved) unawaited(HapticFeedback.mediumImpact());
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(settingsControllerProvider);
    final market = marketFor(view.settings?.country);
    final amount = parseMoneyInput(_amount.text);
    final canContinue = amount != null && amount > 0 && !view.isSaving;
    return Scaffold(
      backgroundColor: ZadColors.canvasMid,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(ZadSpacing.xl),
            child: Column(
              children: <Widget>[
                const Icon(
                  ZadIcons.wallet,
                  size: 56,
                  color: ZadColors.green700,
                ),
                const SizedBox(height: 20),
                Text(
                  'قبل ما نبدأ، حدد سقفك الشهري',
                  textAlign: TextAlign.center,
                  style: ZadType.titleLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: ZadSpacing.sm),
                Text(
                  'زاد ما بيخترعش أرقام. من غير السقف مفيش "متبقي" ولا "متاح" '
                  '— وكل رقم هتشوفه هيبقى تخمين.',
                  textAlign: TextAlign.center,
                  style: ZadType.bodyMedium.copyWith(color: ZadColors.inkMuted),
                ),
                const SizedBox(height: ZadSpacing.xl),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: ZadColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ZadSpacing.lg,
                      vertical: ZadSpacing.md,
                    ),
                    child: Row(
                      children: <Widget>[
                        const Icon(
                          ZadIcons.market,
                          size: 20,
                          color: ZadColors.green700,
                        ),
                        const SizedBox(width: ZadSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'البلد والعملة',
                                style: ZadType.labelSmall.copyWith(
                                  color: ZadColors.inkMuted,
                                ),
                              ),
                              Text(
                                market == null
                                    ? (view.settings?.currency ?? '—')
                                    : '${market.nameAr} — ${market.currency}',
                                style: ZadType.titleSmall.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              unawaited(showRegionalSheet(context)),
                          child: const Text('تغيير'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: ZadSpacing.md),
                TextField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp('[0-9.٠-٩٫]')),
                  ],
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => unawaited(_start()),
                  decoration: InputDecoration(
                    labelText: 'سقف الصرف الشهري',
                    suffixText:
                        market?.currencySymbol ?? view.settings?.currency,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    style: FilledButton.styleFrom(shape: const StadiumBorder()),
                    onPressed: canContinue ? () => unawaited(_start()) : null,
                    child: const Text('يلا نبدأ'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
