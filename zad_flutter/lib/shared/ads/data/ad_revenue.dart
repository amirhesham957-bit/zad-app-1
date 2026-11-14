/// What each ad impression earned, as AdMob reports it (ZAD_PLAN 10.3 g).
///
/// Every ad this app shows hands its `onPaidEvent` to [AdRevenue.reporter],
/// which sends the value to `zad_ad_paid`. The server compares it with what
/// the AI cost the same customer that day (`zad_ads_vs_brain`). The value is
/// AdMob's estimate, not the final payment, so it is enough to know whether
/// the ads cover the AI, not for accounting.
///
/// Nothing here may disturb the ad: a failed send is logged and dropped.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Where one paid event goes; replaced in tests.
typedef AdRevenueSink = Future<void> Function(Map<String, dynamic> params);

/// The kinds of ad, as the server names them.
enum AdFormat {
  /// The inline banner.
  banner('banner'),

  /// The native card.
  native('native'),

  /// The full-screen ad.
  interstitial('interstitial'),

  /// The ad the customer chose to watch.
  rewarded('rewarded'),

  /// The ad on return to the app.
  appOpen('app_open');

  new(this.wire);

  /// The value `zad_ad_paid` takes.
  final String wire;
}

/// [precision] as `zad_ad_paid` takes it.
String precisionWire(PrecisionType precision) => switch (precision) {
  PrecisionType.estimated => 'estimated',
  PrecisionType.publisherProvided => 'publisher_provided',
  PrecisionType.precise => 'precise',
  PrecisionType.unknown => 'unknown',
};

/// The parameters of `zad_ad_paid` for one impression.
Map<String, dynamic> adPaidParams(
  AdFormat format,
  double valueMicros,
  PrecisionType precision,
  String currencyCode,
) => <String, dynamic>{
  'p_format': format.wire,
  'p_value_micros': valueMicros.isFinite ? valueMicros.round() : 0,
  'p_currency': currencyCode.toUpperCase(),
  'p_precision': precisionWire(precision),
};

/// Sends paid events.
abstract final class AdRevenue {
  /// Where they go: `zad_ad_paid` by default.
  static AdRevenueSink sink = _rpc;

  static Future<void> _rpc(Map<String, dynamic> params) async {
    await Supabase.instance.client.rpc<dynamic>('zad_ad_paid', params: params);
  }

  /// The `onPaidEvent` for an ad of [format].
  static OnPaidEventCallback reporter(AdFormat format) =>
      (ad, valueMicros, precision, currencyCode) => unawaited(
        send(adPaidParams(format, valueMicros, precision, currencyCode)),
      );

  /// Sends one event; never throws.
  static Future<void> send(Map<String, dynamic> params) async {
    try {
      await sink(params);
    } on Object catch (e) {
      debugPrint('[ads] paid event not recorded: $e');
    }
  }
}
