/// One rewarded ad, shown on the customer's tap (AdMob account opened
/// 2026-10-13).
///
/// The phone never grants anything. The ad carries the customer's id as SSV
/// `custom_data`; AdMob calls `admob-ssv` with a signed callback, and that
/// grants through `zad_ad_reward_grant`. So [RewardedAds.watch] only says
/// whether AdMob counted the reward — the balance comes from the server a few
/// seconds later.
///
/// Before the first ad: Google's consent form where the law asks for one
/// (UMP), and a content rating of PG.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// The rewarded ad unit. Debug and profile builds use Google's test unit:
/// tapping one's own live ads is invalid traffic and AdMob suspends accounts
/// for it.
const String rewardedAdUnit = kReleaseMode
    ? 'ca-app-pub-4433736715872551/5974535887'
    : 'ca-app-pub-3940256099942544/5224354917';

/// How a watch ended.
enum RewardedOutcome {
  /// AdMob counted the reward; the server grants it through SSV.
  earned,

  /// Closed before the reward.
  dismissed,

  /// No ad: no fill, no network, no consent, or the SDK failed.
  unavailable,
}

/// Rewarded ads, behind an interface for tests.
abstract interface class RewardedAds {
  /// Loads and shows one ad for [userId].
  Future<RewardedOutcome> watch({required String userId});
}

/// AdMob.
class AdMobRewardedAds implements RewardedAds {
  Future<bool>? _ready;

  /// Consent, the rating, and the SDK — once per run.
  Future<bool> _prepare() => _ready ??= () async {
    try {
      final consent = Completer<void>();
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () => unawaited(
          ConsentForm.loadAndShowConsentFormIfRequired((_) {
            if (!consent.isCompleted) consent.complete();
          }),
        ),
        (_) {
          if (!consent.isCompleted) consent.complete();
        },
      );
      await consent.future;
      if (!await ConsentInformation.instance.canRequestAds()) return false;
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(maxAdContentRating: MaxAdContentRating.pg),
      );
      await MobileAds.instance.initialize();
      return true;
    } on Object catch (e) {
      debugPrint('[ads] prepare failed: $e');
      return false;
    }
  }();

  @override
  Future<RewardedOutcome> watch({required String userId}) async {
    if (!await _prepare()) {
      _ready = null; // ask again next time: the form may have been dismissed
      return RewardedOutcome.unavailable;
    }
    final ad = await _load();
    if (ad == null) return RewardedOutcome.unavailable;

    final done = Completer<RewardedOutcome>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdDismissedFullScreenContent: (a) {
        unawaited(a.dispose());
        if (!done.isCompleted) {
          done.complete(
            earned ? RewardedOutcome.earned : RewardedOutcome.dismissed,
          );
        }
      },
      onAdFailedToShowFullScreenContent: (a, e) {
        debugPrint('[ads] show failed: $e');
        unawaited(a.dispose());
        if (!done.isCompleted) done.complete(RewardedOutcome.unavailable);
      },
    );
    try {
      await ad.setServerSideOptions(
        ServerSideVerificationOptions(customData: userId),
      );
      await ad.show(onUserEarnedReward: (_, _) => earned = true);
    } on Object catch (e) {
      debugPrint('[ads] show threw: $e');
      unawaited(ad.dispose());
      return RewardedOutcome.unavailable;
    }
    return await done.future;
  }

  Future<RewardedAd?> _load() {
    final loaded = Completer<RewardedAd?>();
    unawaited(
      RewardedAd.load(
        adUnitId: rewardedAdUnit,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            if (loaded.isCompleted) {
              unawaited(ad.dispose()); // too late, the customer was told
            } else {
              loaded.complete(ad);
            }
          },
          onAdFailedToLoad: (e) {
            debugPrint('[ads] load failed: $e');
            if (!loaded.isCompleted) loaded.complete(null);
          },
        ),
      ).catchError((Object e) {
        debugPrint('[ads] load threw: $e');
        if (!loaded.isCompleted) loaded.complete(null);
      }),
    );
    // Given up on after 15 seconds; one that arrives later is disposed above.
    final giveUp = Timer(const Duration(seconds: 15), () {
      if (!loaded.isCompleted) loaded.complete(null);
    });
    return loaded.future.whenComplete(giveUp.cancel);
  }
}

/// The ads in use.
final rewardedAdsProvider = Provider<RewardedAds>((ref) => AdMobRewardedAds());
