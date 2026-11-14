import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:zad/shared/ads/data/ad_revenue.dart';

void main() {
  tearDown(() => AdRevenue.sink = (_) async {});

  test('one impression becomes the parameters zad_ad_paid takes', () {
    expect(
      adPaidParams(
        AdFormat.appOpen,
        1499.6,
        PrecisionType.publisherProvided,
        'usd',
      ),
      <String, dynamic>{
        'p_format': 'app_open',
        'p_value_micros': 1500,
        'p_currency': 'USD',
        'p_precision': 'publisher_provided',
      },
    );
    expect(
      adPaidParams(
        AdFormat.banner,
        double.nan,
        PrecisionType.unknown,
        'EGP',
      )['p_value_micros'],
      0,
    );
  });

  test(
    'the reporter sends each paid event, and a failed send never throws',
    () async {
      final sent = <Map<String, dynamic>>[];
      AdRevenue.sink = (p) async => sent.add(p);
      await AdRevenue.send(
        adPaidParams(AdFormat.rewarded, 20000, PrecisionType.precise, 'USD'),
      );
      expect(sent.single['p_format'], 'rewarded');

      AdRevenue.sink = (_) async => throw StateError('offline');
      await expectLater(
        AdRevenue.send(
          adPaidParams(AdFormat.native, 1, PrecisionType.estimated, 'USD'),
        ),
        completes,
      );
    },
  );
}
