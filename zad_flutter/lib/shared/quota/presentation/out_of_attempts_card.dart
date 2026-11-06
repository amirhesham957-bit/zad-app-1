/// Home's «محاولاتك خلصت» card (owner, 6/11: «الكوتة قفلت وملقتش الزرار»).
///
/// The rewarded-ad button lived only in the attempts sheet behind the small
/// chip, in a locked chat and on the paywall — nothing on home said where to
/// get an attempt back. This card shows when the balance is low or empty,
/// with the same [WatchAdButton] (three ads = one attempt) and the plans.
/// [WatchAdButton] hides itself for subscribers, kids and where ads are off.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/shared/ads/presentation/watch_ad_button.dart';
import 'package:zad/shared/navigation/zad_screens.dart';
import 'package:zad/shared/quota/application/attempts_balance_provider.dart';

/// The card.
class OutOfAttemptsCard extends ConsumerWidget {
  /// Creates the card.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(attemptsBalanceProvider).value;
    if (balance == null || !balance.isLow) return const SizedBox.shrink();
    final l = context.l10n;
    final empty = balance.left <= 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: ZadSpacing.lg),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: ZadColors.mustardOchre.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(ZadRadii.card),
          border: Border.all(
            color: ZadColors.mustardOchre.withValues(alpha: .4),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(ZadSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                empty ? l.outOfAttemptsTitle : l.lowAttemptsTitle,
                style: ZadType.titleSmall,
              ),
              const SizedBox(height: ZadSpacing.xs),
              Text(
                l.outOfAttemptsBody,
                style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
              ),
              const SizedBox(height: ZadSpacing.md),
              const WatchAdButton(),
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                onPressed: () =>
                    unawaited(ZadScreens.showPaywallScreen(context)),
                child: Text(l.outOfAttemptsPlans),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
