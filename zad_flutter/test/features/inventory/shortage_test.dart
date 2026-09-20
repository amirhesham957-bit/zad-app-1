// What counts as running out.
//
// Pure rules over the pantry, so they are tested as pure rules: no boxes, no
// network, and the day passed in rather than read. That last part is the
// point — "is this expiring" is a civil-date question, and answering it
// against `DateTime.now()` answers it in the device's zone, which is the
// wrong zone for an account whose market is somewhere else and the wrong
// answer either side of midnight.

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/features/inventory/domain/inventory_item.dart';
import 'package:zad/features/inventory/domain/shopping_item.dart';
import 'package:zad/features/inventory/domain/shortage.dart';

final today = DateTime.utc(2026, 9, 20);

InventoryItem item(
  String name, {
  int quantity = 5,
  int? threshold,
  DateTime? expiry,
}) => InventoryItem(
  id: 'i-$name',
  userId: 'user-1',
  itemName: name,
  quantity: quantity,
  lowStockThreshold: threshold,
  expiryDate: expiry,
);

void main() {
  group('the threshold', () {
    test('is two when nobody set one', () {
      // The Kotlin screens' figure: `lowStockThreshold ?: 2`.
      expect(item('لبن').effectiveThreshold, 2);
    });

    test('never drops below one', () {
      // Zero would mean "warn me when I have less than nothing" — a warning
      // that can never fire.
      expect(item('لبن', threshold: 0).effectiveThreshold, 1);
      expect(item('لبن', threshold: -3).effectiveThreshold, 1);
    });

    test('running low is at the threshold, not past it', () {
      expect(item('لبن', quantity: 2, threshold: 2).isLowStock, isTrue);
      expect(item('لبن', quantity: 3, threshold: 2).isLowStock, isFalse);
    });

    test('getting low is the band above it, and not low itself', () {
      final getting = item('لبن', quantity: 4, threshold: 2);
      expect(getting.isGettingLow, isTrue);
      expect(getting.isLowStock, isFalse);

      // At the threshold it is low, which is a stronger claim than getting
      // low — the two must not both be true or a screen would badge it twice.
      final low = item('لبن', quantity: 2, threshold: 2);
      expect(low.isGettingLow, isFalse);
    });
  });

  group('expiry is counted in days, not instants', () {
    test('tomorrow is one day away whatever the hour is now', () {
      final row = item('زبادي', expiry: DateTime.utc(2026, 9, 21));

      // Late in the evening, which is where an instant comparison goes wrong.
      expect(row.daysUntilExpiry(DateTime.utc(2026, 9, 20, 23, 55)), 1);
      // And early the same morning.
      expect(row.daysUntilExpiry(DateTime.utc(2026, 9, 20, 0, 5)), 1);
    });

    test('yesterday is negative, which is what marks it expired', () {
      final row = item('زبادي', expiry: DateTime.utc(2026, 9, 19));

      expect(row.daysUntilExpiry(today), -1);
    });

    test('no expiry date means no expiry question', () {
      expect(item('ملح').daysUntilExpiry(today), isNull);
      expect(item('ملح').isExpiringSoon(today), isFalse);
    });
  });

  group('why something is a shortage', () {
    test('nothing left beats every other reason', () {
      final row = item('أرز', quantity: 0, expiry: DateTime.utc(2026, 9, 5));

      expect(shortageReasonFor(row, today: today), ShortageReason.outOfStock);
    });

    test('out of date beats running low, even with a full jar', () {
      // A full jar of something that went off last week is not "running low",
      // and calling it that would rank it below an item there are two of.
      final row = item('مربى', quantity: 9, expiry: DateTime.utc(2026, 9, 13));

      expect(shortageReasonFor(row, today: today), ShortageReason.expired);
    });

    test('running low beats expiring soon', () {
      final row = item(
        'لبن',
        quantity: 1,
        threshold: 2,
        expiry: DateTime.utc(2026, 9, 22),
      );

      expect(shortageReasonFor(row, today: today), ShortageReason.runningLow);
    });

    test('expiring soon is within three days, inclusive', () {
      expect(
        shortageReasonFor(
          item('جبنة', expiry: DateTime.utc(2026, 9, 23)),
          today: today,
        ),
        ShortageReason.expiringSoon,
      );
      expect(
        shortageReasonFor(
          item('جبنة', expiry: DateTime.utc(2026, 9, 24)),
          today: today,
        ),
        isNull,
      );
    });

    test('a well-stocked item in date is not a shortage', () {
      expect(
        shortageReasonFor(item('سكر', quantity: 10), today: today),
        isNull,
      );
    });
  });

  group('the shortage list', () {
    test('holds each row once, under its most urgent reason', () {
      // Both the last one and going off tomorrow. One line, not two — the
      // Kotlin screens dedupe the same way after unioning the two sets.
      final both = item(
        'لبن',
        quantity: 1,
        threshold: 2,
        expiry: DateTime.utc(2026, 9, 21),
      );

      final shortages = shortagesIn(<InventoryItem>[both], today: today);

      expect(shortages, hasLength(1));
      expect(shortages.single.reason, ShortageReason.runningLow);
    });

    test('is most urgent first, then by name', () {
      final shortages = shortagesIn(<InventoryItem>[
        item('شاي', quantity: 1, threshold: 2),
        item('أرز', quantity: 0),
        item('عسل', expiry: DateTime.utc(2026, 9, 10)),
        item('بن', quantity: 1, threshold: 2),
        item('سكر', quantity: 20),
      ], today: today);

      expect(shortages.map((s) => s.item.itemName), <String>[
        'أرز',
        'عسل',
        'بن',
        'شاي',
      ]);
      // Stable between runs: a list that reshuffles on every rebuild is one
      // nobody can scan.
      expect(
        shortagesIn(<InventoryItem>[
          item('شاي', quantity: 1, threshold: 2),
          item('بن', quantity: 1, threshold: 2),
        ], today: today).map((s) => s.item.itemName),
        <String>['بن', 'شاي'],
      );
    });

    test('an empty pantry has no shortages', () {
      expect(shortagesIn(const <InventoryItem>[], today: today), isEmpty);
    });
  });

  group('how urgent the shopping line is', () {
    test('only nothing-usable-left earns high', () {
      // If everything a pantry scan turned up were urgent, the ranking would
      // say nothing at all.
      ShoppingPriority priorityFor(ShortageReason reason) =>
          Shortage(item: item('x'), reason: reason).priority;

      expect(priorityFor(ShortageReason.outOfStock), ShoppingPriority.high);
      expect(priorityFor(ShortageReason.expired), ShoppingPriority.high);
      expect(priorityFor(ShortageReason.runningLow), ShoppingPriority.medium);
      expect(priorityFor(ShortageReason.expiringSoon), ShoppingPriority.medium);
    });
  });
}
