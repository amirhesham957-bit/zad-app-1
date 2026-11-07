import 'package:flutter_test/flutter_test.dart';
import 'package:zad/features/home/presentation/permission_banners.dart';
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
}
