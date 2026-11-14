/// One inline AdMob banner in its own room (owner 11/11: an ad with every
/// AI request and every receipt scan, and never over a task or a button).
///
/// It takes no room until an ad has loaded, sits under the content it follows
/// with a small «إعلان» label above it, and is never placed inside a card,
/// over a list item, or next to a button. Nothing loads unless
/// [adsAllowedProvider] allows ads, the build has an inline unit, and the
/// consent the SDK holds lets it ask for one.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/env/zad_env.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/shared/ads/application/ads_policy.dart';
import 'package:zad/shared/ads/data/ad_revenue.dart';
import 'package:zad/shared/ads/data/ads_sdk.dart';

/// The unit in use: Google's adaptive-banner test unit outside release, the
/// configured one in release, or none.
String get inlineAdUnit => kReleaseMode
    ? ZadEnv.admobInlineUnit
    : 'ca-app-pub-3940256099942544/9214589741';

/// The ad.
class ZadInlineAd extends ConsumerStatefulWidget {
  /// Creates it.
  const new({super.key});

  @override
  ConsumerState<ZadInlineAd> createState() => _ZadInlineAdState();
}

class _ZadInlineAdState extends ConsumerState<ZadInlineAd> {
  BannerAd? _ad;
  AdSize? _size;
  bool _asked = false;

  Future<void> _load(double width) async {
    _asked = true;
    if (inlineAdUnit.isEmpty || !ref.read(adsAllowedProvider)) return;
    if (!await AdsSdk.prepare(askConsent: false)) return;
    final size = AdSize.getCurrentOrientationInlineAdaptiveBannerAdSize(
      width.truncate(),
    );
    final ad = BannerAd(
      adUnitId: inlineAdUnit,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onPaidEvent: AdRevenue.reporter(AdFormat.banner),
        onAdLoaded: (ad) async {
          final real = await (ad as BannerAd).getPlatformAdSize();
          if (!mounted) {
            unawaited(ad.dispose());
            return;
          }
          setState(() {
            _ad = ad;
            _size = real ?? size;
          });
        },
        onAdFailedToLoad: (ad, e) {
          logAdLoadFailure('inline', e);
          unawaited(ad.dispose());
        },
      ),
    );
    try {
      await ad.load();
    } on Object catch (e) {
      debugPrint('[ads] inline load threw: $e');
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
    return LayoutBuilder(
      builder: (context, box) {
        if (!_asked && box.maxWidth.isFinite && box.maxWidth > 0) {
          unawaited(_load(box.maxWidth));
        }
        final ad = _ad;
        final size = _size;
        if (ad == null || size == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: ZadSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                context.l10n.adInlineLabel,
                style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
              ),
              const SizedBox(height: ZadSpacing.xs),
              SizedBox(
                height: size.height.toDouble(),
                child: AdWidget(ad: ad),
              ),
            ],
          ),
        );
      },
    );
  }
}
