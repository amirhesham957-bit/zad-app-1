// The market list is data the server switches on, so what is pinned here is
// agreement: with the zone table that mirrors `zad_market_timezone`, and with
// the code shapes `zad_users` holds.

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/period/market_calendar.dart';
import 'package:zad/features/market/domain/market.dart';

void main() {
  test('nineteen markets, one per country', () {
    expect(kMarkets, hasLength(19));
    expect(kMarkets.map((m) => m.country).toSet(), hasLength(19));
  });

  test('every market has a zone — none falls back to UTC', () {
    // A market missing from the zone table would put a customer who *did*
    // choose on UTC anyway, which is the failure the picker exists to end.
    for (final market in kMarkets) {
      expect(
        marketTimeZone(market.country),
        isNot('UTC'),
        reason: '${market.country} has no zone in market_calendar.dart',
      );
    }
  });

  test('codes are in the shape zad_users stores', () {
    final alpha2 = RegExp(r'^[A-Z]{2}$');
    final iso4217 = RegExp(r'^[A-Z]{3}$');
    for (final market in kMarkets) {
      expect(market.country, matches(alpha2));
      expect(market.currency, matches(iso4217));
    }
    // The two that exist in the live table today.
    expect(marketFor('EG')?.currency, 'EGP');
    expect(marketFor('SA')?.currency, 'SAR');
  });

  group('marketFor', () {
    test('reads a stored code regardless of case or padding', () {
      expect(marketFor(' eg '), marketFor('EG'));
    });

    test('empty, null and unknown codes are no market', () {
      expect(marketFor(null), isNull);
      expect(marketFor(''), isNull);
      expect(marketFor('XX'), isNull);
      expect(isKnownMarket('XX'), isFalse);
      expect(isKnownMarket('TR'), isTrue);
    });
  });

  group('searchMarkets', () {
    test('an empty query is every market, in order', () {
      expect(searchMarkets('  '), kMarkets);
    });

    test('finds by Arabic name, currency code and symbol', () {
      expect(searchMarkets('مصر').single.country, 'EG');
      expect(searchMarkets('egp').single.country, 'EG');
      expect(searchMarkets('₺').single.country, 'TR');
    });

    test('a query nothing matches is empty, not everything', () {
      expect(searchMarkets('zzz'), isEmpty);
    });
  });
}
