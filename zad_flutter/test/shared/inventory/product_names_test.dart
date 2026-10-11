// The home's «same product» answers in the app: the server's key, its chain
// rule and its order (zad_product_pairs, 2026-10-11).

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/shared/inventory/domain/product_names.dart';

Map<String, dynamic> _pair(
  String a,
  String b,
  String verdict, {
  String? keep,
  String at = '2026-10-11T08:00:00Z',
}) {
  final keys = <String>[productKey(a), productKey(b)]..sort();
  return <String, dynamic>{
    'a_key': keys[0],
    'b_key': keys[1],
    'verdict': verdict,
    'canonical_name': keep,
    'created_at': at,
  };
}

void main() {
  test('the key is zad_inventory_name_key', () {
    expect(productKey('  الحليب '), 'حليب');
    expect(productKey('إزازة ماء'), 'ازازه ماء');
    expect(productKey('ال'), 'ال', reason: 'a bare article is kept, as in SQL');
  });

  test('a «same» answer names both; «different» names nothing', () {
    final names = ProductNames.fromRows(<Map<String, dynamic>>[
      _pair('لبن', 'حليب', 'same', keep: 'لبن'),
      _pair('لبن', 'لبن رايب', 'different'),
    ]);
    expect(names.canonical('الحليب'), 'لبن');
    expect(names.canonical('لبن'), 'لبن');
    expect(names.canonical('لبن رايب'), 'لبن رايب');
    expect(names.canonical('طماطم'), 'طماطم', reason: 'untouched as typed');
  });

  test('a chain is followed, and the newest answer for a name wins', () {
    final names = ProductNames.fromRows(<Map<String, dynamic>>[
      _pair('ماء', 'مياه', 'same', keep: 'مياه', at: '2026-10-10T00:00:00Z'),
      _pair('مياه', 'مياه معدنية', 'same', keep: 'مياه معدنية'),
      _pair('رز', 'أرز', 'same', keep: 'أرز', at: '2026-10-01T00:00:00Z'),
      _pair('رز', 'أرز', 'same', keep: 'رز', at: '2026-10-09T00:00:00Z'),
    ]);
    expect(names.canonical('ماء'), 'مياه معدنية');
    expect(names.canonical('أرز'), 'رز');
  });

  test('no answers: every name is itself', () {
    expect(ProductNames.none.canonical('حليب'), 'حليب');
  });
}
