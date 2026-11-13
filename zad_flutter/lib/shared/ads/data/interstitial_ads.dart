/// One full-screen AdMob ad, loaded ahead so a break never waits for it.
///
/// Loaded quietly in the background and kept for under an hour (AdMob's own
/// expiry); shown at once when the pacer says a break may carry one, so the
/// ad never appears seconds after the customer moved on.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:zad/core/env/zad_env.dart';
import 'package:zad/shared/ads/data/ads_sdk.dart';

/// The unit in use: Google's test unit outside release (tapping one's own
/// live ads is invalid traffic), the configured one in release, or none.
String get interstitialAdUnit => kReleaseMode
    ? ZadEnv.admobInterstitialUnit
    : 'ca-app-pub-3940256099942544/1033173712';

/// Full-screen ads, behind an interface for tests.
abstract interface class InterstitialAds {
  /// Whether this build has a unit at all.
  bool get configured;

  /// Loads one ahead if none is ready.
  Future<void> preload();

  /// Shows the ready ad; completes when it closes. False when none was
  /// ready.
  Future<bool> showReady();
}

/// AdMob.
class AdMobInterstitialAds implements InterstitialAds {
  InterstitialAd? _ad;
  DateTime? _loadedAt;
  bool _loading = false;

  static const Duration _keep = Duration(minutes: 50);

  @override
  bool get configured => interstitialAdUnit.isNotEmpty;

  bool get _fresh =>
      _ad != null &&
      _loadedAt != null &&
      DateTime.now().difference(_loadedAt!) < _keep;

  @override
  Future<void> preload() async {
    if (!configured || _loading || _fresh) return;
    if (!await AdsSdk.prepare(askConsent: false)) return;
    _loading = true;
    unawaited(_ad?.dispose());
    _ad = null;
    try {
      await InterstitialAd.load(
        adUnitId: interstitialAdUnit,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _ad = ad;
            _loadedAt = DateTime.now();
            _loading = false;
          },
          onAdFailedToLoad: (e) {
            logAdLoadFailure('interstitial', e);
            _loading = false;
          },
        ),
      );
    } on Object catch (e) {
      debugPrint('[ads] interstitial load threw: $e');
      _loading = false;
    }
  }

  @override
  Future<bool> showReady() async {
    final ad = _ad;
    if (ad == null || !_fresh) return false;
    _ad = null;
    final done = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
      onAdDismissedFullScreenContent: (a) {
        unawaited(a.dispose());
        if (!done.isCompleted) done.complete(true);
      },
      onAdFailedToShowFullScreenContent: (a, e) {
        debugPrint('[ads] interstitial show failed: $e');
        unawaited(a.dispose());
        if (!done.isCompleted) done.complete(false);
      },
    );
    try {
      await ad.show();
    } on Object catch (e) {
      debugPrint('[ads] interstitial show threw: $e');
      unawaited(ad.dispose());
      return false;
    }
    return await done.future;
  }
}

/// The ads in use.
final interstitialAdsProvider = Provider<InterstitialAds>(
  (ref) => AdMobInterstitialAds(),
);
