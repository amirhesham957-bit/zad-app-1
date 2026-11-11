/// One native AdMob ad in the app's own look, inside a list of cards (owner
/// 11/11). It uses Google's small native template, so the ad is drawn by
/// the SDK with its own «Ad» badge and AdChoices, never dressed up as one of
/// Zad's cards.
///
/// It takes no room until an ad has loaded, and nothing loads unless
/// [adsAllowedProvider] allows ads, the build has a native unit, and the
/// consent the SDK holds lets it ask for one. [nativeAdAfter] says where a
/// list places one.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/env/zad_env.dart';
import 'package:zad/shared/ads/application/ads_policy.dart';
import 'package:zad/shared/ads/data/ads_sdk.dart';

/// The unit in use: Google's native test unit outside release, the
/// configured one in release, or none.
String get nativeAdUnit => kReleaseMode
    ? ZadEnv.admobNativeUnit
    : 'ca-app-pub-3940256099942544/2247696110';

/// Whether a list places an ad after its item at [index]: after the third
/// item, then after every sixth — the content always outweighs the ads.
bool nativeAdAfter(int index) => index >= 2 && (index - 2) % 6 == 0;

/// The ad.
class ZadNativeAd extends ConsumerStatefulWidget {
  /// Creates it.
  const new({super.key});

  @override
  ConsumerState<ZadNativeAd> createState() => _ZadNativeAdState();
}

class _ZadNativeAdState extends ConsumerState<ZadNativeAd> {
  NativeAd? _ad;
  bool _asked = false;

  Future<void> _load() async {
    _asked = true;
    if (nativeAdUnit.isEmpty || !ref.read(adsAllowedProvider)) return;
    if (!await AdsSdk.prepare(askConsent: false)) return;
    final ad = NativeAd(
      adUnitId: nativeAdUnit,
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.small,
        mainBackgroundColor: ZadColors.surface,
        cornerRadius: ZadRadii.card,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: ZadColors.green700,
        ),
        primaryTextStyle: NativeTemplateTextStyle(textColor: ZadColors.ink),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: ZadColors.inkMuted,
        ),
      ),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            unawaited(ad.dispose());
            return;
          }
          setState(() => _ad = ad as NativeAd);
        },
        onAdFailedToLoad: (ad, e) {
          debugPrint('[ads] native load failed: $e');
          unawaited(ad.dispose());
        },
      ),
    );
    try {
      await ad.load();
    } on Object catch (e) {
      debugPrint('[ads] native load threw: $e');
      unawaited(ad.dispose());
    }
  }

  @override
  void dispose() {
    unawaited(_ad?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(adsAllowedProvider)) return const SizedBox.shrink();
    if (!_asked) unawaited(_load());
    final ad = _ad;
    if (ad == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ZadSpacing.xs),
      child: ConstrainedBox(
        // Google's small template: 90–200 high.
        constraints: const BoxConstraints(minHeight: 90, maxHeight: 120),
        child: AdWidget(ad: ad),
      ),
    );
  }
}
