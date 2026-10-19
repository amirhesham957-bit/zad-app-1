import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/shared/companion/domain/price_games.dart';
import 'package:zad/shared/prices/domain/prices.dart';
import 'package:zad/shared/transactions/domain/transaction.dart';

ZadTransaction _txn(String title, double amount, {String kind = 'expense'}) =>
    ZadTransaction.fromJson(<String, dynamic>{
      'id': title,
      'user_id': 'u',
      'amount': amount,
      'title': title,
      'created_at': '2026-10-19T10:00:00Z',
      'txn_kind': kind,
      'is_expense': kind == 'expense',
    });

const List<PriceFact> _facts = <PriceFact>[
  PriceFact(label: 'رز', price: 35, source: PriceSource.crowd),
  PriceFact(label: 'لبن', price: 48, source: PriceSource.crowd),
  PriceFact(label: 'عيش', price: 5, source: PriceSource.yours),
  PriceFact(label: 'زيت', price: 95, source: PriceSource.yours),
];

void main() {
  group('the prices', () {
    test('a price is said the way a person says it', () {
      expect(nicePrice(4.3), 4.5);
      expect(nicePrice(37.6), 38);
      expect(nicePrice(312), 310);
      expect(nicePrice(1270), 1250);
      expect(nicePrice(0.1), 0.5);
      expect(priceText(4.5), '4.5');
      expect(priceText(38), '38');
    });

    test(
      "the city's first, then the household's — expenses only, one per title",
      () {
        final facts = priceFactsFrom(
          crowd: <CheapestPrice>[
            CheapestPrice.fromJson(<String, dynamic>{
              'item_name': 'رز',
              'min_price': 30,
              'avg_price': 34.6,
            })!,
          ],
          spent: <ZadTransaction>[
            _txn('زيت', 95.2),
            _txn('زيت', 120),
            _txn('مرتب', 9000, kind: 'income'),
            _txn('رز', 50),
            _txn('', 10),
            _txn('ملاحظة طويلة جداً جداً عن مشوار السوق امبارح', 70),
          ],
        );
        expect(
          facts.map((f) => (f.label, f.price, f.source)),
          <(String, double, PriceSource)>[
            ('رز', 35, PriceSource.crowd),
            ('زيت', 95, PriceSource.yours),
          ],
        );
      },
    );
  });

  group('خمّن السعر', () {
    test('three different prices a round, the real one among them', () {
      final rounds = guessRounds(_facts, math.Random(1));
      expect(rounds, hasLength(4));
      for (final r in rounds) {
        expect(r.options.toSet(), hasLength(3));
        expect(r.options[r.answer], r.fact.price);
      }
    });

    test('too few prices: no game rather than made-up ones', () {
      expect(guessRounds(_facts.take(2).toList(), math.Random(1)), isEmpty);
    });
  });

  group('ذاكرة الأسعار', () {
    test('an item and its price per pair, every price different', () {
      final deck = memoryDeck(<PriceFact>[
        ..._facts,
        const PriceFact(label: 'سكر', price: 35, source: PriceSource.crowd),
      ], math.Random(2));
      expect(deck, hasLength(8));
      final prices = deck.where((c) => c.isPrice).map((c) => c.text).toList();
      expect(prices.toSet(), hasLength(4));
      for (var p = 0; p < 4; p++) {
        expect(
          deck.where((c) => c.pair == p).map((c) => c.isPrice).toSet(),
          <bool>{true, false},
        );
      }
    });
  });
}
