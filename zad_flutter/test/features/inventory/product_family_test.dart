// A staple under several brands is one stock — the owner's eight bottles of
// water in five rows read as five shortages (2026-09-30).

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/shared/inventory/domain/inventory_item.dart';
import 'package:zad/shared/inventory/domain/product_family.dart';
import 'package:zad/shared/inventory/domain/receipt_intake.dart';
import 'package:zad/shared/inventory/domain/shopping_item.dart';
import 'package:zad/shared/inventory/domain/shortage.dart';

InventoryItem _row(String id, String name, int qty, {int? threshold}) =>
    InventoryItem(
      id: id,
      userId: 'u',
      itemName: name,
      quantity: qty,
      unit: 'قطعة',
      lowStockThreshold: threshold,
    );

final DateTime _today = DateTime.utc(2026, 9, 30);

void main() {
  // The owner's pantry, as the screenshot shows it.
  final water = <InventoryItem>[
    _row('1', 'ماء إيلان', 1),
    _row('2', 'ماء بونا', 1),
    _row('3', 'مياه إيلانو', 0),
    _row('4', 'مياه داساني', 1),
    _row('5', 'مياه نستله', 5),
  ];

  test('brands of the same staple share a family; others do not', () {
    expect(sameProductFamily('ماء إيلان', 'مياه نستله'), isTrue);
    expect(sameProductFamily('الأرز البسمتي', 'رز مصري'), isTrue);
    expect(sameProductFamily('زيت زيتون', 'زيت عباد الشمس'), isFalse);
    expect(sameProductFamily('جبنة رومي', 'جبنة بيضاء'), isFalse);
    expect(productFamilyOf('شيبسي'), isNull);
  });

  test('five water rows are one group with the house total', () {
    final groups = groupPantry(water);
    expect(groups, hasLength(1));
    expect(groups.single.isFamily, isTrue);
    expect(groups.single.total, 8);
    expect(groups.single.isLow, isFalse);
    // Largest row first, and it names the staple.
    expect(groups.single.members.first.itemName, 'مياه نستله');
    expect(groups.single.name, 'مياه');
  });

  test('eight bottles across five brands are not a shortage', () {
    expect(shortagesIn(water, today: _today), isEmpty);
  });

  test('a family low across every brand is one shortage, under its name', () {
    final low = <InventoryItem>[
      _row('1', 'ماء إيلان', 1),
      _row('2', 'مياه نستله', 1),
    ];
    final shortages = shortagesIn(low, today: _today);
    expect(shortages, hasLength(1));
    expect(shortages.single.item.itemName, 'مياه');
    expect(shortages.single.item.quantity, 2);
    expect(shortages.single.reason, ShortageReason.runningLow);
  });

  test('out of every brand is out of stock', () {
    final out = <InventoryItem>[
      _row('1', 'ماء إيلان', 0),
      _row('2', 'مياه نستله', 0),
    ];
    expect(
      shortagesIn(out, today: _today).single.reason,
      ShortageReason.outOfStock,
    );
  });

  test('rows that are not staples keep their own rules', () {
    final rows = <InventoryItem>[
      _row('1', 'شيبسي', 0),
      _row('2', 'زيت زيتون', 5),
    ];
    final shortages = shortagesIn(rows, today: _today);
    expect(shortages.single.item.itemName, 'شيبسي');
  });

  test('«مياه» on the list is bought by a water brand on a receipt', () {
    final plan = planIntake(
      lines: const <IntakeLine>[IntakeLine(name: 'ماء إيلان', quantity: 6)],
      pantry: water,
      shopping: const <ShoppingItem>[
        ShoppingItem(id: 's1', userId: 'u', itemName: 'مياه'),
      ],
    );
    expect(plan.bought.map((s) => s.id), <String>['s1']);
  });
}
