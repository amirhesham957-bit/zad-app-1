// Back to the app re-reads the medicines: «امسح سيبرو» to the Telegram bot
// deleted the row on the server (2026-10-05), and the open app kept showing
// it, with its doses today and its reminders, until a restart.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:zad/app/zad_shell.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/shared/pharmacy/application/pharmacy_controller.dart';

import '../support/quiet_household.dart';
import '../support/shell_harness.dart';

class _CountingPharmacy extends QuietPharmacy {
  int refreshes = 0;

  @override
  Future<void> refresh() async => refreshes++;
}

void main() {
  final harness = ShellHarness();

  setUpAll(() async {
    tz_data.initializeTimeZones();
    await initializeDateFormatting('ar');
  });
  setUp(harness.open);

  testWidgets('coming back to the app refreshes the pharmacy', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('zad/app'),
      (_) async => true,
    );
    final pharmacy = _CountingPharmacy();
    final container = harness.container(
      'user-1',
      household: <Override>[
        quietHouseholdOverrides.first,
        pharmacyControllerProvider.overrideWith(() => pharmacy),
        ...quietHouseholdOverrides.skip(2),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ZadTheme.light(),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: ZadShell(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    // Read once, so the controller is alive the way a screen keeps it.
    container.read(pharmacyControllerProvider);
    final before = pharmacy.refreshes;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(pharmacy.refreshes, before, reason: 'leaving reads nothing');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(pharmacy.refreshes, before + 1);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 3));
  });
}
