/// The companion's two price games (ZAD_PLAN ٥.٤): «خمّن السعر» and «ذاكرة
/// الأسعار». Every price in them is a real one — what people in the
/// customer's city reported (`zad_cheapest_prices`) or what the household
/// itself paid (its own expenses) — and each says which. None is made up, so
/// with too few prices the game says so instead of inventing some.
///
/// Like the ball game they grant nothing: no XP, no seeds (ZAD_COMPANION.md).
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:zad/shared/prices/domain/prices.dart';
import 'package:zad/shared/transactions/domain/transaction.dart';

/// Where a price came from.
enum PriceSource {
  /// The average people in the city reported.
  crowd('متوسط الناس في مدينتك'),

  /// What the household paid.
  yours('انت دفعت');

  new(this.label);

  /// Said under the answer.
  final String label;
}

/// One real price.
@immutable
class PriceFact {
  /// Creates it.
  const new({required this.label, required this.price, required this.source});

  /// What it is.
  final String label;

  /// Rounded the way a person would say it ([nicePrice]).
  final double price;

  /// Where it came from.
  final PriceSource source;
}

/// A price as a person would say it: halves under 10, whole under 100, fives
/// under 1000, fifties above.
double nicePrice(double p) {
  final step = p < 10
      ? 0.5
      : p < 100
      ? 1.0
      : p < 1000
      ? 5.0
      : 50.0;
  return math.max(step, (p / step).round() * step);
}

/// The price's text: no decimals unless it has a half.
String priceText(double p) =>
    p == p.roundToDouble() ? p.toStringAsFixed(0) : p.toStringAsFixed(1);

/// Titles longer than this are a note, not an item.
const int _labelMax = 28;

/// The real prices a game can ask about: the city's first, then the
/// household's own expenses (newest first, one per title), at most [max].
List<PriceFact> priceFactsFrom({
  List<CheapestPrice> crowd = const <CheapestPrice>[],
  List<ZadTransaction> spent = const <ZadTransaction>[],
  int max = 24,
}) {
  final seen = <String>{};
  final out = <PriceFact>[];
  void add(String raw, double price, PriceSource source) {
    final label = raw.trim();
    if (out.length >= max) return;
    if (label.isEmpty || label.length > _labelMax || price <= 0) return;
    if (!seen.add(label.toLowerCase())) return;
    out.add(PriceFact(label: label, price: nicePrice(price), source: source));
  }

  for (final c in crowd) {
    add(c.itemName, c.avgPrice, PriceSource.crowd);
  }
  for (final t in spent) {
    if (t.kind != TxnKind.expense || !t.isExpense) continue;
    add(t.title, t.amount, PriceSource.yours);
  }
  return out;
}

/// One question of «خمّن السعر».
@immutable
class GuessRound {
  /// Creates it.
  const new({required this.fact, required this.options, required this.answer});

  /// The item asked about.
  final PriceFact fact;

  /// Three prices, one of them right.
  final List<double> options;

  /// Index of the right one in [options].
  final int answer;
}

/// Rounds a game needs to be worth playing.
const int guessMinFacts = 3;

/// Up to [rounds] questions, each with the real price and two others far
/// enough from it to be told apart; empty with fewer than [guessMinFacts].
List<GuessRound> guessRounds(
  List<PriceFact> facts,
  math.Random rng, {
  int rounds = 5,
}) {
  if (facts.length < guessMinFacts) return const <GuessRound>[];
  final pool = [...facts]..shuffle(rng);
  const factors = <double>[0.5, 0.65, 1.4, 1.75, 2.2];
  return <GuessRound>[
    for (final fact in pool.take(rounds))
      () {
        final options = <double>{fact.price};
        final tries = [...factors]..shuffle(rng);
        for (final f in tries) {
          if (options.length == 3) break;
          options.add(nicePrice(fact.price * f));
        }
        final list = options.toList()..shuffle(rng);
        return GuessRound(
          fact: fact,
          options: list,
          answer: list.indexOf(fact.price),
        );
      }(),
  ];
}

/// One card of «ذاكرة الأسعار»: an item, or its price.
@immutable
class MemoryCard {
  /// Creates it.
  const new({required this.pair, required this.isPrice, required this.text});

  /// The pair it belongs to.
  final int pair;

  /// The price side, not the item side.
  final bool isPrice;

  /// What it shows when turned.
  final String text;
}

/// Pairs a board needs.
const int memoryMinPairs = 3;

/// A shuffled board of up to [pairs] item–price pairs, every price on it
/// different so each card has one match; empty with fewer than
/// [memoryMinPairs].
List<MemoryCard> memoryDeck(
  List<PriceFact> facts,
  math.Random rng, {
  int pairs = 4,
}) {
  final pool = [...facts]..shuffle(rng);
  final prices = <double>{};
  final chosen = <PriceFact>[
    for (final f in pool)
      if (prices.add(f.price)) f,
  ].take(pairs).toList();
  if (chosen.length < memoryMinPairs) return const <MemoryCard>[];
  return <MemoryCard>[
    for (final (i, f) in chosen.indexed) ...<MemoryCard>[
      MemoryCard(pair: i, isPrice: false, text: f.label),
      MemoryCard(pair: i, isPrice: true, text: priceText(f.price)),
    ],
  ]..shuffle(rng);
}
