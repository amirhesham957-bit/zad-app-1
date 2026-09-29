import 'package:flutter_test/flutter_test.dart';
import 'package:zad/features/support/domain/support_faq.dart';

void main() {
  test('the questions the owner hit have answers without the model', () {
    expect(
      faqAnswer('التطبيق مش شايف إشعارات البنك والمفتاح رمادي'),
      contains('السماح بالإعدادات المقيدة'),
    );
    expect(faqAnswer('ازاي ابعت مصروف لابني'), contains('حوّل مصروف'));
    expect(faqAnswer('الفاتورة اتسجلت غلط'), contains('تاريخ الفاتورة'));
    expect(faqAnswer('عايز أفكر نفسي بميعاد الدكتور'), contains('مواعيدي'));
  });

  test('nothing is invented for a question it does not know', () {
    expect(faqAnswer('ايه رأيك في الطقس النهارده'), isNull);
    expect(faqAnswer('   '), isNull);
  });
}
