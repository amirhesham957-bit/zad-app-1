/// The AdMob SDK, set up once per run for every ad format.
///
/// Before the first ad: an update of Google's consent information (UMP), the
/// consent form where the law asks for one, and a content rating of PG. The
/// form is asked for only from a tap the customer made (a rewarded ad); a
/// banner, a native card or a full-screen ad at a break never pops a form up
/// by itself.
///
/// The update itself is not a form and runs for every format, once a run.
/// UMP's `canRequestAds()` answers false until `requestConsentInfoUpdate()`
/// has been called — Google's own docs say so — and until 2026-11-13 only
/// the rewarded path called it. So in a run where the customer never tapped
/// «شاهد إعلان», every banner, native card and interstitial asked
/// `canRequestAds()`, got false, and quietly loaded nothing: the closed-test
/// build 1.0.7+8 showed no ad at all.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// The SDK's one-time setup.
abstract final class AdsSdk {
  static Future<void>? _consentInfo;
  static Future<bool>? _sdk;

  /// Forgets this run's setup, for tests.
  @visibleForTesting
  static void resetForTest() {
    _consentInfo = null;
    _sdk = null;
  }

  /// Consent, the rating and the SDK. With [askConsent] false the consent
  /// form is never shown: where one is still owed, this answers false.
  static Future<bool> prepare({bool askConsent = true}) async {
    try {
      await (_consentInfo ??= _updateConsentInfo());
      if (askConsent) await _showFormIfRequired();
      if (!await ConsentInformation.instance.canRequestAds()) {
        // Asked again next time: the network may have been down, or the
        // form dismissed.
        _consentInfo = null;
        debugPrint('[ads] consent does not allow ads yet');
        return false;
      }
    } on Object catch (e) {
      _consentInfo = null;
      debugPrint('[ads] consent failed: $e');
      return false;
    }
    final ok = await (_sdk ??= _start());
    if (!ok) _sdk = null;
    return ok;
  }

  /// Google's advice: every launch. On an error UMP keeps the last run's
  /// status, which `canRequestAds()` then reads.
  static Future<void> _updateConsentInfo() {
    final done = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () {
        if (!done.isCompleted) done.complete();
      },
      (e) {
        debugPrint('[ads] consent info update failed: ${e.message}');
        if (!done.isCompleted) done.complete();
      },
    );
    return done.future;
  }

  static Future<void> _showFormIfRequired() {
    final done = Completer<void>();
    unawaited(
      ConsentForm.loadAndShowConsentFormIfRequired((e) {
        if (e != null) debugPrint('[ads] consent form: ${e.message}');
        if (!done.isCompleted) done.complete();
      }),
    );
    return done.future;
  }

  static Future<bool> _start() async {
    try {
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(maxAdContentRating: MaxAdContentRating.pg),
      );
      await MobileAds.instance.initialize();
      return true;
    } on Object catch (e) {
      debugPrint('[ads] SDK start failed: $e');
      return false;
    }
  }
}

/// Logs why an ad of [kind] did not load, in words a person reading logcat
/// understands. Code 3 (no fill) is the usual answer for a brand-new AdMob
/// app or unit until AdMob has reviewed the app and the units have warmed
/// up; it is not a bug in the app.
void logAdLoadFailure(String kind, LoadAdError e) {
  final why = switch (e.code) {
    0 => 'internal error',
    1 => 'invalid request (wrong unit id or app id?)',
    2 => 'network error',
    3 => 'no fill — normal for a new AdMob app/unit until it is reviewed',
    _ => 'error',
  };
  debugPrint(
    '[ads] $kind load failed: code ${e.code} ($why) '
    'domain ${e.domain}: ${e.message}',
  );
}
