// ZAD_PLAN ١٠.١ slice 3: «منخفض» follows how much was bought and in what.
//
// On 2026-11-12, 29 of the live project's 40 pantry rows read «منخفض»: every
// row carried the column's default threshold of 2, and most things are bought
// one at a time. The cases here are the same as the SQL test
// (`supabase/sql/tests/low_stock_threshold_test.sql`): the phone and the
// server's trigger must give a row the same level.

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/shared/inventory/domain/inventory_item.dart';

InventoryItem _item(double qty, {String? unit, double? threshold}) =>
    InventoryItem(
      id: 'i',
      userId: 'u',
      itemName: 'x',
      quantity: qty,
      unit: unit,
      lowStockThreshold: threshold,
    );

void main() {
  test('the same levels as the server', () {
    expect(defaultLowStockThreshold(1, 'علبة'), 0.5);
    expect(defaultLowStockThreshold(30, 'حبة'), 7.5);
    expect(defaultLowStockThreshold(4, null), 1);
    expect(defaultLowStockThreshold(1, 'كيلو'), 0.25);
    expect(defaultLowStockThreshold(10, ' KG '), 2.5);
    expect(defaultLowStockThreshold(500, 'جرام'), 125);
    expect(defaultLowStockThreshold(200, 'مل'), 100);
    expect(defaultLowStockThreshold(-3, 'علبة'), 0.5);
  });

  test('one box just bought is stocked, not low and not almost gone', () {
    final box = _item(
      1,
      unit: 'علبة',
      threshold: defaultLowStockThreshold(1, 'علبة'),
    );
    expect(box.isLowStock, isFalse);
    expect(box.isGettingLow, isFalse);
  });

  test('a row with no threshold yet reads by the same rule', () {
    expect(_item(1, unit: 'زجاجة').isLowStock, isFalse);
    expect(_item(0, unit: 'زجاجة').isLowStock, isTrue);
    expect(_item(0.5, unit: 'زجاجة').isLowStock, isTrue);
  });

  test('thirty eggs run low at seven, and are getting low under fifteen', () {
    final eggs = _item(30, unit: 'حبة', threshold: 7.5);
    expect(eggs.isLowStock, isFalse);
    expect(eggs.copyWith(quantity: 12).isGettingLow, isTrue);
    expect(eggs.copyWith(quantity: 7).isLowStock, isTrue);
  });

  test("the customer's own threshold still wins", () {
    final chosen = _item(1, unit: 'كرتونة', threshold: 1);
    expect(chosen.isLowStock, isTrue);
    // Zero would be a warning that never fires: it counts as none.
    expect(_item(1, unit: 'علبة', threshold: 0).effectiveThreshold, 0.5);
  });
}
