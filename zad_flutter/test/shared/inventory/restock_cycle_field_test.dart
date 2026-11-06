import 'package:flutter_test/flutter_test.dart';
import 'package:zad/shared/inventory/domain/inventory_item.dart';

InventoryItem _oil({int? cycle}) => InventoryItem.fromJson(<String, dynamic>{
  'id': 'i1',
  'user_id': 'u1',
  'item_name': 'زيت',
  'quantity': 1,
  'restock_cycle_days': cycle,
});

void main() {
  test('the customer’s cycle is read and sent', () {
    final item = _oil(cycle: 14);
    expect(item.restockCycleDays, 14);
    expect(item.toUpsertJson()['restock_cycle_days'], 14);
  });

  test('nothing set is left out of the row, so it never wipes the server', () {
    final row = _oil().copyWith(quantity: 3).toUpsertJson();
    expect(row.containsKey('restock_cycle_days'), isFalse);
  });

  test('removing it sends an explicit null, even after a second edit', () {
    final cleared = _oil(cycle: 14).withoutRestockCycle();
    expect(cleared.restockCycleDays, isNull);
    expect(cleared.toUpsertJson().containsKey('restock_cycle_days'), isTrue);
    expect(cleared.toUpsertJson()['restock_cycle_days'], isNull);

    // The queued copy goes through the cache before a second edit.
    final cached = InventoryItem.fromJson(
      cleared.markPending(pending: true).toCacheJson(),
    );
    final edited = cached.copyWith(quantity: 2);
    expect(edited.toUpsertJson().containsKey('restock_cycle_days'), isTrue);
  });

  test('out-of-range values from the wire are ignored', () {
    expect(_oil(cycle: 0).restockCycleDays, isNull);
    expect(_oil(cycle: 400).restockCycleDays, isNull);
  });
}
