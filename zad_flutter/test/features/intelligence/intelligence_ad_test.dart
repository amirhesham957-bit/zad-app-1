// One ad per AI request (owner, 11/11): the written report and the «اشرح
// بالذكاء الاصطناعي» answers on the brain screen carry an inline ad under
// them; before the answer, and when the call fails, there is none.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/features/intelligence/presentation/intelligence_screen.dart';
import 'package:zad/shared/ads/application/ads_policy.dart';
import 'package:zad/shared/ads/presentation/inline_ad.dart';
import 'package:zad/shared/alerts/application/local_reminders.dart';
import 'package:zad/shared/family/application/family_controller.dart';
import 'package:zad/shared/inventory/application/pantry_controller.dart';
import 'package:zad/shared/inventory/application/shopping_controller.dart';
import 'package:zad/shared/modes/application/modes_controller.dart';
import 'package:zad/shared/pharmacy/application/pharmacy_controller.dart';
import 'package:zad/shared/sync/live_sync.dart';

import '../../support/quiet_household.dart';
import '../../support/shell_harness.dart';

void main() {
  final harness = ShellHarness();
  var status = 200;
  Completer<void>? gate;
  // Built outside the tests: its auth client starts a timer the fake clock
  // would otherwise count as pending.
  final client = SupabaseClient(
    'https://example.supabase.co',
    'anon',
    httpClient: MockClient((request) async {
      // Everything but the two AI calls (the companion's status, rows)
      // answers empty and at once.
      final decoded = request.method == 'POST' && request.body.isNotEmpty
          ? jsonDecode(request.body)
          : null;
      final body = decoded is Map<String, dynamic> ? decoded : null;
      final action = body?['action'];
      if (action != 'explain' && action != 'monthly_expense_report') {
        return http.Response(
          '[]',
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }
      await gate?.future;
      final answer = action == 'explain'
          ? <String, dynamic>{'ok': true, 'text': 'شرح من زاد'}
          : <String, dynamic>{
              'summary': 'ملخص الشهر',
              'insights': <String>['لاحظت كذا'],
              'recommendations': <String>['وفّر كذا'],
              'health_label': 'ممتاز',
            };
      return http.Response(
        jsonEncode(answer),
        status,
        headers: <String, String>{'content-type': 'application/json'},
      );
    }),
  );

  setUpAll(() async {
    tz_data.initializeTimeZones();
    await initializeDateFormatting('ar');
  });
  setUp(() async {
    // The chat card's recorder has no plugin under test.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.record/messages'),
          (_) async => null,
        );
    status = 200;
    gate = null;
    await harness.open();
    for (var i = 0; i < 6; i++) {
      await harness.transactions.put(
        'seed-$i',
        jsonEncode(<String, dynamic>{
          'id': 'seed-$i',
          'user_id': 'user-1',
          'amount': 100 + i,
          'title': 'كارفور',
          'category': 'بقالة',
          'created_at': harness.now
              .subtract(Duration(days: i))
              .toIso8601String(),
          'wallet': 'card',
          'txn_kind': 'expense',
          'is_expense': true,
          'merchant_name': 'كارفور',
        }),
      );
    }
  });

  Future<void> open(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = harness.container(
      'user-1',
      // The quiet household minus its own Supabase stand-in, which this
      // test replaces with one that answers.
      household: [
        pantryControllerProvider.overrideWith(QuietPantry.new),
        pharmacyControllerProvider.overrideWith(QuietPharmacy.new),
        shoppingControllerProvider.overrideWith(QuietShopping.new),
        modesControllerProvider.overrideWith(QuietModes.new),
        familyControllerProvider.overrideWith(QuietFamily.new),
        localRemindersProvider.overrideWith(QuietReminders.new),
        liveSyncProvider.overrideWith(
          (ref) =>
              LiveSync(changes: QuietLiveChanges(), onChange: (_) async {}),
        ),
        supabaseClientProvider.overrideWithValue(client),
      ],
      extra: [adsAllowedProvider.overrideWithValue(false)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ZadTheme.light(),
          locale: const Locale('ar'),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: IntelligenceScreen(),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  final reportButton = find.widgetWithText(
    FilledButton,
    'توليد تقرير الذكاء الاصطناعي الشامل',
  );
  final explainButton = find.text('اشرح بالذكاء الاصطناعي');

  testWidgets('the written report carries one inline ad, once it lands', (
    tester,
  ) async {
    gate = Completer<void>();
    await open(tester);
    expect(find.byType(ZadInlineAd), findsNothing);
    await tester.tap(reportButton);
    await settle(tester);
    expect(find.byType(ZadInlineAd), findsNothing);

    gate!.complete();
    await settle(tester);
    expect(find.text('ملخص الشهر'), findsOneWidget);
    expect(find.byType(ZadInlineAd), findsOneWidget);
  });

  testWidgets('a report that failed shows no ad', (tester) async {
    status = 500;
    await open(tester);
    await tester.tap(reportButton);
    await settle(tester);
    expect(find.text('إعادة المحاولة'), findsOneWidget);
    expect(find.byType(ZadInlineAd), findsNothing);
  });

  testWidgets('an explanation carries one inline ad, a failed one none', (
    tester,
  ) async {
    await open(tester);
    expect(find.byType(ZadInlineAd), findsNothing);
    await tester.ensureVisible(explainButton.first);
    await tester.tap(explainButton.first);
    await settle(tester);
    expect(find.text('شرح من زاد'), findsOneWidget);
    expect(find.byType(ZadInlineAd), findsOneWidget);
  });

  testWidgets('an explanation that failed shows no ad', (tester) async {
    status = 500;
    await open(tester);
    await tester.ensureVisible(explainButton.first);
    await tester.tap(explainButton.first);
    await settle(tester);
    expect(find.text('شرح من زاد'), findsNothing);
    expect(find.byType(ZadInlineAd), findsNothing);
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 120));
  }
}
