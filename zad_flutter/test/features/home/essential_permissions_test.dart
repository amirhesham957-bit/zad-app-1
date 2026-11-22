import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/features/home/presentation/essential_permissions.dart';
import 'package:zad/shared/bank/application/bank_access_controller.dart';

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
}
