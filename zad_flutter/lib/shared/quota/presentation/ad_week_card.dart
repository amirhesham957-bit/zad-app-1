/// «شفت ١٥ إعلان الأسبوع ده»: once a week, for a free customer who watched
/// five ads or more, their own numbers next to the plan without ads (income
/// plan 2026-10-11, §4). Not pressure — the customer sees for themselves
/// that their time is worth something. Either button closes it for the week.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_motion.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/shared/ads/application/ads_policy.dart';
import 'package:zad/shared/navigation/zad_screens.dart';
import 'package:zad/shared/quota/data/ad_week_remote.dart';

/// The card, or nothing.
class AdWeekCard extends ConsumerStatefulWidget {
  /// Creates it.
  const new({super.key});

  @override
  ConsumerState<AdWeekCard> createState() => _AdWeekCardState();
}

class _AdWeekCardState extends ConsumerState<AdWeekCard> {
  bool _closed = false;

  Future<void> _close({required bool openPlans}) async {
    setState(() => _closed = true);
    try {
      await ref.read(adWeekRemoteProvider).seen();
    } on Object catch (e) {
      debugPrint('[ad-week] seen failed: $e');
    }
    if (openPlans && mounted) unawaited(ZadScreens.showPaywallScreen(context));
  }

  @override
  Widget build(BuildContext context) {
    // The message is about ads: it goes wherever ads go (never in kids
    // mode).
    final week = ref.watch(adsAllowedProvider)
        ? ref.watch(adWeekProvider).value
        : null;
    return AnimatedSize(
      duration: ZadDuration.enter,
      curve: ZadCurves.standard,
      child: week == null || _closed
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(bottom: ZadSpacing.lg),
              child: Material(
                color: ZadColors.mint50,
                borderRadius: BorderRadius.circular(ZadRadii.card),
                child: Padding(
                  padding: const EdgeInsets.all(ZadSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'شفت ${week.ads} إعلان الأسبوع ده',
                        style: ZadType.titleMedium.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: ZadSpacing.xs),
                      Text(
                        'يعني حوالي ${week.minutes} دقيقة من وقتك. '
                        'الاشتراك من غير إعلانات خالص، ومعاه محاولات أكتر.',
                        style: ZadType.bodyMedium.copyWith(
                          color: ZadColors.slate,
                        ),
                      ),
                      const SizedBox(height: ZadSpacing.md),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: SizedBox(
                              height: 44,
                              child: FilledButton(
                                onPressed: () => _close(openPlans: true),
                                child: const Text('شوف الباقات'),
                              ),
                            ),
                          ),
                          const SizedBox(width: ZadSpacing.sm),
                          SizedBox(
                            height: 44,
                            child: TextButton(
                              onPressed: () => _close(openPlans: false),
                              child: const Text('مش دلوقتي'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
