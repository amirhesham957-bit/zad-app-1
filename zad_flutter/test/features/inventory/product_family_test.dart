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

  test('a water brand alone, or with its size, is water', () {
    for (final name in <String>[
      'إيلان',
      'إيلانو',
      'داساني',
      'بوفانا',
      'نستله',
      'صافي 1.5 لتر',
      'إزازة ماء',
      'ماء صافى',
    ]) {
      expect(productFamilyOf(name), 'مياه', reason: name);
    }
    expect(productFamilyOf('نستله نيدو'), isNull);
    expect(productFamilyOf('صافي لبن'), isNull);
  });

  test("the owner's ten water rows are one stock of 13", () {
    final rows = <InventoryItem>[
      _row('1', 'إزازة ماء', 1),
      _row('2', 'صافي 1.5 لتر', 2),
      _row('3', 'ماء صافى', 1),
      _row('4', 'كرتونة ماية', 1),
      _row('5', 'عبوة مياه', 1),
      _row('6', 'إيلان', 2),
      _row('7', 'إيلانو', 1),
      _row('8', 'بوفانا', 1),
      _row('9', 'داساني', 2),
      _row('10', 'نستله', 1),
    ];
    final groups = groupPantry(rows);
    expect(groups, hasLength(1));
    expect(groups.single.total, 13);
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

  group('the shopping list reads by need (owner, 2026-10-01)', () {
    ShoppingItem line(String id, String name) =>
        ShoppingItem(id: id, userId: 'u', itemName: name);

    // The owner's outstanding list, as the database held it.
    final owner = <ShoppingItem>[
      line('1', 'مرتديلا لحم مقطعة'),
      line('2', 'مياه نستله بيور لايف'),
      line('3', 'مياه داساني جالون'),
      line('4', 'ماء إيلان'),
      line('5', 'عبوة مياه'),
      line('6', 'علبة حفظ طعام'),
      line('7', 'كرتونة ماية'),
      line('8', 'بيض'),
    ];

    test('packing words and ماية do not hide the staple', () {
      expect(productFamilyOf('عبوة مياه'), 'مياه');
      expect(productFamilyOf('كرتونة ماية'), 'مياه');
      expect(productFamilyOf('كيس سكر'), 'سكر');
      expect(productFamilyOf('كيلو رز مصري'), 'رز');
      // A box is not a staple, and a word alone is not skipped away.
      expect(productFamilyOf('علبة حفظ طعام'), isNull);
      expect(productFamilyOf('علبة'), isNull);
    });

    test("a staple's lines are one group, where its first line was", () {
      final groups = groupShoppingLines(owner);
      expect(groups.map((g) => g.name).toList(), <String>[
        'مرتديلا لحم مقطعة',
        'مياه',
        'علبة حفظ طعام',
        'بيض',
      ]);
      final water = groups[1];
      expect(water.isFamily, isTrue);
      expect(water.lines.map((l) => l.id), <String>['2', '3', '4', '5', '7']);
      expect(water.allPurchased, isFalse);
    });

    test('a brand is named without its staple', () {
      expect(brandWithinFamily('ماء إيلان'), 'إيلان');
      expect(brandWithinFamily('مياه داساني جالون'), 'داساني');
      expect(brandWithinFamily('عبوة مياه'), 'عبوة مياه');
      expect(brandWithinFamily('مرتديلا لحم'), 'مرتديلا لحم');
    });

    test('the house stock of a line: the staple across brands', () {
      final stock = pantryStockFor('كرتونة ماية', water);
      expect(stock?.total, 8);
      expect(stock?.isLow, isFalse);
      expect(pantryStockFor('مرتديلا', water), isNull);
      expect(
        pantryStockFor('مياه', <InventoryItem>[_row('1', 'مياه صافي', 0)]),
        isNull,
      );
    });
  });

  test(
    'brand-first water joins the family; other staples need to come first',
    () {
      // The owner's pantry, 2026-10-01: «صافي مياه معدنية 1.5 لتر» beside nine
      // other water rows.
      expect(productFamilyOf('صافي مياه معدنية 1.5 لتر'), 'مياه');
      expect(productFamilyOf('نستله مياه'), 'مياه');
      expect(productFamilyOf('بسكويت شاي'), isNull);
      expect(productFamilyOf('عصير سكر'), isNull);
    },
  );
}
