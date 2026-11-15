/// The ad that covers an AI wait, by how long the wait lasts (owner 15/11,
/// approved the same night):
///
/// - a quick answer (under [ZadAiWaitAd.nativeAfter]) shows no ad at all;
/// - a slow one draws one native ad in Google's medium template, whose media
///   view plays video, muted. When the build has no native unit, or the
///   native ad does not load, it falls back to the inline banner;
/// - a long one (still waiting after [ZadAiWaitAd.fullScreenAfter]: a
///   receipt, an analysis, a recipe) also reports [InterstitialBreak.aiWait]
///   once, and the pacer decides whether a full-screen ad shows.
///
/// A request that retries keeps the same widget, so it keeps its native ad
/// and gets no extra full-screen ad on top of the failure. Nothing renders or
/// is reported when [adsAllowedProvider] says no (kids mode, paid plan).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:zad/shared/ads/application/ads_policy.dart';
import 'package:zad/shared/ads/application/interstitials.dart';
import 'package:zad/shared/ads/data/ads_sdk.dart';
import 'package:zad/shared/ads/presentation/inline_ad.dart';
import 'package:zad/shared/ads/presentation/native_ad.dart';

/// The wait ad.
class ZadAiWaitAd extends ConsumerStatefulWidget {
  /// Creates it.
  const new({super.key});

  /// A wait shorter than this shows no ad: the answer was quick.
  static const Duration nativeAfter = Duration(milliseconds: 1500);

  /// A wait longer than this is a long request and may carry a full-screen
  /// ad, if the pacer allows one.
  static const Duration fullScreenAfter = Duration(seconds: 6);

  @override
  ConsumerState<ZadAiWaitAd> createState() => _ZadAiWaitAdState();
}

class _ZadAiWaitAdState extends ConsumerState<ZadAiWaitAd> {
  bool _nativeFailed = false;
  bool _slow = false;
  Timer? _slowTimer;
  Timer? _longTimer;

  @override
  void initState() {
    super.initState();
    _slowTimer = Timer(ZadAiWaitAd.nativeAfter, () {
      if (mounted) setState(() => _slow = true);
    });
    _longTimer = Timer(ZadAiWaitAd.fullScreenAfter, () {
      if (!mounted || !ref.read(adsAllowedProvider)) return;
      unawaited(
        ref.read(interstitialsProvider).atBreak(InterstitialBreak.aiWait),
      );
    });
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    _longTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(adsAllowedProvider) || !_slow) {
      return const SizedBox.shrink();
    }
    if (nativeAdUnit.isEmpty || _nativeFailed) return const ZadInlineAd();
    return ZadNativeAd(
      templateType: TemplateType.medium,
      onFailed: (e) {
        logAdLoadFailure('ai_wait', e);
        if (mounted) setState(() => _nativeFailed = true);
      },
    );
  }
}
