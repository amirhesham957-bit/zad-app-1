// A pharmacy receipt restocks the pharmacy. Pinned here: which printed name
// is which tracked medicine (stricter than the pantry — a strength or a
// letter makes a different medicine), how many tablets a box holds when the
// name says so, that a box is never added to a tablet count as one tablet,
// and what the plan does with duplicates and the shopping list.

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/features/inventory/domain/shopping_item.dart';
import 'package:zad/features/pharmacy/domain/medicine.dart';
import 'package:zad/features/pharmacy/domain/pharmacy_intake.dart';

Medicine _med(String id, String name, {String unit = 'قرص', int left = 3}) =>
    Medicine(
      id: id,
      userId: 'u',
      name: name,
      unit: unit,
      remainingQuantity: left,
    );

PharmacyLine _line(String name, {int packs = 1, String? unit}) =>
    PharmacyLine(name: name, packs: packs, unit: unit);

ShoppingItem _list(String id, String name) =>
    ShoppingItem(id: id, userId: 'u', itemName: name);

void main() {
  group('which medicine a printed name is', () {
    test('the same name, however it is spelt', () {
      expect(medicineNamesMatch('كونكور', 'كونكور 5 مجم 30 قرص'), isTrue);
      expect(medicineNamesMatch('أوجمنتين', 'اوجمنتين 1 جم'), isTrue);
      expect(medicineNamesMatch('Concor', 'CONCOR 5MG 30 TABS'), isTrue);
    });

    test('a different letter is a different medicine', () {
      // The pantry rule drops words of two letters, and would call these one.
      expect(medicineNamesMatch('فيتامين د', 'فيتامين سي'), isFalse);
      expect(medicineNamesMatch('فيتامين د', 'فيتامين د3 1000'), isTrue);
    });

    test('a different strength is a different medicine', () {
      expect(medicineNamesMatch('كونكور 10', 'كونكور 5 مجم 30 قرص'), isFalse);
      expect(medicineNamesMatch('كونكور 5', 'كونكور 5 مجم 30 قرص'), isTrue);
    });

    test('a name with no words names nothing', () {
      expect(medicineNamesMatch('500 mg', '500 mg'), isFalse);
    });
  });

  group('what a box holds', () {
    test('read off the printed name', () {
      expect(packContents('كونكور 5 مجم 30 قرص'), (count: 30, unit: 'قرص'));
      expect(packContents('Nexium 40mg 14 caps'), (count: 14, unit: 'كبسولة'));
      expect(packContents('شراب كونجستال ١٢٠ مل'), (count: 120, unit: 'مل'));
      expect(packContents('فوار 10 أكياس'), (count: 10, unit: 'كيس'));
    });

    test('a strength is never a count', () {
      expect(packContents('بانادول 500 مجم'), isNull);
      expect(packContents('Augmentin 1g'), isNull);
      // "مل" at the start of a longer word is not millilitres.
      expect(packContents('دواء 5 ملغ'), isNull);
    });
  });

  group('what a line proposes', () {
    final concor = _med('m1', 'كونكور 5');

    test('a box of thirty goes into a tablet count as thirty', () {
      final p = proposeRestock(
        _line('كونكور 5 مجم 30 قرص', packs: 2),
        <Medicine>[concor],
      );
      expect((p.medicine?.id, p.count, p.unit), ('m1', 60, 'قرص'));
    });

    test('a box of unknown contents is left for the customer to count', () {
      // Kotlin adds the box count: two boxes become two tablets, and the
      // "running out" reminder stays quiet while the shelf fills.
      final p = proposeRestock(
        _line('كونكور 5', packs: 2, unit: 'علبة'),
        <Medicine>[concor],
      );
      expect((p.medicine?.id, p.needsCount, p.unit), ('m1', true, 'قرص'));

      expect(p.withCount(56).count, 56);
    });

    test("a line counted in the medicine's own unit is taken as is", () {
      final p = proposeRestock(
        _line('كونكور 5', packs: 20, unit: 'أقراص'),
        <Medicine>[concor],
      );
      expect(p.count, 20);
    });

    test("a medicine counted in tubes takes the receipt's count", () {
      final cream = _med('m2', 'فيوسيدين كريم', unit: 'كريم', left: 0);
      final p = proposeRestock(
        _line('فيوسيدين كريم', packs: 2),
        <Medicine>[cream],
      );
      expect((p.count, p.unit), (2, 'كريم'));
    });

    test("a new medicine is started in the box's contents when printed", () {
      final p = proposeRestock(_line('أوجمنتين 1 جم 14 قرص'), <Medicine>[]);
      expect((p.isNew, p.count, p.unit), (true, 14, 'قرص'));
    });

    test('and in boxes when not', () {
      final p = proposeRestock(_line('بانادول', packs: 2), <Medicine>[]);
      expect((p.isNew, p.count, p.unit), (true, 2, kPackUnit));
    });

    test('the most specific tracked name wins', () {
      final plain = _med('m3', 'بانادول');
      final extra = _med('m4', 'بانادول اكسترا');
      final p = proposeRestock(
        _line('بانادول اكسترا 24 قرص'),
        <Medicine>[plain, extra],
      );
      expect(p.medicine?.id, 'm4');
    });
  });

  group('the plan', () {
    final concor = _med('m1', 'كونكور 5');

    test('two lines for one medicine are one restock', () {
      final plan = planPharmacyIntake(
        proposals: <RestockProposal>[
          proposeRestock(_line('كونكور 5 مجم 30 قرص'), <Medicine>[concor]),
          proposeRestock(_line('كونكور 5 30 قرص'), <Medicine>[concor]),
        ],
        shopping: const <ShoppingItem>[],
      );
      expect(plan.restocks.single.add, 60);
    });

    test('two lines for one new medicine are one medicine', () {
      final plan = planPharmacyIntake(
        proposals: <RestockProposal>[
          proposeRestock(_line('أوجمنتين 14 قرص'), <Medicine>[]),
          proposeRestock(_line('اوجمنتين 14 قرص'), <Medicine>[]),
        ],
        shopping: const <ShoppingItem>[],
      );
      expect(plan.additions.single.count, 28);
    });

    test('an uncounted line is left out, and said so', () {
      final plan = planPharmacyIntake(
        proposals: <RestockProposal>[
          proposeRestock(_line('كونكور 5', unit: 'علبة'), <Medicine>[concor]),
        ],
        shopping: const <ShoppingItem>[],
      );
      expect((plan.restocks.length, plan.uncounted), (0, 1));
    });

    test('the list is ticked for what was bought, counted or not', () {
      // The dose function puts a medicine on the list by its tracked name.
      final plan = planPharmacyIntake(
        proposals: <RestockProposal>[
          proposeRestock(_line('كونكور 5', unit: 'علبة'), <Medicine>[concor]),
        ],
        shopping: <ShoppingItem>[
          _list('s1', 'كونكور 5'),
          _list('s2', 'فيتامين سي'),
        ],
      );
      expect(plan.bought.map((s) => s.id), <String>['s1']);
    });

    test("a line category is kept only when it is a medicine's", () {
      expect(medicineCategory('مضاد حيوي'), 'مضاد حيوي');
      expect(medicineCategory('ألبان'), isNull);
      expect(medicineCategory(null), isNull);
    });
  });
}
