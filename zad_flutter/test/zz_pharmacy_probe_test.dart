import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/features/household/presentation/household_screen.dart';
import 'package:zad/shared/navigation/destinations.dart';

import 'support/quiet_household.dart';
import 'support/shell_harness.dart';

void main() {
  final harness = ShellHarness();
  setUpAll(() async {
    tz_data.initializeTimeZones();
    await initializeDateFormatting('ar');
  });
  setUp(harness.open);
  testWidgets('probe', (tester) async {
    final overrides = [...quietHouseholdOverrides]..removeAt(1);
    final c = harness.container('user-1', household: overrides);
    addTearDown(c.dispose);
    final errors = <String>[];
    final old = FlutterError.onError;
    FlutterError.onError = (d) =>
        errors.add(d.toString().split('\n').take(12).join('\n'));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: ZadTheme.light(),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: HouseholdScreen(initialSection: HouseholdSection.pharmacy),
          ),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    FlutterError.onError = old;
    final texts = find
        .byType(Text)
        .evaluate()
        .map((e) => (e.widget as Text).data)
        .whereType<String>()
        .toList();
    debugPrint('TEXTS: $texts');
    debugPrint('ERRORS: ${errors.join('\n---\n')}');
    debugPrint('EXC: ${tester.takeException()}');
  });
}
