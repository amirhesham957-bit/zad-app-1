import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/features/home/presentation/essential_permissions.dart';
import 'package:zad/features/home/presentation/rescue_card.dart';
import 'package:zad/shared/bank/application/bank_access_controller.dart';
import 'package:zad/shared/places/data/background_location.dart';

class _BankOff extends BankAccessController {
  @override
  BankAccessState build() => const BankAccessState(granted: false, pending: 0);
}

void main() {
  test('nothing missing when the platform cannot be read', () async {
    final c = ProviderContainer(
      overrides: [
        bankAccessControllerProvider.overrideWith(_BankOff.new),
        batteryUnrestrictedProvider.overrideWithValue(() async => null),
      ],
    );
    addTearDown(c.dispose);
    final missing = await c.read(missingPermissionsProvider.future);
    // Notifications unknown, battery unknown; only the bank listener is off.
    expect(missing, [EssentialPermission.bankReading]);
  });

  test('battery restricted is reported', () async {
    final c = ProviderContainer(
      overrides: [
        bankAccessControllerProvider.overrideWith(_BankOff.new),
        batteryUnrestrictedProvider.overrideWithValue(() async => false),
      ],
    );
    addTearDown(c.dispose);
    final missing = await c.read(missingPermissionsProvider.future);
    expect(missing, contains(EssentialPermission.battery));
  });

  Future<List<EssentialPermission>> missingWith({
    required bool needed,
    required bool granted,
  }) {
    final c = ProviderContainer(
      overrides: [
        bankAccessControllerProvider.overrideWith(_BankOff.new),
        batteryUnrestrictedProvider.overrideWithValue(() async => true),
        rescueLocationNeededProvider.overrideWithValue(() async => needed),
        backgroundLocationProvider.overrideWithValue(_Always(on: granted)),
      ],
    );
    addTearDown(c.dispose);
    return c.read(missingPermissionsProvider.future);
  }

  test('«الموقع طول الوقت» is missing for an account that uses it', () async {
    expect(
      await missingWith(needed: true, granted: false),
      contains(EssentialPermission.locationAlways),
    );
  });

  test('not asked when granted, or when the account never uses it', () async {
    expect(
      await missingWith(needed: true, granted: true),
      isNot(contains(EssentialPermission.locationAlways)),
    );
    expect(
      await missingWith(needed: false, granted: false),
      isNot(contains(EssentialPermission.locationAlways)),
    );
  });
}

class _Always implements BackgroundLocationAccess {
  new({required this.on});
  final bool on;
  @override
  Future<bool> granted() async => on;
  @override
  Future<bool> request() async => on;
  @override
  Future<void> openSettings() async {}
}
