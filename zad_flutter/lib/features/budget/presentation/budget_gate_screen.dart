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
import 'package:zad/core/design/foundation/elevation.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/core/money/money.dart';
import 'package:zad/shared/market/domain/market.dart';
import 'package:zad/shared/navigation/zad_screens.dart';
import 'package:zad/shared/settings/application/settings_controller.dart';

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
    return DecoratedBox(
      // The app's own canvas from the first screen, not a flat page.
      decoration: BoxDecoration(gradient: ZadColors.canvas),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(ZadSpacing.xl),
              child: Column(
                children: <Widget>[
                  // The wallet on Zad's own hero gradient, like the balance
                  // card this number will fill.
                  Container(
                    width: 88,
                    height: 88,
                    decoration: const BoxDecoration(
                      gradient: ZadColors.hero,
                      shape: BoxShape.circle,
                      boxShadow: ZadElevation.hero,
                    ),
                    child: const Icon(
                      ZadIcons.wallet,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: ZadSpacing.xl),
                  Text(
                    context.l10n.gateTitle,
                    textAlign: TextAlign.center,
                    style: ZadType.titleLarge.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: ZadSpacing.sm),
                  Text(
                    context.l10n.gateBody,
                    textAlign: TextAlign.center,
                    style: ZadType.bodyMedium.copyWith(
                      color: ZadColors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: ZadSpacing.xl),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: ZadColors.surface,
                      borderRadius: BorderRadius.circular(ZadRadii.card),
                      boxShadow: ZadElevation.card,
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
                                  context.l10n.gateMarket,
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
                            onPressed: () => unawaited(
                              ZadScreens.showRegionalSheet(context),
                            ),
                            child: Text(context.l10n.commonChange),
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
                    // Arabic-Indic digits are typed, not shown (l10n: data).
                    // l10n: data-begin
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.allow(RegExp('[0-9.٠-٩٫]')),
                    ],
                    // l10n: data-end
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => unawaited(_start()),
                    textAlign: TextAlign.center,
                    style: ZadType.headlineMedium.copyWith(
                      fontWeight: FontWeight.w800,
                      color: ZadColors.ink,
                    ),
                    decoration: InputDecoration(
                      labelText: context.l10n.gateCeiling,
                      suffixText:
                          market?.currencySymbol ?? view.settings?.currency,
                      filled: true,
                      fillColor: ZadColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ZadRadii.card),
                        borderSide: BorderSide(color: ZadColors.outline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ZadRadii.card),
                        borderSide: BorderSide(color: ZadColors.outline),
                      ),
                    ),
                  ),
                  const SizedBox(height: ZadSpacing.xl),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        shape: const StadiumBorder(),
                      ),
                      onPressed: canContinue ? () => unawaited(_start()) : null,
                      child: Text(context.l10n.gateStart),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
