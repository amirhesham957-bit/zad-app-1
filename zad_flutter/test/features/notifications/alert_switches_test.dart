// «تنبيهات المساعد الذكي»: every switch shows what the alerts actually do,
// and «تنبيهات تخطي الميزانية» decides the budget alert (owner, 2026-10-01:
// «في ميزات مستخبية في البروفايل تفعلها وهمي»).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/core/data/local/boxes.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/features/profile/presentation/profile_sub_screens.dart';
import 'package:zad/shared/alerts/data/alert_prefs.dart';
import 'package:zad/shared/notifications/application/smart_notifications.dart';

void main() {
  group('budgetAlert', () {
    (String, String)? alert({
      double spent = 900,
      double? limit = 1000,
      bool enabled = true,
      Set<String> unread = const <String>{},
    }) => budgetAlert(
      spent: spent,
      limit: limit,
      enabled: enabled,
      currency: 'EGP',
      alreadyUnread: unread.contains,
    );

    test('at 85% of the ceiling, once', () {
      expect(alert()?.$1, '⚠️ تنبيه الميزانية — 90%');
      expect(alert(spent: 800), isNull);
      expect(alert(limit: null), isNull);
      expect(alert(unread: <String>{'⚠️ تنبيه الميزانية — 90%'}), isNull);
    });

    test('the switch turns it off', () {
      expect(alert(enabled: false), isNull);
    });
  });

  group('the switches', () {
    late Directory dir;
    late ZadLocalStore store;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('zad_alert_switches');
      Hive.init(dir.path);
      store = await ZadLocalStore.open();
    });

    tearDown(() async {
      await Hive.deleteFromDisk();
      await dir.delete(recursive: true);
    });

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [localStoreProvider.overrideWithValue(store)],
          child: const MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: AssistantAlertsScreen(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    bool switchOf(WidgetTester tester, String title) {
      final row = find.ancestor(
        of: find.text(title),
        matching: find.byType(AlertSwitchItem),
      );
      return tester.widget<AlertSwitchItem>(row).checked;
    }

    testWidgets('stock and budget alerts read on, as they behave', (
      tester,
    ) async {
      await pump(tester);
      expect(switchOf(tester, 'تنبيهات نقص المخزون'), isTrue);
      expect(switchOf(tester, 'تنبيهات تخطي الميزانية'), isTrue);
      expect(switchOf(tester, 'تذكير التسبيح'), isFalse);
    });

    testWidgets('turning the budget switch off is what the alert reads', (
      tester,
    ) async {
      await pump(tester);
      final row = find.ancestor(
        of: find.text('تنبيهات تخطي الميزانية'),
        matching: find.byType(AlertSwitchItem),
      );
      // The Hive write runs outside the fake clock, where it can finish.
      await tester.runAsync(() async {
        tester.widget<AlertSwitchItem>(row).onChanged(false);
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      expect(switchOf(tester, 'تنبيهات تخطي الميزانية'), isFalse);
      expect(
        AlertPrefs(store.device).isEnabledUnlessOff(AlertPrefs.budgetOverrun),
        isFalse,
      );
    });
  });
}
