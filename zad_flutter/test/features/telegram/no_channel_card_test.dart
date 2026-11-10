// ZAD_PLAN ٦.٢: an account nobody can reach — notifications off and Telegram
// not linked — sees one card with both ways in and no «مش دلوقتي». Anything
// unknown never counts as missing.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/features/telegram/data/telegram_link.dart';
import 'package:zad/features/telegram/presentation/telegram_binding.dart';
import 'package:zad/shared/navigation/zad_screens.dart';
import 'package:zad/shared/session/product_events.dart';

class _Home extends TelegramHomeController {
  new(this.initial);

  final TelegramHomeState initial;

  @override
  TelegramHomeState build() => initial;
}

void main() {
  test('only two known misses make «no channel»', () {
    expect(noChannel(linked: false, notificationsOn: false), isTrue);
    expect(noChannel(linked: true, notificationsOn: false), isFalse);
    expect(noChannel(linked: false, notificationsOn: true), isFalse);
    expect(noChannel(linked: null, notificationsOn: false), isFalse);
    expect(noChannel(linked: false, notificationsOn: null), isFalse);
  });

  group('home', () {
    late bool allowed;
    late int asked;
    late List<String> events;
    late Future<bool> Function(WidgetRef) savedAllowed;
    late Future<bool> Function(WidgetRef) savedAsk;

    setUp(() {
      allowed = false;
      asked = 0;
      events = <String>[];
      savedAllowed = ZadScreens.notificationsAllowed;
      savedAsk = ZadScreens.askNotifications;
      ZadScreens.notificationsAllowed = (_) async => allowed;
      ZadScreens.askNotifications = (_) async {
        asked++;
        allowed = true;
        return true;
      };
    });

    tearDown(() {
      ZadScreens.notificationsAllowed = savedAllowed;
      ZadScreens.askNotifications = savedAsk;
    });

    Future<void> pump(WidgetTester tester, TelegramHomeState state) async {
      await tester.binding.setSurfaceSize(const Size(360, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            telegramHomeControllerProvider.overrideWith(() => _Home(state)),
            productEventsProvider.overrideWithValue(
              ProductEvents(
                send: (name) async => events.add(name),
                signedIn: () => true,
              ),
            ),
          ],
          child: const MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: SingleChildScrollView(child: HomeTelegramBlocks()),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      // The card grows in (AnimatedSize): let it reach its place.
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('no channel: one card, both ways in, no snooze', (
      tester,
    ) async {
      await pump(
        tester,
        const TelegramHomeState(
          bannerVisible: false, // snoozed — the card does not care
          promptDue: false,
          linked: false,
        ),
      );
      expect(find.text('مفيش طريقة أوصلك بيها'), findsOneWidget);
      expect(find.text('مش دلوقتي'), findsNothing);
      expect(events, contains('channel.card_shown'));

      await tester.tap(find.text('فعّل الإشعارات'));
      await tester.pump();
      await tester.pump();
      expect(asked, 1);
      expect(events, contains('channel.card_notifications'));
      // Notifications on: the card goes.
      expect(find.text('مفيش طريقة أوصلك بيها'), findsNothing);
    });

    testWidgets('notifications on: the usual Telegram banner, not the card', (
      tester,
    ) async {
      allowed = true;
      await pump(
        tester,
        const TelegramHomeState(
          bannerVisible: true,
          promptDue: false,
          linked: false,
        ),
      );
      expect(find.text('مفيش طريقة أوصلك بيها'), findsNothing);
      expect(find.text('تشغيل البوت الآن 🚀'), findsOneWidget);
      expect(events, isNot(contains('channel.card_shown')));
    });

    // One Telegram card at a time, none once linked (emulator, 2026-11-10).
    for (final (banner, linked, shown) in <(bool, bool, bool)>[
      (true, false, false),
      (false, false, true),
      (false, true, false),
    ]) {
      testWidgets('quiet bot card: banner $banner, linked $linked', (
        tester,
      ) async {
        allowed = true;
        await pump(
          tester,
          TelegramHomeState(
            bannerVisible: banner,
            promptDue: false,
            linked: linked,
          ),
        );
        expect(
          find.text('بوت زاد على تليجرام'),
          shown ? findsOneWidget : findsNothing,
        );
      });
    }

    testWidgets('link status unknown: no card', (tester) async {
      await pump(
        tester,
        const TelegramHomeState(bannerVisible: false, promptDue: false),
      );
      expect(find.text('مفيش طريقة أوصلك بيها'), findsNothing);
    });
  });
}
