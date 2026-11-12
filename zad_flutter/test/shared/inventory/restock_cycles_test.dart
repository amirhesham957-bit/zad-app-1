import 'package:flutter_test/flutter_test.dart';
import 'package:zad/shared/inventory/data/restock_cycles.dart';
import 'package:zad/shared/inventory/domain/inventory_item.dart';
import 'package:zad/shared/inventory/domain/shortage.dart';

final DateTime _today = DateTime.utc(2026, 11, 6);

InventoryItem _row(
  String name,
  double qty, {
  DateTime? created,
  double? threshold,
}) => InventoryItem(
  id: 'i-$name',
  userId: 'u',
  itemName: name,
  quantity: qty,
  lowStockThreshold: threshold,
  createdAt: created ?? DateTime.utc(2026, 11, 5, 11, 46),
);

void main() {
  test('owner 6/11: ghee bought yesterday at 1 is not short tonight', () {
    // The old flat threshold of 2, set by hand: it alone said «short» the day
    // after; the purchase rhythm is what keeps it off.
    final ghee = _row('سمن شيراتون', 1, threshold: 2);
    expect(shortagesIn(<InventoryItem>[ghee], today: _today), hasLength(1));
    expect(
      shortagesIn(
        <InventoryItem>[ghee],
        today: _today,
        notYetDue: notYetDueFrom(<Object?>[
          <String, dynamic>{'item': 'سمن شيراتون', 'due': false},
        ]),
      ),
      isEmpty,
    );
  });

  test('zero is still out of stock, whatever the cycle says', () {
    final shortages = shortagesIn(
      <InventoryItem>[_row('زيت', 0)],
      today: _today,
      notYetDue: <String>{'زيت'},
    );
    expect(shortages.single.reason, ShortageReason.outOfStock);
  });

  test('a known rate of use still wins over the cycle', () {
    final shortages = shortagesIn(
      <InventoryItem>[_row('مياه', 2)],
      today: _today,
      rates: <String, ({double perDay, bool known})>{
        'مياه': (perDay: 2, known: true),
      },
      notYetDue: <String>{'مياه'},
    );
    expect(shortages.single.reason, ShortageReason.runningLow);
  });

  test('only items the server says are not due are read', () {
    expect(
      notYetDueFrom(<Object?>[
        <String, dynamic>{'item': 'عيش', 'due': true},
        <String, dynamic>{'item': 'Sugar ', 'due': false},
        <String, dynamic>{'due': false},
        'junk',
      ]),
      <String>{'sugar'},
    );
    expect(notYetDueFrom(null), isEmpty);
  });
}
