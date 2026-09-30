// A category the customer corrected for a merchant is the one the next
// statement import gives it — Kotlin's MerchantCategoryOverrides.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/features/statement/domain/statement_import.dart';
import 'package:zad/shared/transactions/data/merchant_categories.dart';

void main() {
  const table = (
    headers: <String>['date', 'title', 'amount'],
    rows: <List<String>>[
      <String>['2026-09-01', 'Talabat', '-250'],
      <String>['2026-09-02', 'Unknown Shop', '-80'],
    ],
  );
  const ColumnMapping mapping = (
    date: 0,
    title: 1,
    amount: 2,
    category: null,
    invertSign: false,
  );

  test("the customer's category wins over the keyword guess", () {
    final rows = buildPreview(
      table,
      mapping,
      customCategory: (t) => t == 'Talabat' ? 'البقالة' : null,
    );
    expect(rows[0].category, 'البقالة');
    expect(rows[1].category, classifyStatementTitle('Unknown Shop'));
  });

  test('without corrections, the guess stands', () {
    final rows = buildPreview(table, mapping);
    expect(rows[0].category, classifyStatementTitle('Talabat'));
  });

  test('corrections are kept per merchant, case and spaces aside', () async {
    final dir = await Directory.systemTemp.createTemp('zad_merchant');
    Hive.init(dir.path);
    final box = await Hive.openBox<String>('m');
    addTearDown(() async {
      await Hive.deleteFromDisk();
      await dir.delete(recursive: true);
    });
    final store = MerchantCategories(box);
    await store.remember(' Talabat ', 'المطاعم');
    await store.remember('', 'المطاعم');
    await store.remember('Carrefour', '  ');
    expect(store.categoryFor('talabat'), 'المطاعم');
    expect(store.categoryFor('Carrefour'), isNull);
    expect(store.categoryFor(null), isNull);
  });
}
