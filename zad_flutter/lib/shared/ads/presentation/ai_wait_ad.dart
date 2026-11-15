/// The ad that covers an AI wait (owner 15/11: every AI request carries a
/// video ad while the AI works).
///
/// Built once per wait, it reports [InterstitialBreak.aiWait] (the pacer
/// decides whether a full-screen ad shows) and draws one native ad in
/// Google's medium template, whose media view plays video, muted. When the
/// build has no native unit, or the native ad does not load, it falls back to
/// the inline banner, which can carry video creatives too. Nothing renders or
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

  @override
  ConsumerState<ZadAiWaitAd> createState() => _ZadAiWaitAdState();
}

class _ZadAiWaitAdState extends ConsumerState<ZadAiWaitAd> {
  bool _reported = false;
  bool _nativeFailed = false;

  void _report() {
    if (_reported) return;
    _reported = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref.read(interstitialsProvider).atBreak(InterstitialBreak.aiWait),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(adsAllowedProvider)) return const SizedBox.shrink();
    _report();
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
