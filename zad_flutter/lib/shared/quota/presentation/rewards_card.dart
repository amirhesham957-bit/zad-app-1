/// Home's «مكافآت زاد» card (owner, 13/11: «الذر بتاع شوف اعلان وخد
/// مكافأة مش موجود، واشترك بريميوم مش موجود، والذر بتاع بوت تليجرام
/// اتمسح»).
///
/// Every other way in was conditional: the ad button only when attempts ran
/// low («محاولاتك خلصت» card), the subscribe card once a session, and the
/// Telegram card only while the account is unlinked and not snoozed. With a
/// normal balance on a linked account Home offered none of the three. This
/// card is always there, low on the page, in its own room: the rewarded ad
/// ([WatchAdButton], which hides itself for subscribers, kids and where ads
/// are off), the plans for free customers, and the bot.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/shared/ads/application/ads_policy.dart';
import 'package:zad/shared/ads/presentation/watch_ad_button.dart';
import 'package:zad/shared/navigation/zad_screens.dart';
import 'package:zad/shared/quota/application/attempts_balance_provider.dart';

/// The card.
class RewardsCard extends ConsumerWidget {
  /// Creates the card.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(attemptsBalanceProvider).value;
    // Low or empty: [OutOfAttemptsCard] already says it, with the same
    // buttons — one card at a time.
    if (balance != null && balance.isLow) return const SizedBox.shrink();
    final l = context.l10n;
    // Unknown plan (offline, older server): the free default.
    final free = balance?.isFree ?? true;
    final ads = ref.watch(adsAllowedProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: ZadSpacing.lg),
      child: DecoratedBox(
        key: const ValueKey<String>('rewards-card'),
        decoration: BoxDecoration(
          color: ZadColors.forestEmerald.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(ZadRadii.card),
          border: Border.all(
            color: ZadColors.forestEmerald.withValues(alpha: .25),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(ZadSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(l.rewardsCardTitle, style: ZadType.titleSmall),
              if (free && ads) ...<Widget>[
                const SizedBox(height: ZadSpacing.xs),
                Text(
                  l.rewardsCardBody,
                  style: ZadType.bodySmall.copyWith(
                    color: ZadColors.inkMuted,
                  ),
                ),
                const SizedBox(height: ZadSpacing.md),
                const WatchAdButton(),
              ],
              const SizedBox(height: ZadSpacing.sm),
              if (free)
                FilledButton.icon(
                  key: const ValueKey<String>('rewards-subscribe'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: ZadColors.forestEmerald,
                  ),
                  onPressed: () =>
                      unawaited(ZadScreens.showPaywallScreen(context)),
                  icon: const Icon(Icons.workspace_premium, size: 20),
                  label: Text(l.rewardsSubscribe),
                ),
              const SizedBox(height: ZadSpacing.sm),
              OutlinedButton.icon(
                key: const ValueKey<String>('rewards-telegram'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: ZadColors.forestEmerald,
                ),
                onPressed: () =>
                    unawaited(ZadScreens.showTelegramBotSheet(context)),
                icon: const Icon(ZadIcons.send, size: 20),
                label: Text(l.rewardsTelegram),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
