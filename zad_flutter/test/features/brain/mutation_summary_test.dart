import 'package:flutter_test/flutter_test.dart';
import 'package:zad/features/brain/domain/mutation_summary.dart';

// Cairo in October: UTC+3.
DateTime _cairo(DateTime utc) => utc.add(const Duration(hours: 3));

MutationSummary _sum(Object? old, Object? next) =>
    summarizeMutation(old, next, toLocal: _cairo);

void main() {
  // The rows of the owner's screenshot, 2026-10-13.
  final pharmacyBefore = <String, dynamic>{
    'id': '9cb326db-ffd1-43d8-9e9f-4846bc1c9dc8',
    'name': 'LIMITLESS ALLZYME MAX 20 TAB 3',
    'unit': 'قرص',
    'price': 0,
    'dosage': null,
    'user_id': '20a420a9-5fab-42d5-910a-47fa9b37cb1d',
    'created_at': '2026-10-09T17:11:14.974729+00:00',
    'remaining_quantity': 14,
    'has_invalid_dose_time': false,
  };

  test('an update shows the name and only the field that changed', () {
    final after = <String, dynamic>{
      ...pharmacyBefore,
      'remaining_quantity': 13,
      'created_at': '2026-10-09T17:11:15+00:00',
    };
    final s = _sum(pharmacyBefore, after);
    expect(s.subject, 'LIMITLESS ALLZYME MAX 20 TAB 3');
    expect(s.change, 'الكمية المتبقية: 14 ← 13');
  });

  test('no JSON, id or user id ever reaches the line', () {
    final s = _sum(pharmacyBefore, <String, dynamic>{
      ...pharmacyBefore,
      'dosage': 'مرتين في اليوم',
    });
    final line = '${s.subject} ${s.change}';
    expect(line, isNot(contains('{')));
    expect(line, isNot(contains('9cb326db')));
    expect(line, isNot(contains('20a420a9')));
    expect(s.change, 'الجرعة: — ← مرتين في اليوم');
  });

  test('an update that touched only plumbing still says something', () {
    final s = _sum(pharmacyBefore, <String, dynamic>{
      ...pharmacyBefore,
      'has_invalid_dose_time': true,
    });
    expect(s.change, 'اتعدّل');
  });

  test('a new appointment reads its time on the account clock', () {
    final s = _sum(null, <String, dynamic>{
      'title': 'صحوة الصبح',
      'starts_at': '2026-10-12T03:30:00.000Z',
    });
    expect(s.subject, 'صحوة الصبح');
    expect(s.change, 'الميعاد: 12/10 06:30');
  });

  test('a new medicine lists its dose times', () {
    final s = _sum(null, <String, dynamic>{
      'name': 'Suprax 400 Mg 5 Caps',
      'dose_times': <String>['21:00'],
    });
    expect(s.subject, 'Suprax 400 Mg 5 Caps');
    expect(s.change, 'مواعيد الجرعات: 21:00');
  });

  test('a deletion names what went', () {
    final s = _sum(pharmacyBefore, null);
    expect(s.subject, 'LIMITLESS ALLZYME MAX 20 TAB 3');
    expect(s.change, 'اتشال');
  });

  test('plain values keep the old ← new form', () {
    expect(_sum(16, 30).change, '16 ← 30');
    expect(_sum(null, 30).change, '30');
    expect(_sum(2500.5, 3000).change, '2500.5 ← 3000');
  });

  test('a quantity against a {item, qty} row reads as two numbers', () {
    final s = _sum(5, <String, dynamic>{'item': 'رز', 'qty': 7});
    expect(s.subject, 'رز');
    expect(s.change, '5 ← 7');
  });

  test('statuses and flags are words', () {
    expect(
      _sum(
        <String, dynamic>{'title': 'تحدي', 'status': 'active'},
        <String, dynamic>{'title': 'تحدي', 'status': 'abandoned'},
      ).change,
      'الحالة: شغّال ← اتوقف',
    );
    expect(
      _sum(
        <String, dynamic>{'active': true},
        <String, dynamic>{'is_active': false},
      ).change,
      'شغّال: — ← لأ',
    );
  });

  test('more than three changes are counted, not listed', () {
    final s = _sum(
      <String, dynamic>{'amount': 1, 'qty': 1, 'price': 1, 'unit': 'a'},
      <String, dynamic>{'amount': 2, 'qty': 2, 'price': 2, 'unit': 'b'},
    );
    expect(s.change, endsWith('و1 كمان'));
  });
}
