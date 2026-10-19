import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:zad/core/data/local/boxes.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/features/home/presentation/close_day_card.dart';
import 'package:zad/shared/alerts/application/local_reminders.dart';
import 'package:zad/shared/auth/application/session_controller.dart';
import 'package:zad/shared/companion/application/pet_care_controller.dart';
import 'package:zad/shared/day_close/application/day_close_controller.dart';
import 'package:zad/shared/day_close/data/day_close_remote.dart';
import 'package:zad/shared/day_close/domain/close_day_line.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';

import '../../support/quiet_household.dart';
import '../companion/companion_fakes.dart';

class _FakeRemote implements DayCloseRemote {
  new({this.offline = false});

  final bool offline;
  final List<DayCloseOutcome> closes = <DayCloseOutcome>[];
  bool closedOnServer = false;

  @override
  Future<DayCloseResult> close(DayCloseOutcome outcome) async {
    if (offline) return (ok: false, already: false, xp: 0, reason: 'offline');
    closes.add(outcome);
    final already = closes.length > 1;
    return (ok: true, already: already, xp: already ? 0 : 20, reason: null);
  }

  @override
  Future<bool?> closedOn(String day) async => offline ? null : closedOnServer;
}

void main() {
  group('closeDayLine — the same words as the 9:30 template', () {
    test('nothing seen still asks about cash', () {
      expect(
        closeDayLine(const <SeenExpense>[]),
        'النهارده ماشفتش ولا مصروف. صرفت حاجة كاش؟',
      );
    });

    test('three named, the rest counted', () {
      expect(
        closeDayLine(const <SeenExpense>[
          (name: 'قهوة', amount: 50),
          (name: 'كارفور', amount: 320.4),
          (name: 'أوبر', amount: 85),
          (name: 'عيش', amount: 10),
        ], currency: 'ج.م'),
        'النهارده شفت 4 حاجات: قهوة 50 ج.م، كارفور 320 ج.م، أوبر 85 ج.م '
        'وكمان 1. فيه حاجة كاش؟',
      );
      expect(
        closeDayLine(const <SeenExpense>[(name: 'عيش', amount: 10)]),
        'النهارده شفت حاجة واحدة: عيش 10. فيه حاجة كاش؟',
      );
    });

    test('the thanks says the points and the dinner once', () {
      expect(
        closeDayThanks(already: false, xp: 20, petAte: true),
        'يومك اتقفل ✅ +20 نقطة لرفيقك، واتعشى 🍽️',
      );
      expect(
        closeDayThanks(already: true, xp: 0, petAte: false),
        'يومك متقفل خلاص ✅',
      );
    });
  });

  group('the close on the phone', () {
    late Directory dir;
    late Box<String> device;
    var run = 0;
    // 21:00 in Cairo (UTC+3 on this date).
    var now = DateTime.utc(2026, 10, 19, 18);

    setUpAll(tzdata.initializeTimeZones);

    setUp(() async {
      run++;
      now = DateTime.utc(2026, 10, 19, 18);
      dir = await Directory.systemTemp.createTemp('zad_day_close');
      Hive.init(dir.path);
      device = await Hive.openBox<String>('device$run');
    });

    tearDownAll(() => dir.delete(recursive: true).ignore());

    ProviderContainer containerWith(DayCloseRemote remote) {
      final c = ProviderContainer(
        overrides: [
          localStoreProvider.overrideWithValue(
            ZadLocalStore(
              outbox: device,
              transactions: device,
              documents: device,
              chat: device,
              inventory: device,
              shopping: device,
              pharmacy: device,
              subscriptions: device,
              device: device,
            ),
          ),
          supabaseClientProvider.overrideWithValue(quietSupabase),
          localRemindersProvider.overrideWith(QuietReminders.new),
          sessionControllerProvider.overrideWith(SignedIn.new),
          dayCloseRemoteProvider.overrideWithValue(remote),
          nowProvider.overrideWithValue(() => now),
          petClockProvider.overrideWithValue(() => now),
          accountTimeZoneProvider.overrideWithValue('Africa/Cairo'),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test(
      'a first close feeds the pet; a second gives no second dinner',
      () async {
        final remote = _FakeRemote();
        final c = containerWith(remote);
        expect(c.read(dayCloseProvider), isNull);
        final hungry = c.read(petCareProvider)!.fullness(now);

        final first = await c
            .read(dayCloseProvider.notifier)
            .close(DayCloseOutcome.allGood);
        expect(first.result.xp, 20);
        expect(first.petAte, isTrue);
        expect(c.read(petCareProvider)!.fullness(now), greaterThan(hungry));
        expect(c.read(dayCloseProvider), '2026-10-19');
        expect(c.read(dayCloseProvider.notifier).closedToday, isTrue);
        expect(device.get('day_closed_user-1'), '2026-10-19');

        final second = await c
            .read(dayCloseProvider.notifier)
            .close(DayCloseOutcome.cash);
        expect(second.result.already, isTrue);
        expect(second.petAte, isFalse);
      },
    );

    test('a failed close changes nothing and feeds nobody', () async {
      final c = containerWith(_FakeRemote(offline: true));
      final before = c.read(petCareProvider)!.fedAt;
      final done = await c
          .read(dayCloseProvider.notifier)
          .close(DayCloseOutcome.allGood);
      expect(done.result.ok, isFalse);
      expect(done.petAte, isFalse);
      expect(c.read(dayCloseProvider), isNull);
      expect(c.read(petCareProvider)!.fedAt, before);
    });

    test(
      'a day closed elsewhere (Telegram) is learnt from the server',
      () async {
        final remote = _FakeRemote()..closedOnServer = true;
        final c = containerWith(remote)..read(dayCloseProvider);
        await Future<void>.delayed(Duration.zero);
        expect(c.read(dayCloseProvider.notifier).closedToday, isTrue);
      },
    );

    Future<ProviderContainer> pumpCard(
      WidgetTester tester,
      DayCloseRemote remote,
    ) async {
      final c = containerWith(remote);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: const MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(body: CloseDayCard()),
            ),
          ),
        ),
      );
      await tester.pump();
      return c;
    }

    testWidgets('the evening card closes the day and goes away', (
      tester,
    ) async {
      final remote = _FakeRemote();
      await pumpCard(tester, remote);
      expect(find.text('اقفل يومك'), findsOneWidget);

      await tester.tap(find.text('اقفل يومك'));
      await tester.pumpAndSettle();
      expect(
        find.text('النهارده ماشفتش ولا مصروف. صرفت حاجة كاش؟'),
        findsOneWidget,
      );

      await tester.tap(find.text('✅ تمام كده'));
      await tester.pumpAndSettle();
      expect(remote.closes, <DayCloseOutcome>[DayCloseOutcome.allGood]);
      expect(
        find.text('يومك اتقفل ✅ +20 نقطة لرفيقك، واتعشى 🍽️'),
        findsOneWidget,
      );
      expect(find.text('اقفل يومك'), findsNothing);
    });

    testWidgets('no card in the afternoon', (tester) async {
      now = DateTime.utc(2026, 10, 19, 12); // 15:00 in Cairo
      await pumpCard(tester, _FakeRemote());
      expect(find.text('اقفل يومك'), findsNothing);
    });
  });
}
