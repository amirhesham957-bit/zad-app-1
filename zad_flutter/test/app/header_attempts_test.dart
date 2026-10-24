// The attempts balance sits in the top header on every tab (ZAD_PLAN ٠.٤).
// It used to be on the chat's bar only, and the owner reported the attempts
// «مش موجودة».

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:zad/app/zad_shell.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/shared/quota/application/attempts_balance_provider.dart';
import 'package:zad/shared/quota/domain/attempts_balance.dart';

import '../support/shell_harness.dart';

void main() {
  final harness = ShellHarness();

  setUpAll(() async {
    tz_data.initializeTimeZones();
    await initializeDateFormatting('ar');
  });
  setUp(harness.open);

  Future<void> pump(WidgetTester tester, AttemptsBalance? balance) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('zad/app'),
      (_) async => true,
    );
    final container = harness.container(
      'user-1',
      extra: <Override>[
        attemptsBalanceProvider.overrideWith((ref) async => balance),
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
  }

  testWidgets('home shows the balance in the header', (tester) async {
    await pump(
      tester,
      const AttemptsBalance(
        tier: 'free',
        left: 3,
        perCycle: 5,
        nextRefillAt: null,
        adsEnabled: true,
      ),
    );
    expect(find.byKey(const ValueKey<String>('attempts-chip')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('no balance, no chip — never a guessed number', (tester) async {
    await pump(tester, null);
    expect(find.byKey(const ValueKey<String>('attempts-chip')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
