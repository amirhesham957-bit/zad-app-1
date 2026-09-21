// The profile is cut to what the table accepts before it is sent, and sends
// only the columns this screen owns; the habits card shows only what a row
// says.

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/features/brain/domain/customer_profile.dart';
import 'package:zad/features/brain/domain/habits.dart';
import 'package:zad/features/brain/domain/memory_note.dart';
import 'package:zad/features/brain/presentation/profile_sheet.dart';

void main() {
  group('CustomerProfile.normalized', () {
    test('trims, caps, and turns blanks into "not known"', () {
      final p = CustomerProfile(
        preferredName: '  أمير  ',
        occupation: '   ',
        city: 'ا' * 70,
      ).normalized();
      expect(p.preferredName, 'أمير');
      expect(p.occupation, isNull);
      expect(p.city!.length, 60);
    });

    test('drops anything outside a check constraint instead of sending it', () {
      final p = const CustomerProfile(
        gender: 'other',
        householdRole: 'uncle',
        ageRange: '30s',
        payFrequency: 'yearly',
        dialect: 'FR',
        payDay: 32,
        householdSize: 0,
        kidsCount: 21,
      ).normalized();
      expect(p, const CustomerProfile());
    });

    test('keeps every value the constraints allow', () {
      const p = CustomerProfile(
        gender: 'female',
        householdRole: 'grandparent',
        ageRange: '55_plus',
        payFrequency: 'irregular',
        dialect: 'EN',
        payDay: 31,
        householdSize: 30,
        kidsCount: 0,
      );
      expect(p.normalized(), p);
    });
  });

  test('the form sends only the columns it shows', () {
    // work_schedule, income_source, interests and notes come from the brain;
    // an upsert that leaves them out keeps them.
    expect(const CustomerProfile().toFormJson().keys.toSet(), <String>{
      'preferred_name',
      'gender',
      'household_role',
      'age_range',
      'occupation',
      'pay_day',
      'pay_frequency',
      'household_size',
      'kids_count',
      'city',
      'dialect',
    });
  });

  test('a number typed in Arabic digits is read', () {
    expect(parseWholeNumber('٢٥'), 25);
    expect(parseWholeNumber(' 7 '), 7);
    expect(parseWholeNumber(''), isNull);
    expect(parseWholeNumber('خمسة'), isNull);
  });

  test('every scope on the live project reads as Arabic', () {
    for (final scope in <String>[
      'cycle_pattern',
      'data_quality',
      'dismissal',
      'general',
      'proactive_dismissal',
      'spending_pattern',
      'weekly_synthesis',
    ]) {
      final label = memoryScopeLabel(scope);
      expect(label, isNot('ملاحظة'), reason: scope);
      expect(label, isNot(contains('_')), reason: scope);
    }
  });

  group('HabitsSummary', () {
    PlaceVisit visit(double spent, List<String> places) => PlaceVisit(
      returnedAt: DateTime.utc(2026, 9, 20),
      spentTotal: spent,
      places: places,
    );

    test('the three biggest categories, biggest first', () {
      final h = HabitsSummary.from(const <String, dynamic>{
        'top_spending_categories': <Map<String, dynamic>>[
          <String, dynamic>{'category': 'مطاعم', 'total': 300},
          <String, dynamic>{'category': 'بقالة', 'total': 900},
          <String, dynamic>{'category': ' ', 'total': 5000},
          <String, dynamic>{'category': 'مواصلات', 'total': 400},
          <String, dynamic>{'category': 'فواتير', 'total': 100},
        ],
      }, const <PlaceVisit>[]);
      expect(h.topCategories, <String>['بقالة', 'مواصلات', 'مطاعم']);
    });

    test('the busiest weekday is the biggest, and zeros say nothing', () {
      final h = HabitsSummary.from(const <String, dynamic>{
        'spending_pattern_by_weekday': <String, dynamic>{
          'السبت': 120,
          'الخميس': 480.5,
          'الأحد': 0,
        },
        'avg_weekly_spending': 0,
        'subscription_load_monthly': 0,
      }, const <PlaceVisit>[]);
      expect(h.busiestWeekday, 'الخميس');
      expect(h.avgWeeklySpending, isNull);
      expect(h.subscriptionsMonthly, isNull);
    });

    test(
      'outings: spend averaged over the ones that spent, places counted',
      () {
        final h = HabitsSummary.from(null, <PlaceVisit>[
          visit(100, <String>['كارفور', 'صيدلية العزبي']),
          visit(0, <String>['كارفور']),
          visit(300, <String>['كارفور', 'بيم']),
        ]);
        expect(h.outingsCount, 3);
        expect(h.avgSpendPerOuting, 200);
        expect(h.topPlaces.first, 'كارفور');
        expect(h.isEmpty, isFalse);
      },
    );

    test('a visit names each place once, merchants and stores together', () {
      final v = PlaceVisit.fromJson(const <String, dynamic>{
        'returned_at': '2026-09-20T18:00:00Z',
        'spent_total': 50,
        'merchants': <String>['كارفور', ' '],
        'stores': <String>['كارفور', 'بيم'],
      });
      expect(v.places, <String>['كارفور', 'بيم']);
    });

    test('nothing learned is empty', () {
      expect(HabitsSummary.from(null, const <PlaceVisit>[]).isEmpty, isTrue);
    });
  });
}
