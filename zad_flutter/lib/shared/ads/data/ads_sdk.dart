/// The AdMob SDK, set up once per run for every ad format.
///
/// Before the first ad: Google's consent form where the law asks for one
/// (UMP), and a content rating of PG. The form is asked for only from a tap
/// the customer made (a rewarded ad); a full-screen ad at a break never pops
/// a form up by itself, it just skips until consent exists.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// The SDK's one-time setup.
abstract final class AdsSdk {
  static Future<bool>? _ready;

  /// Consent, the rating and the SDK. With [askConsent] false, answers
  /// false rather than showing the consent form.
  static Future<bool> prepare({bool askConsent = true}) async {
    if (!askConsent) {
      final ready = _ready;
      if (ready != null) return await ready;
      try {
        if (!await ConsentInformation.instance.canRequestAds()) return false;
      } on Object {
        return false;
      }
    }
    final ok = await (_ready ??= _setUp());
    // Asked again next time: the form may have been dismissed.
    if (!ok) _ready = null;
    return ok;
  }

  static Future<bool> _setUp() async {
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
  }
}
