import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/shared/companion/domain/companion_catalog.dart';
import 'package:zad/shared/companion/domain/pet_stories.dart';
import 'package:zad/shared/transactions/domain/transaction.dart';

ZadTransaction _txn(String title, double amount, {String kind = 'expense'}) =>
    ZadTransaction.fromJson(<String, dynamic>{
      'id': '$title$amount',
      'user_id': 'u',
      'amount': amount,
      'title': title,
      'created_at': '2026-10-19T10:00:00Z',
      'txn_kind': kind,
      'is_expense': kind == 'expense',
    });

void main() {
  test("the dream is about yesterday's biggest expense", () {
    final line = PetStories.dream(
      yesterday: <ZadTransaction>[
        _txn('قهوة', 40),
        _txn('سوبرماركت', 620),
        _txn('مرتب', 9000, kind: 'income'),
      ],
      stage: CompanionStage.seed,
      rng: math.Random(0),
    );
    expect(line, contains('«سوبرماركت»'));
    expect(line, startsWith('حلمت'));
  });

  test('no expense yesterday: no dream rather than a made-up one', () {
    expect(
      PetStories.dream(
        yesterday: <ZadTransaction>[_txn('مرتب', 9000, kind: 'income')],
        stage: CompanionStage.seed,
      ),
      isNull,
    );
  });

  test('a grown pet dreams wiser than a young one', () {
    final young = <String>{
      for (var i = 0; i < 8; i++)
        PetStories.dream(
          yesterday: <ZadTransaction>[_txn('عيش', 10)],
          stage: CompanionStage.seed,
          rng: math.Random(i),
        )!,
    };
    final grown = <String>{
      for (var i = 0; i < 8; i++)
        PetStories.dream(
          yesterday: <ZadTransaction>[_txn('عيش', 10)],
          stage: CompanionStage.at(3),
          rng: math.Random(i),
        )!,
    };
    expect(young.intersection(grown), isEmpty);
  });

  test('the weekly word says the real days, and never scolds', () {
    for (final stage in <CompanionStage>[
      CompanionStage.seed,
      CompanionStage.at(3),
    ]) {
      expect(PetStories.weekly(days: 5, goal: 5, stage: stage), contains('5'));
      expect(PetStories.weekly(days: 2, goal: 5, stage: stage), contains('2'));
      final none = PetStories.weekly(days: 0, goal: 5, stage: stage);
      expect(none, isNot(contains('0')));
    }
  });

  test('mornings only for the dream', () {
    expect(isDreamHour(4), isFalse);
    expect(isDreamHour(5), isTrue);
    expect(isDreamHour(11), isTrue);
    expect(isDreamHour(12), isFalse);
  });
}
