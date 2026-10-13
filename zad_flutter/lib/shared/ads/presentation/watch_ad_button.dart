/// «شاهد وخد»: one rewarded ad for attempts, in the attempts sheet.
///
/// Shown only when [adsAllowedProvider] says ads may show and the server's
/// preview says the next ad would be granted — so a tap never ends in an ad
/// that earns nothing. The reward reaches the balance through the server
/// (SSV), so after an ad the button says it is on its way and reads the
/// balance again rather than adding anything itself.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/shared/ads/application/ads_policy.dart';
import 'package:zad/shared/ads/data/ad_reward_preview.dart';
import 'package:zad/shared/ads/data/rewarded_ads.dart';
import 'package:zad/shared/auth/application/session_controller.dart';
import 'package:zad/shared/quota/application/attempts_balance_provider.dart';
import 'package:zad/shared/quota/domain/attempts_balance.dart';

/// When the balance is read again after an ad: SSV usually lands within a
/// few seconds, sometimes later.
const List<Duration> rewardRereads = <Duration>[
  Duration(seconds: 3),
  Duration(seconds: 10),
];

/// The button, or nothing.
class WatchAdButton extends ConsumerStatefulWidget {
  /// Creates it.
  const new({super.key});

  @override
  ConsumerState<WatchAdButton> createState() => _WatchAdButtonState();
}

class _WatchAdButtonState extends ConsumerState<WatchAdButton> {
  bool _busy = false;
  String? _note;
  final List<Timer> _timers = <Timer>[];
  Timer? _waitOver;

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _waitOver?.cancel();
    super.dispose();
  }

  void _later(Duration d, VoidCallback f) => _timers.add(
    Timer(d, () {
      if (mounted) f();
    }),
  );

  Future<void> _watch() async {
    final user = ref.read(sessionControllerProvider);
    if (user == null || _busy) return;
    setState(() {
      _busy = true;
      _note = null;
    });
    final outcome = await ref.read(rewardedAdsProvider).watch(userId: user);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _note = switch (outcome) {
        RewardedOutcome.earned => 'المكافأة في الطريق لرصيدك…',
        RewardedOutcome.dismissed => 'الإعلان اتقفل قبل المكافأة.',
        RewardedOutcome.unavailable => 'مفيش إعلان دلوقتي. جرّب كمان شوية.',
      };
    });
    if (outcome == RewardedOutcome.earned) {
      for (final d in rewardRereads) {
        _later(d, () => ref.invalidate(attemptsBalanceProvider));
      }
    }
    // The count, the box and the minute between two ads all moved.
    ref.invalidate(adRewardPreviewProvider);
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(adsAllowedProvider)) return const SizedBox.shrink();
    final preview = ref.watch(adRewardPreviewProvider).value;
    if (preview == null || preview.reason == 'kids_no_ads') {
      return const SizedBox.shrink();
    }

    final waiting = preview.available && preview.waitSeconds > 0;
    // Asks again once the minute is over; one timer, however often this builds.
    if (waiting && !(_waitOver?.isActive ?? false)) {
      _waitOver = Timer(Duration(seconds: preview.waitSeconds), () {
        if (mounted) ref.invalidate(adRewardPreviewProvider);
      });
    }

    final String label;
    if (preview.capped) {
      label = 'خلصت إعلانات النهارده';
    } else if (waiting) {
      label = 'الإعلان الجاي بعد دقيقة';
    } else {
      label = 'شاهد إعلان وخد ${attemptsLabel(preview.total)}';
    }
    final enabled = preview.available && !waiting && !_busy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        OutlinedButton.icon(
          key: const ValueKey<String>('watch-ad'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            foregroundColor: ZadColors.forestEmerald,
          ),
          onPressed: enabled ? () => unawaited(_watch()) : null,
          icon: _busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(ZadIcons.play, size: 20),
          label: Text(label),
        ),
        if (preview.available && !preview.capped) ...<Widget>[
          const SizedBox(height: ZadSpacing.xs),
          Text(
            preview.boxNext
                ? 'الإعلان ده بيفتح الصندوق: '
                      '+${arabicDigits(preview.boxBonus)} زيادة'
                : 'كل تالت إعلان بيفتح صندوق — '
                      '${arabicDigits(preview.adsToday % 3)} من ٣',
            textAlign: TextAlign.center,
            style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
          ),
        ],
        if (_note != null) ...<Widget>[
          const SizedBox(height: ZadSpacing.xs),
          Text(
            _note!,
            key: const ValueKey<String>('watch-ad-note'),
            textAlign: TextAlign.center,
            style: ZadType.bodySmall.copyWith(color: ZadColors.ink),
          ),
        ],
      ],
    );
  }
}
