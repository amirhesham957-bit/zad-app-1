// اسم واحد لكل فئة (ZAD_LIVING_BRAIN.md §١١): التطبيق والماسح والسيرفر
// نفس القاموس، والتخمين من العنوان.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/shared/scan/domain/scanned_receipt.dart';
import 'package:zad/shared/transactions/domain/expense_categories.dart';

void main() {
  test('every scanner category is a picker category', () {
    for (final c in kStandardCategories.where((c) => c != 'تحويلات')) {
      expect(kExpenseCategories, contains(c), reason: c);
    }
  });

  test('every picker category is a name the server keeps as it is', () {
    // zad_canonical_category's targets, read from the migration itself.
    final sql = File('../supabase/migrations/20261005233809_audit_gaps.sql')
        .readAsStringSync();
    final targets = RegExp("then '([^']+)'")
        .allMatches(sql)
        .map((m) => m.group(1)!)
        .toSet();
    for (final c in kExpenseCategories) {
      expect(targets, contains(c), reason: c);
    }
  });

  test('the title says the category', () {
    expect(suggestExpenseCategory('سوبرماركت كارفور'), 'البقالة');
    expect(suggestExpenseCategory('أوبر للشغل'), 'المواصلات');
    expect(suggestExpenseCategory('بنزين'), 'الوقود');
    expect(suggestExpenseCategory('فاتورة الكهربا'), 'الفواتير');
    expect(suggestExpenseCategory('صيدلية العزبي'), 'الرعاية الصحية');
    expect(suggestExpenseCategory('قهوة ستاربكس'), 'المطاعم');
    expect(suggestExpenseCategory('اشتراك نتفليكس'), 'الاشتراكات');
    expect(suggestExpenseCategory('قسط فاليو'), 'الأقساط');
  });

  test('a word inside another word is not a hint; nothing said is null', () {
    expect(suggestExpenseCategory('مرزوق'), isNull);
    expect(suggestExpenseCategory('حلاقة'), isNull);
    expect(suggestExpenseCategory('   '), isNull);
  });
}
