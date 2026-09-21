// The client's renewal date must be the server's, or the list promises a
// renewal the budget is not reserving money for.
//
// Every expected value below is what the deployed
// `zad_subscription_next_renewal` answered for the same inputs on 2026-09-21
// — called on the live project, not derived by hand. When the SQL changes,
// re-run that query and paste the new answers here in the same commit.

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/features/subscriptions/domain/renewal.dart';

typedef _Case = (
  int n,
  String? renewalDate,
  int? dueDay,
  String? cycle,
  String asOf,
  String? expected,
);

const List<_Case> _fromTheServer = <_Case>[
  (1, '2026-09-25', null, 'MONTHLY', '2026-09-21', '2026-09-25'),
  (2, '2026-09-10', null, 'MONTHLY', '2026-09-21', '2026-10-10'),
  (3, '2026-01-31', null, 'MONTHLY', '2026-02-15', '2026-02-28'),
  (4, '2026-01-31', null, 'MONTHLY', '2026-09-21', '2026-09-30'),
  (5, '2024-02-29', null, 'YEARLY', '2026-09-21', '2027-02-28'),
  (6, '2026-02-31', null, 'MONTHLY', '2026-09-21', '2026-10-20'),
  (7, '30 مارس', null, null, '2026-09-21', '2026-09-30'),
  (8, '20', null, 'MONTHLY', '2026-09-21', '2026-10-20'),
  (9, null, 5, 'MONTHLY', '2026-09-21', '2026-10-05'),
  (10, null, null, 'MONTHLY', '2026-09-21', null),
  (11, 'abc', null, 'MONTHLY', '2026-09-21', null),
  (12, '2020-01-06', null, 'WEEKLY', '2026-09-21', '2026-09-21'),
  (13, '2000-01-01', null, 'WEEKLY', '2026-09-21', null),
  (14, '2026-09-21', null, 'QUARTERLY', '2026-09-21', '2026-09-21'),
  (15, null, 31, 'MONTHLY', '2026-02-15', '2026-02-28'),
  (16, null, 32, null, '2026-09-21', null),
  (17, '0000-01-01', null, null, '2026-09-21', null),
  (18, '2026-09-21T10:00:00Z', null, 'YEARLY', '2026-09-22', '2027-09-21'),
  (19, '2026-12-31', null, 'MONTHLY', '2027-03-01', '2027-03-31'),
  (20, '5', 12, 'MONTHLY', '2026-09-21', '2026-10-12'),
  (21, '2026-13-01', null, null, '2026-09-21', '2026-10-20'),
  (22, '2025-08-15', null, 'annual', '2026-09-21', '2027-08-15'),
  (23, '', null, null, '2026-09-21', null),
  (24, '2028-02-29', null, 'MONTHLY', '2026-09-21', '2028-02-29'),
];

String? _iso(DateTime? d) => d?.toIso8601String().substring(0, 10);

void main() {
  group('agrees with zad_subscription_next_renewal', () {
    for (final (n, renewalDate, dueDay, cycle, asOf, expected)
        in _fromTheServer) {
      test('case $n: ($renewalDate, $dueDay, $cycle) as of $asOf', () {
        final got = nextRenewal(
          renewalDate: renewalDate,
          dueDay: dueDay,
          billingCycle: cycle,
          asOf: DateTime.parse(asOf),
        );
        expect(_iso(got), expected);
      });
    }
  });

  test('reads only the civil date of asOf', () {
    // A late-evening instant must not become tomorrow by way of UTC.
    final got = nextRenewal(
      renewalDate: '2026-09-21',
      dueDay: null,
      billingCycle: 'MONTHLY',
      asOf: DateTime(2026, 9, 21, 23, 59),
    );
    expect(_iso(got), '2026-09-21');
  });

  group('step', () {
    test('a monthly schedule returns to the 31st after February', () {
      final feb = step(
        DateTime.utc(2026, 1, 31),
        cycle: BillingCycle.monthly,
        anchorDay: 31,
      );
      expect(_iso(feb), '2026-02-28');
      expect(
        _iso(step(feb, cycle: BillingCycle.monthly, anchorDay: 31)),
        '2026-03-31',
      );
    });

    test('December rolls into January', () {
      expect(
        _iso(
          step(
            DateTime.utc(2026, 12, 15),
            cycle: BillingCycle.monthly,
            anchorDay: 15,
          ),
        ),
        '2027-01-15',
      );
    });
  });

  test('anchorDayOf follows the same sources as the SQL', () {
    expect(anchorDayOf(renewalDate: '2026-01-31', dueDay: 5), 31);
    expect(anchorDayOf(renewalDate: '2026-02-31', dueDay: null), 20);
    expect(anchorDayOf(renewalDate: 'x', dueDay: 7), 7);
    expect(anchorDayOf(renewalDate: null, dueDay: null), isNull);
  });

  test("monthlyEquivalent matches the Kotlin app's figures", () {
    expect(monthlyEquivalent(120, BillingCycle.yearly), 10);
    expect(monthlyEquivalent(100, BillingCycle.weekly), closeTo(434.5, 1e-9));
    expect(monthlyEquivalent(50, BillingCycle.monthly), 50);
  });

  test('billing cycles read the way the SQL case reads them', () {
    expect(BillingCycle.fromWire(null), BillingCycle.monthly);
    expect(BillingCycle.fromWire('annual'), BillingCycle.yearly);
    expect(BillingCycle.fromWire('weekly'), BillingCycle.weekly);
    expect(BillingCycle.fromWire('QUARTERLY'), BillingCycle.monthly);
  });
}
