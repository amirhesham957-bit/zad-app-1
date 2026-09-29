import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/features/scan/domain/scanned_receipt.dart';

void main() {
  tz_data.initializeTimeZones();
  final cairo = tz.getLocation('Africa/Cairo');
  // 23:30 in Cairo on 28 September.
  final now = DateTime.utc(2026, 9, 28, 20, 30);

  test('the printed date is read, and only a real one', () {
    ScannedReceipt read(Object? date) => ScannedReceipt.fromJson(
      <String, dynamic>{'total': 10, 'purchaseDate': date},
    );
    expect(read('2026-08-12').purchasedOn, DateTime.utc(2026, 8, 12));
    expect(read('2026-02-30').purchasedOn, isNull);
    expect(read('12/08/2026').purchasedOn, isNull);
    expect(read(null).purchasedOn, isNull);
  });

  test('a receipt from last month is recorded in last month', () {
    final at = receiptSpentAt(DateTime.utc(2026, 8, 12), now, cairo);
    final local = tz.TZDateTime.from(at, cairo);
    expect((local.year, local.month, local.day), (2026, 8, 12));
  });

  test("the last day of a month stays in that month in the account's zone", () {
    final at = receiptSpentAt(DateTime.utc(2026, 8, 31), now, cairo);
    final local = tz.TZDateTime.from(at, cairo);
    expect((local.month, local.day), (8, 31));
  });

  test('no date, today, or a future date is the moment of the scan', () {
    expect(receiptSpentAt(null, now, cairo), now);
    expect(receiptSpentAt(DateTime.utc(2026, 9, 28), now, cairo), now);
    expect(receiptSpentAt(DateTime.utc(2026, 10, 3), now, cairo), now);
  });

  test('a correction keeps the date', () {
    final r = ScannedReceipt.fromJson(<String, dynamic>{
      'total': 10,
      'purchaseDate': '2026-08-12',
    });
    expect(r.copyWith(total: 20).purchasedOn, DateTime.utc(2026, 8, 12));
  });
}
