/// One AdMob App Open ad, loaded when the customer comes back (ZAD_PLAN
/// ١٠.٣ د).
///
/// It is fetched only on a return that qualifies, and shown only if it
/// arrives within [AppOpenAds.loadDeadline] — the moment the app is still
/// coming up — so it never appears seconds after the customer started doing
/// something. One that arrives later is thrown away.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:zad/core/env/zad_env.dart';
import 'package:zad/shared/ads/data/ad_revenue.dart';
import 'package:zad/shared/ads/data/ads_sdk.dart';

/// The unit in use: Google's App Open test unit outside release (tapping
/// one's own live ads is invalid traffic), the configured one in release
/// (`ADMOB_APP_OPEN_UNIT`), or none — and none turns App Open off.
String get appOpenAdUnit => kReleaseMode
    ? ZadEnv.admobAppOpenUnit
    : 'ca-app-pub-3940256099942544/9257395921';

/// App Open ads, behind an interface for tests.
abstract interface class AppOpenAds {
  /// How long a return waits for the ad before giving up on it.
  static const Duration loadDeadline = Duration(seconds: 4);

  /// Whether this build has a unit at all.
  bool get configured;

  /// Loads one and shows it if it arrives within [loadDeadline]; completes
  /// when it closes. Answers whether one showed.
  Future<bool> loadAndShow();
}

/// AdMob.
class AdMobAppOpenAds implements AppOpenAds {
  @override
  bool get configured => appOpenAdUnit.isNotEmpty;

  @override
  Future<bool> loadAndShow() async {
    if (!configured) return false;
    final started = DateTime.now();
    if (!await AdsSdk.prepare(askConsent: false)) return false;
    final loaded = Completer<AppOpenAd?>();
    try {
      await AppOpenAd.load(
        adUnitId: appOpenAdUnit,
        request: const AdRequest(),
        adLoadCallback: AppOpenAdLoadCallback(
          onAdLoaded: (ad) {
            if (loaded.isCompleted) {
              unawaited(ad.dispose()); // too late: the customer moved on
            } else {
              ad.onPaidEvent = AdRevenue.reporter(AdFormat.appOpen);
              loaded.complete(ad);
            }
          },
          onAdFailedToLoad: (e) {
            logAdLoadFailure('app open', e);
            if (!loaded.isCompleted) loaded.complete(null);
          },
        ),
      );
    } on Object catch (e) {
      debugPrint('[ads] app open load threw: $e');
      if (!loaded.isCompleted) loaded.complete(null);
    }
    final left = AppOpenAds.loadDeadline - DateTime.now().difference(started);
    final giveUp = Timer(left.isNegative ? Duration.zero : left, () {
      if (!loaded.isCompleted) loaded.complete(null);
    });
    final ad = await loaded.future.whenComplete(giveUp.cancel);
    if (ad == null) return false;

    final done = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback<AppOpenAd>(
      onAdDismissedFullScreenContent: (a) {
        unawaited(a.dispose());
        if (!done.isCompleted) done.complete(true);
      },
      onAdFailedToShowFullScreenContent: (a, e) {
        debugPrint('[ads] app open show failed: $e');
        unawaited(a.dispose());
        if (!done.isCompleted) done.complete(false);
      },
    );
    try {
      await ad.show();
    } on Object catch (e) {
      debugPrint('[ads] app open show threw: $e');
      unawaited(ad.dispose());
      return false;
    }
    return await done.future;
  }
}

/// The ads in use.
final appOpenAdsProvider = Provider<AppOpenAds>((ref) => AdMobAppOpenAds());
