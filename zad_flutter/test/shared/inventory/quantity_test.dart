// ZAD_PLAN ٣.٨: half a kilo of rice is 0.5, not 1 — and not 0.
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/shared/inventory/domain/inventory_item.dart';
import 'package:zad/shared/inventory/domain/quantity.dart';

void main() {
  test('reads what people type', () {
    expect(parseQuantity('0.5'), 0.5);
    expect(parseQuantity('٠٫٥'), 0.5);
    expect(parseQuantity('1,5'), 1.5);
    expect(parseQuantity('نص'), 0.5);
    expect(parseQuantity('ربع'), 0.25);
    expect(parseQuantity('1 ونص'), 1.5);
    expect(parseQuantity('٢ و ربع'), 2.25);
    expect(parseQuantity('10'), 10);
    expect(parseQuantity('0.3333'), 0.333);
  });

  test('nothing readable is nothing', () {
    for (final raw in <String>['', '  ', 'كتير', '0', '-1', 'ونص بس']) {
      expect(parseQuantity(raw), isNull, reason: raw);
    }
  });

  test('shows halves as halves, whole counts as whole', () {
    expect(formatQuantity(2), '2');
    expect(formatQuantity(2.0), '2');
    expect(formatQuantity(0.5), '½');
    expect(formatQuantity(1.5), '1½');
    expect(formatQuantity(0.25), '¼');
    expect(formatQuantity(0.3), '0.3');
    expect(formatQuantity(2.125), '2.125');
  });

  test('a server row of half a kilo is half a kilo, not zero', () {
    // The app used to read the column with toInt(): 0.5 became 0, «خلص».
    final item = InventoryItem.fromJson(<String, dynamic>{
      'id': 'r',
      'item_name': 'رز',
      'quantity': 0.5,
      'low_stock_threshold': 0.25,
      'unit': 'كجم',
    });
    expect(item.quantity, 0.5);
    expect(item.lowStockThreshold, 0.25);
    expect(item.isLowStock, isTrue, reason: 'threshold is at least one');
  });
}
