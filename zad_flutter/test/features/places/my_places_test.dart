// «أماكني»: the shops the customer keeps going back to, and the day they go.

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/features/places/domain/my_places.dart';

PlaceVisit _visit(DateTime left, List<String> stores, {double spent = 0}) => (
  id: '$left',
  leftAt: left,
  returnedAt: left.add(const Duration(hours: 1)),
  spent: spent,
  currency: 'EGP',
  merchants: const <String>[],
  stores: stores,
);

void main() {
  DateTime local(DateTime utc) => utc;

  test(
    'a shop seen twice is a habit; its usual day is when most visits were',
    () {
      // 2026-09-03, -10 and -17 are Thursdays; -14 is a Monday.
      final habits = placeHabits(<PlaceVisit>[
        _visit(DateTime.utc(2026, 9, 3, 17), <String>['كارفور']),
        _visit(DateTime.utc(2026, 9, 10, 18), <String>['كارفور', 'العزبي']),
        _visit(DateTime.utc(2026, 9, 14, 12), <String>['العزبي']),
        _visit(DateTime.utc(2026, 9, 17, 17), <String>['كارفور']),
        _visit(DateTime.utc(2026, 9, 18, 17), <String>['سعودي']),
      ], local);
      expect(habits.map((h) => h.name), <String>['كارفور', 'العزبي']);
      expect(habits.first.visits, 3);
      expect(weekdayLabel(habits.first.usualWeekday!), 'الخميس');
    },
  );

  test('a row with unreadable times is skipped, lists are cleaned', () {
    expect(placeVisitFromJson(<String, dynamic>{'id': 'x'}), isNull);
    final v = placeVisitFromJson(<String, dynamic>{
      'id': 'v',
      'left_at': '2026-09-10T15:00:00Z',
      'returned_at': '2026-09-10T16:30:00Z',
      'spent_total': 240.5,
      'stores': <Object?>['كارفور', '', 3],
      'merchants': null,
    })!;
    expect(v.stores, <String>['كارفور']);
    expect(v.merchants, isEmpty);
    expect(v.spent, 240.5);
  });
}
