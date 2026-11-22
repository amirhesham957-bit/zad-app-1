import 'package:flutter_test/flutter_test.dart';
import 'package:zad/features/home/domain/zad_status.dart';
import 'package:zad/shared/bank/application/bank_access_controller.dart';
import 'package:zad/shared/nearby/data/location_source.dart';

void main() {
  final now = DateTime.utc(2026, 11, 7, 15);

  group('showBankBanner', () {
    test('not read yet: nothing', () {
      expect(
        showBankBanner(const BankAccessState(granted: false, pending: 0)),
        isFalse,
      );
    });

    test('a new account that never had access: the setup card asks', () {
      expect(
        showBankBanner(
          BankAccessState(granted: false, pending: 0, checkedAt: now),
        ),
        isFalse,
      );
    });

    test('access taken back after it had worked: the banner', () {
      final s = BankAccessState(
        granted: false,
        pending: 0,
        lastConnectedAt: now.subtract(const Duration(days: 3)),
        checkedAt: now,
      );
      expect(s.health, BankAccessHealth.notGranted);
      expect(showBankBanner(s), isTrue);
    });

    test('granted but silent past the stall window: the banner', () {
      final s = BankAccessState(
        granted: true,
        pending: 0,
        lastConnectedAt: now.subtract(const Duration(days: 5)),
        lastCapturedAt: now.subtract(const Duration(days: 4)),
        lastSeenAnyAt: now.subtract(
          kListenerStallAfter + const Duration(hours: 1),
        ),
        checkedAt: now,
      );
      expect(s.health, BankAccessHealth.stalled);
      expect(showBankBanner(s), isTrue);
    });

    test('flowing: nothing', () {
      final s = BankAccessState(
        granted: true,
        pending: 0,
        lastConnectedAt: now.subtract(const Duration(days: 1)),
        lastCapturedAt: now.subtract(const Duration(hours: 1)),
        lastSeenAnyAt: now.subtract(const Duration(minutes: 5)),
        checkedAt: now,
      );
      expect(s.health, BankAccessHealth.flowing);
      expect(showBankBanner(s), isFalse);
    });
  });

  group('showLocationBanner', () {
    test('granted or unreadable: nothing', () {
      expect(showLocationBanner(LocationAccess.granted, null, now), isFalse);
      expect(showLocationBanner(null, null, now), isFalse);
    });

    test('refused, refused for good, or switched off: the banner', () {
      for (final a in <LocationAccess>[
        LocationAccess.denied,
        LocationAccess.deniedForever,
        LocationAccess.serviceOff,
      ]) {
        expect(showLocationBanner(a, null, now), isTrue, reason: '$a');
      }
    });

    test('«مش دلوقتي» puts it away for a week, then it comes back', () {
      final snoozed = now.subtract(const Duration(days: 2));
      expect(showLocationBanner(LocationAccess.denied, snoozed, now), isFalse);
      expect(
        showLocationBanner(
          LocationAccess.denied,
          snoozed,
          snoozed.add(kLocationBannerSnooze),
        ),
        isTrue,
      );
    });
  });

  group('zadStatusRows', () {
    final flowing = BankAccessState(
      granted: true,
      pending: 0,
      lastConnectedAt: now.subtract(const Duration(days: 1)),
      lastCapturedAt: now.subtract(const Duration(hours: 1)),
      lastSeenAnyAt: now.subtract(const Duration(minutes: 5)),
      checkedAt: now,
    );
    final stalled = BankAccessState(
      granted: true,
      pending: 0,
      lastConnectedAt: now.subtract(const Duration(days: 5)),
      lastCapturedAt: now.subtract(const Duration(days: 4)),
      lastSeenAnyAt: now.subtract(
        kListenerStallAfter + const Duration(hours: 1),
      ),
      checkedAt: now,
    );

    test('everything working: all rows ok, nothing needs attention', () {
      final rows = zadStatusRows(
        ZadStatusReading(
          bank: flowing,
          notificationsOn: true,
          location: LocationAccess.granted,
          backgroundNeeded: true,
          backgroundGranted: true,
          batteryUnrestricted: true,
        ),
      );
      expect(rows, hasLength(5));
      expect(rows.every((r) => r.level == ZadStatusLevel.ok), isTrue);
      expect(rows.any((r) => r.needsAttention), isFalse);
    });

    test('broken rows come first, each with its fix', () {
      final rows = zadStatusRows(
        ZadStatusReading(
          bank: stalled,
          notificationsOn: true,
          location: LocationAccess.serviceOff,
          batteryUnrestricted: false,
        ),
      );
      expect(rows.map((r) => r.kind).toList(), <ZadStatusKind>[
        ZadStatusKind.bank,
        ZadStatusKind.location,
        ZadStatusKind.battery,
        ZadStatusKind.notifications,
      ]);
      expect(rows[0].fix, ZadStatusFix.openBankSettings);
      expect(rows[0].level, ZadStatusLevel.off);
      expect(rows[1].fix, ZadStatusFix.openLocationSettings);
      expect(rows[2].level, ZadStatusLevel.warn);
    });

    test('granted but silent is its own explained state', () {
      final silent = BankAccessState(granted: true, pending: 0, checkedAt: now);
      final row = zadStatusRows(ZadStatusReading(bank: silent)).single;
      expect(row.reason, ZadStatusReason.bankSilent);
      expect(row.needsAttention, isTrue);
    });

    test('a brand-new account has no bank row: the setup card asks', () {
      final fresh = BankAccessState(granted: false, pending: 0, checkedAt: now);
      expect(zadStatusRows(ZadStatusReading(bank: fresh)), isEmpty);
    });

    test('location fixes follow how it is refused', () {
      ZadStatusFix? fixFor(LocationAccess a) =>
          zadStatusRows(ZadStatusReading(bank: flowing, location: a))
              .firstWhere((r) => r.kind == ZadStatusKind.location)
              .fix;
      expect(fixFor(LocationAccess.denied), ZadStatusFix.askLocation);
      expect(
        fixFor(LocationAccess.deniedForever),
        ZadStatusFix.openAppSettings,
      );
      expect(
        fixFor(LocationAccess.serviceOff),
        ZadStatusFix.openLocationSettings,
      );
    });

    test('«مش دلوقتي» keeps the row listed but not counted', () {
      final rows = zadStatusRows(
        ZadStatusReading(
          bank: flowing,
          location: LocationAccess.denied,
          locationSnoozed: true,
        ),
      );
      final loc = rows.firstWhere((r) => r.kind == ZadStatusKind.location);
      expect(loc.snoozed, isTrue);
      expect(loc.needsAttention, isFalse);
    });

    test('background shows only for an account that uses it', () {
      final without = zadStatusRows(
        ZadStatusReading(bank: flowing, backgroundGranted: false),
      );
      expect(without.any((r) => r.kind == ZadStatusKind.background), isFalse);
      final needed = zadStatusRows(
        ZadStatusReading(
          bank: flowing,
          backgroundNeeded: true,
          backgroundGranted: false,
        ),
      );
      expect(needed.first.kind, ZadStatusKind.background);
      expect(needed.first.fix, ZadStatusFix.askBackground);
    });

    test('unreadable rows are left out', () {
      expect(
        zadStatusRows(ZadStatusReading(bank: flowing)).map((r) => r.kind),
        <ZadStatusKind>[ZadStatusKind.bank],
      );
    });
  });
}
