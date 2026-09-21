// The settings row says whether alerts reach this phone, offers the prompt
// while Android will still show it, and the system settings once it will not.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/design/zad_theme.dart';
import 'package:zad/features/alerts/data/notification_permission.dart';
import 'package:zad/features/alerts/presentation/alerts_settings_section.dart';

class _Permission implements NotificationPermission {
  new(this.now);
  AlertPermission now;
  int requests = 0;
  int settingsOpened = 0;

  @override
  Future<AlertPermission> status() async => now;

  @override
  Future<AlertPermission> request() async {
    requests++;
    return now = AlertPermission.granted;
  }

  @override
  Future<void> openSettings() async => settingsOpened++;
}

void main() {
  late _Permission permission;

  Future<void> pump(WidgetTester tester, AlertPermission starting) async {
    permission = _Permission(starting);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationPermissionProvider.overrideWithValue(permission),
        ],
        child: MaterialApp(
          theme: ZadTheme.light(),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: AlertsSettingsSection()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('granted: says so, offers nothing', (tester) async {
    await pump(tester, AlertPermission.granted);
    expect(find.textContaining('شغّالة'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('not granted: the button asks, and the row updates', (
    tester,
  ) async {
    await pump(tester, AlertPermission.denied);
    expect(find.textContaining('مقفولة'), findsOneWidget);

    await tester.tap(find.text('شغّل التنبيهات'));
    await tester.pumpAndSettle();

    expect(permission.requests, 1);
    expect(find.textContaining('شغّالة'), findsOneWidget);
  });

  testWidgets('blocked for good: the button opens the system settings', (
    tester,
  ) async {
    await pump(tester, AlertPermission.blocked);

    await tester.tap(find.text('افتح إعدادات النظام'));
    await tester.pumpAndSettle();

    expect(permission.settingsOpened, 1);
    expect(permission.requests, 0);
  });
}
