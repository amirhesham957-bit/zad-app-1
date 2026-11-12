// The expiry field's arithmetic and the shelf-life guess (2026-11-12: 0 of
// 40 pantry rows had an expiry date). The guess is pinned per kind, the
// order that makes «فراخ مجمدة» a freezer item and «صابون» no guess, and the
// day it counts from being the account's, not the device's.

import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:zad/shared/inventory/domain/shelf_life.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';

void main() {
  setUpAll(tz_data.initializeTimeZones);

  group('guessShelfLifeDays', () {
    int? guess(String name, [String? category]) =>
        guessShelfLifeDays(itemName: name, category: category);

    test('by category, with a name that says nothing', () {
      expect(guess('حاجة', 'الألبان'), 7);
      expect(guess('حاجة', 'ألبان'), 7, reason: "the scanner's spelling");
      expect(guess('حاجة', 'الخضار'), 5);
      expect(guess('حاجة', 'خضار'), 5);
      expect(guess('حاجة', 'الفواكه'), 7);
      expect(guess('حاجة', 'اللحوم'), 3);
      expect(guess('حاجة', 'مجمدات'), 90);
      expect(guess('حاجة', 'مخبوزات'), 4);
      expect(guess('حاجة', 'البقالة'), 180);
      expect(guess('حاجة', 'معلبات'), 180);
    });

    test('non-food and the unknown get no guess', () {
      expect(guess('حاجة', 'العناية'), isNull);
      expect(guess('حاجة', 'الرعاية الصحية'), isNull);
      expect(guess('حاجة', 'منظفات'), isNull);
      expect(guess('حاجة', 'أخرى'), isNull);
      expect(guess('حاجة'), isNull);
      expect(guess('حاجة', 'المشروبات'), isNull);
    });

    test('the name beats the default category', () {
      // The add dialog starts on «البقالة».
      expect(guess('عيش بلدي', 'البقالة'), 4);
      expect(guess('لبن', 'البقالة'), 7);
      expect(guess('فراخ', 'البقالة'), 3);
      expect(guess('طماطم', 'البقالة'), 5);
      expect(guess('بيض', 'البقالة'), 21);
      expect(guess('صابون', 'البقالة'), isNull);
    });

    test('frozen beats fresh, in the name or the category', () {
      expect(guess('فراخ مجمدة'), 90);
      expect(guess('بسلة', 'مجمدات'), 90);
      expect(guess('frozen peas'), 90);
    });

    test('English names too', () {
      expect(guess('Milk'), 7);
      expect(guess('chicken breast'), 3);
      expect(guess('dish soap'), isNull);
    });
  });

  group('civil dates', () {
    test('plus days crosses months and years, at midnight UTC', () {
      final today = DateTime.utc(2026, 12, 29);
      expect(civilDatePlusDays(today, 3), DateTime.utc(2027));
      expect(civilDatePlusDays(today, 7), DateTime.utc(2027, 1, 5));
      expect(civilDatePlusDays(today, 30), DateTime.utc(2027, 1, 28));
      expect(kExpiryQuickDays, <int>[3, 7, 30]);
    });

    test("today is the account zone's day, not UTC's", () {
      // 21:30 UTC: already the 13th in Riyadh, still the 12th in Cairo.
      final now = DateTime.utc(2026, 11, 12, 21, 30);
      expect(civilDayIn(now, 'Asia/Riyadh'), DateTime.utc(2026, 11, 13));
      expect(civilDayIn(now, 'Africa/Cairo'), DateTime.utc(2026, 11, 12));
      expect(
        civilDatePlusDays(civilDayIn(now, 'Asia/Riyadh'), 7),
        DateTime.utc(2026, 11, 20),
      );
    });

    test('the guessed date counts from the given day', () {
      expect(
        guessExpiryDate(itemName: 'زبادي', today: DateTime.utc(2026, 2, 25)),
        DateTime.utc(2026, 3, 4),
      );
      expect(
        guessExpiryDate(itemName: 'شامبو', today: DateTime.utc(2026, 2, 25)),
        isNull,
      );
    });
  });
}
