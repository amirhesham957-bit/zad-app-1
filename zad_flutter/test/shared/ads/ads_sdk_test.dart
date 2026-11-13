// The closed-test build 1.0.7+8 showed no ad at all (owner, 2026-11-13).
// UMP's canRequestAds() answers false until requestConsentInfoUpdate() has
// run, and only the rewarded tap ran it — so banners, native cards and
// interstitials asked, got false, and loaded nothing. These pin the order.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
// The plugin's own codecs, so the mocked platform answers what it would.
import 'package:google_mobile_ads/src/ad_instance_manager.dart'
    show AdMessageCodec;
import 'package:google_mobile_ads/src/ump/user_messaging_codec.dart';
import 'package:zad/shared/ads/data/ads_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final ump = MethodChannel(
    'plugins.flutter.io/google_mobile_ads/ump',
    StandardMethodCodec(UserMessagingCodec()),
  );
  final sdk = MethodChannel(
    'plugins.flutter.io/google_mobile_ads',
    StandardMethodCodec(AdMessageCodec()),
  );
  late List<String> calls;
  late bool updated;
  late bool consentRequired;
  // The release build on 2026-11-14: AdMob had no consent message, so every
  // update failed with «Publisher misconfiguration».
  late bool updateFails;
  // What UMP remembers from an earlier run (Android's numbering: 0 unknown,
  // 1 not required, 2 required).
  late int storedStatus;

  setUp(() {
    AdsSdk.resetForTest();
    calls = <String>[];
    updated = false;
    consentRequired = false;
    updateFails = false;
    storedStatus = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(ump, (call) async {
        calls.add(call.method);
        switch (call.method) {
          case 'ConsentInformation#requestConsentInfoUpdate':
            if (updateFails) {
              throw PlatformException(
                code: '3',
                message: 'Publisher misconfiguration: no form(s) configured',
              );
            }
            updated = true;
            return null;
          case 'ConsentInformation#canRequestAds':
            // UMP's real behaviour: false before the update; after it, true
            // where no consent is owed (Egypt, Saudi Arabia).
            return updated && !consentRequired;
          case 'ConsentInformation#getConsentStatus':
            if (!updated) return storedStatus;
            return consentRequired ? 2 : 1;
          default:
            return null;
        }
      })
      ..setMockMethodCallHandler(sdk, (call) async {
        calls.add(call.method);
        if (call.method == 'MobileAds#initialize') {
          return InitializationStatus(<String, AdapterStatus>{});
        }
        return null;
      });
  });

  test('a banner or a break updates consent info first, and starts the SDK '
      'without ever showing the form', () async {
    expect(await AdsSdk.prepare(askConsent: false), isTrue);
    final update = calls.indexOf('ConsentInformation#requestConsentInfoUpdate');
    final can = calls.indexOf('ConsentInformation#canRequestAds');
    expect(update, isNonNegative);
    expect(update, lessThan(can));
    expect(calls, contains('MobileAds#initialize'));
    expect(calls.where((c) => c.startsWith('ConsentForm#')), isEmpty);
    expect(calls.where((c) => c.startsWith('UserMessagingPlatform#')), isEmpty);
  });

  test(
    'where consent is owed, a banner answers false and shows no form',
    () async {
      consentRequired = true;
      expect(await AdsSdk.prepare(askConsent: false), isFalse);
      expect(calls, isNot(contains('MobileAds#initialize')));
      expect(
        calls.where((c) => c.startsWith('UserMessagingPlatform#')),
        isEmpty,
      );
    },
  );

  test('a failed update that leaves the status unknown (no consent message '
      'in AdMob) still lets ads load, and never asks for the form', () async {
    updateFails = true;
    expect(await AdsSdk.prepare(askConsent: false), isTrue);
    expect(calls, contains('MobileAds#initialize'));

    AdsSdk.resetForTest();
    calls.clear();
    // The rewarded tap: the form cannot load without a message either.
    expect(await AdsSdk.prepare(), isTrue);
    expect(calls.where((c) => c.startsWith('ConsentForm#')), isEmpty);
    expect(calls.where((c) => c.startsWith('UserMessagingPlatform#')), isEmpty);
  });

  test('a failed update keeps ads off where an earlier run learnt that '
      'consent is owed', () async {
    updateFails = true;
    storedStatus = 2;
    expect(await AdsSdk.prepare(askConsent: false), isFalse);
    expect(calls, isNot(contains('MobileAds#initialize')));
  });
}
