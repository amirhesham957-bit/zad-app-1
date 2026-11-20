// Kotlin's NotificationCenterScreen: the unread count, opening one reads it,
// Kotlin's empty state, the bell's badge, and «تنبيهات ذكاء زاد» for the
// local insights.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/notifications/presentation/notification_center_screen.dart';
import 'package:zad/shared/ads/application/ads_policy.dart';
import 'package:zad/shared/insights/application/insights_controller.dart';
import 'package:zad/shared/insights/application/local_insights.dart';
import 'package:zad/shared/insights/domain/insight.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/notifications/application/notifications_controller.dart';
import 'package:zad/shared/notifications/domain/app_notification.dart';
import 'package:zad/shared/proposals/application/proposals_controller.dart';
import 'package:zad/shared/worlds/zad_world.dart';

import '../../support/fonts.dart';
import '../../support/quiet_household.dart';

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

class _Insights extends InsightsController {
  @override
  InsightsView build() => const InsightsView(pending: <ZadInsight>[]);

  @override
  Future<void> refresh({bool force = false}) async {}
}

class _Proposals extends ProposalsController {
  @override
  ProposalsView build() => const ProposalsView();

  @override
  Future<void> refresh({bool force = false}) async {}
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
    List<LocalInsight> local = const <LocalInsight>[],
  }) async {
    fake = _Notifications(items);
    tester.view
      ..physicalSize = const Size(430, 2600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...quietOrbOverrides,
          adsAllowedProvider.overrideWithValue(false),
          notificationsControllerProvider.overrideWith(() => fake),
          insightsControllerProvider.overrideWith(_Insights.new),
          proposalsControllerProvider.overrideWith(_Proposals.new),
          alertInsightsProvider.overrideWithValue(local),
          nowProvider.overrideWithValue(() => DateTime.utc(2026, 9, 21, 12)),
          accountTimeZoneProvider.overrideWithValue('Africa/Cairo'),
        ],
        child: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            theme: ZadTheme.light(),
            locale: const Locale('ar'),
            supportedLocales: ZadL10n.supportedLocales,
            localizationsDelegates: ZadL10n.localizationsDelegates,
            home: child is NotificationBell
                ? Scaffold(appBar: AppBar(actions: <Widget>[child]))
                : child,
          ),
        ),
      ),
    );
  }

  testWidgets("an empty list says so, in Kotlin's words", (tester) async {
    await pump(tester, <AppNotification>[]);
    expect(find.text('لا توجد إشعارات حالياً.'), findsOneWidget);
    expect(find.text('هنعلمك أول ما يحصل حاجة تستاهل انتباهك'), findsOneWidget);
  });

  testWidgets('the unread count and «إشعارات التطبيق»', (tester) async {
    await pump(tester, <AppNotification>[_n('a'), _n('b', read: true)]);
    // The world's state line, and the two actions beside the list.
    expect(find.text('1 غير مقروء'), findsOneWidget);
    expect(find.text('الإشعارات'), findsWidgets);
    expect(find.text('علّم الكل مقروء'), findsOneWidget);
    expect(find.byTooltip('قراءة التنبيهات صوتيًا'), findsOneWidget);
  });

  testWidgets('notifications are grouped by day in the account zone', (
    tester,
  ) async {
    await pump(tester, <AppNotification>[
      // 2026-09-20 21:30 UTC is already the 21st in Cairo: still «اليوم».
      AppNotification(
        id: 'late',
        title: 'عنوان late',
        message: 'رسالة late',
        createdAt: DateTime.utc(2026, 9, 20, 21, 30),
        isRead: true,
      ),
      _n('old', hoursAgo: 30),
    ]);
    expect(find.text('اليوم'), findsOneWidget);
    expect(find.text('أمس'), findsOneWidget);
  });

  testWidgets('each notification wears its source world', (tester) async {
    await pump(tester, <AppNotification>[
      AppNotification(
        id: 'p',
        title: 'حان وقت جرعة الدواء',
        message: 'بنادول',
        createdAt: DateTime.utc(2026, 9, 21, 11),
      ),
    ]);
    final pill = ZadWorld.ph.label(
      tester.element(find.byType(NotificationCard)).l10n,
    );
    expect(
      find.descendant(
        of: find.byType(NotificationCard),
        matching: find.text(pill),
      ),
      findsOneWidget,
    );
  });

  testWidgets('«علّم الكل مقروء» marks everything read', (tester) async {
    await pump(tester, <AppNotification>[_n('a'), _n('b')]);
    await tester.tap(find.text('علّم الكل مقروء'));
    await tester.pump();
    expect(fake.calls, <String>['all']);
  });

  testWidgets('opening one marks it read', (tester) async {
    await pump(tester, <AppNotification>[_n('a'), _n('b', read: true)]);
    await tester.tap(find.text('عنوان a'));
    await tester.pump();
    expect(fake.calls, <String>['read:a']);
  });

  testWidgets('local insights show under «تنبيهات ذكاء زاد»', (tester) async {
    await pump(
      tester,
      <AppNotification>[],
      local: const <LocalInsight>[
        LocalInsight(
          title: 'ميزانية البقالة على وشك النفاد',
          description: 'صرفت 900 من أصل 1000',
          type: 'Warning',
        ),
      ],
    );
    expect(find.text('تنبيهات ذكاء زاد'), findsOneWidget);
    expect(find.text('ميزانية البقالة على وشك النفاد'), findsOneWidget);
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

  testWidgets('«حاجة خلصت» shows a button per item, never the raw link', (
    tester,
  ) async {
    const url =
        'https://www.amazon.eg/s?k=%D8%AD%D9%84%D9%8A%D8%A8&tag=zad04-21';
    await tester.pumpWidget(
      MaterialApp(
        theme: ZadTheme.light(),
        locale: const Locale('ar'),
        supportedLocales: ZadL10n.supportedLocales,
        localizationsDelegates: ZadL10n.localizationsDelegates,
        home: Scaffold(
          body: NotificationCard(
            title: '🛒 حليب خلص',
            message: 'حليب خلص عندك. جهزتلك لينك أمازون.\n• حليب: $url',
            source: ZadWorld.inv,
            isRead: false,
            onTap: () {},
          ),
        ),
      ),
    );
    expect(find.text('حليب خلص عندك. جهزتلك لينك أمازون.'), findsOneWidget);
    expect(find.text('🛒 حليب على أمازون'), findsOneWidget);
    expect(find.textContaining('https://'), findsNothing);
    expect(
      tester.getSize(find.byType(OutlinedButton)).height,
      greaterThanOrEqualTo(44),
    );
  });

  testWidgets('screenshot: the notifications world', (tester) async {
    await loadZadFonts();
    AppNotification at(
      String id,
      String title,
      String msg,
      int h, {
      bool read = true,
    }) => AppNotification(
      id: id,
      title: title,
      message: msg,
      createdAt: DateTime.utc(2026, 9, 21, 12).subtract(Duration(hours: h)),
      isRead: read,
    );
    await pump(tester, <AppNotification>[
      at(
        '1',
        'حان وقت جرعة الدواء',
        'كونكور ٥ مجم — جرعة الصبح',
        2,
        read: false,
      ),
      at(
        '2',
        '⚠️ تنبيه الميزانية — 85%',
        'صرفت 8,500 من ميزانيتك',
        3,
        read: false,
      ),
      at('3', '📦 مخزون منخفض', 'اللبن والأرز نزلوا في قائمة التسوق', 5),
      at('4', '🔔 تجديد نتفليكس قريب!', 'خلال 3 أيام بمبلغ 120 جنيه', 28),
      at('5', 'نصيحة من زاد', 'جرّب قائمة التسوق الذكية', 30),
    ]);
    tester.view
      ..physicalSize = const Size(860, 1864)
      ..devicePixelRatio = 2;
    await tester.pump(const Duration(milliseconds: 600));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../../build/screens/world_notif.png'),
    );
  }, skip: Platform.environment['ZAD_SCREENS'] != '1');
}
