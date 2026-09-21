// The screen's promises: unread is visible and countable, opening one reads
// it, "mark all" appears only when there is something to mark, and an empty
// list says so.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:zad/core/period/account_time_zone.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/design/zad_theme.dart';
import 'package:zad/features/notifications/application/notifications_controller.dart';
import 'package:zad/features/notifications/domain/app_notification.dart';
import 'package:zad/features/notifications/presentation/notification_center_screen.dart';

class _Notifications extends NotificationsController {
  new(this.items);

  final List<AppNotification> items;
  final List<String> calls = <String>[];

  @override
  NotificationsView build() => NotificationsView(items: items);

  @override
  Future<void> refresh({bool force = false}) async {}

  @override
  Future<void> markRead(AppNotification n) async => calls.add('read:${n.id}');

  @override
  Future<void> markAllRead() async => calls.add('all');
}

AppNotification _n(String id, {bool read = false, int hoursAgo = 1}) =>
    AppNotification(
      id: id,
      title: 'عنوان $id',
      message: 'رسالة $id',
      createdAt: DateTime.utc(
        2026,
        9,
        21,
        12,
      ).subtract(Duration(hours: hoursAgo)),
      isRead: read,
    );

void main() {
  late _Notifications fake;

  setUpAll(() async {
    tz_data.initializeTimeZones();
    await initializeDateFormatting('ar');
  });

  Future<void> pump(
    WidgetTester tester,
    List<AppNotification> items, {
    Widget child = const NotificationCenterScreen(),
  }) async {
    fake = _Notifications(items);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationsControllerProvider.overrideWith(() => fake),
          nowProvider.overrideWithValue(() => DateTime.utc(2026, 9, 21, 12)),
          accountTimeZoneProvider.overrideWithValue('Africa/Cairo'),
        ],
        child: MaterialApp(
          theme: ZadTheme.light(),
          home: Directionality(
            textDirection: TextDirection.rtl,
            // The screen is a whole page; the bell lives in an app bar.
            child: child is NotificationBell
                ? Scaffold(appBar: AppBar(actions: <Widget>[child]))
                : child,
          ),
        ),
      ),
    );
  }

  testWidgets('an empty list says so', (tester) async {
    await pump(tester, <AppNotification>[]);
    expect(find.text('مفيش تنبيهات'), findsOneWidget);
    expect(find.text('علّم الكل مقروء'), findsNothing);
  });

  testWidgets('opening an unread one marks it read', (tester) async {
    await pump(tester, <AppNotification>[_n('a'), _n('b', read: true)]);

    await tester.tap(find.text('عنوان a'));
    await tester.pump();
    await tester.tap(find.text('عنوان b'));
    await tester.pump();

    // The read one is not written again.
    expect(fake.calls, <String>['read:a']);
  });

  testWidgets('"mark all" marks everything when something is unread', (
    tester,
  ) async {
    await pump(tester, <AppNotification>[_n('a')]);
    await tester.tap(find.text('علّم الكل مقروء'));
    await tester.pump();
    expect(fake.calls, <String>['all']);
  });

  testWidgets('"mark all" is not offered when everything is read', (
    tester,
  ) async {
    await pump(tester, <AppNotification>[_n('b', read: true)]);
    expect(find.text('علّم الكل مقروء'), findsNothing);
  });

  testWidgets('the bell counts unread', (tester) async {
    await pump(tester, <AppNotification>[
      for (var i = 0; i < 3; i++) _n('$i'),
      _n('r', read: true),
    ], child: const NotificationBell());
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('past a page, the bell says "99+" rather than a count', (
    tester,
  ) async {
    await pump(tester, <AppNotification>[
      for (var i = 0; i < 132; i++) _n('$i'),
    ], child: const NotificationBell());
    expect(find.text('99+'), findsOneWidget);
  });
}
