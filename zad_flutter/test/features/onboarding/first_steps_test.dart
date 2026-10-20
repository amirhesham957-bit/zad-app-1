// «أول خطوة» (ZAD_PLAN 2.9): the first expense, notifications and Telegram are
// steps after the introduction, each skippable, and the way out never waits.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/features/onboarding/application/first_steps_controller.dart';
import 'package:zad/features/onboarding/presentation/first_steps_screen.dart';
import 'package:zad/shared/kids/application/kids_mode_controller.dart';
import 'package:zad/shared/navigation/zad_screens.dart';
import 'package:zad/shared/navigation/zad_slots.dart';
import 'package:zad/shared/session/product_events.dart';
import 'package:zad/shared/transactions/application/transactions_controller.dart';
import 'package:zad/shared/transactions/domain/transaction.dart';

class _Steps extends FirstStepsController {
  bool finished = false;

  @override
  bool build() => true;

  @override
  void finish() {
    finished = true;
    state = false;
  }
}

class _Txns extends TransactionsController {
  new(this.rows);

  final List<ZadTransaction> rows;

  @override
  TransactionsView build() => TransactionsView(rows: rows);

  @override
  Future<void> refresh({bool force = false}) async {}
}

final _coffee = ZadTransaction.fromJson(<String, dynamic>{
  'id': 't1',
  'user_id': 'u',
  'amount': 40,
  'title': 'قهوة',
  'created_at': '2026-10-20T10:00:00Z',
  'txn_kind': 'expense',
  'is_expense': true,
});

void main() {
  late List<String> events;
  late bool allowed;
  late int asked;
  late Future<bool> Function(WidgetRef) savedAllowed;
  late Future<bool> Function(WidgetRef) savedAsk;
  late SlotBuilder savedTelegram;

  setUp(() {
    events = <String>[];
    allowed = false;
    asked = 0;
    savedAllowed = ZadScreens.notificationsAllowed;
    savedAsk = ZadScreens.askNotifications;
    savedTelegram = ZadSlots.telegramBindingSection;
    ZadScreens.notificationsAllowed = (_) async => allowed;
    ZadScreens.askNotifications = (_) async {
      asked++;
      allowed = true;
      return true;
    };
    ZadSlots.telegramBindingSection = () => const Text('telegram-card');
  });

  tearDown(() {
    ZadScreens.notificationsAllowed = savedAllowed;
    ZadScreens.askNotifications = savedAsk;
    ZadSlots.telegramBindingSection = savedTelegram;
  });

  Future<_Steps> pump(
    WidgetTester tester, {
    List<ZadTransaction> rows = const <ZadTransaction>[],
  }) async {
    final steps = _Steps();
    tester.view
      ..physicalSize = const Size(1080, 3000)
      ..devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firstStepsControllerProvider.overrideWith(() => steps),
          transactionsControllerProvider.overrideWith(() => _Txns(rows)),
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
            child: FirstStepsScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
    return steps;
  }

  testWidgets('three steps, Telegram among them with its reason', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('سجّل أول مصروف'), findsOneWidget);
    expect(find.text('فعّل الإشعارات'), findsOneWidget);
    expect(find.text('اربط بوت تليجرام'), findsOneWidget);
    expect(find.textContaining('من غيره التذكيرات'), findsOneWidget);
    expect(find.text('telegram-card'), findsOneWidget);
    expect(events, contains('onboarding.steps_shown'));
  });

  testWidgets('the way out never waits on a step', (tester) async {
    final steps = await pump(tester);
    await tester.tap(find.text('كمّل بعدين — افتح زاد'));
    await tester.pump();
    expect(steps.finished, isTrue);
    expect(events, contains('onboarding.later'));
  });

  testWidgets('notifications are asked for on a tap, and the step ticks', (
    tester,
  ) async {
    await pump(tester, rows: <ZadTransaction>[_coffee]);
    expect(asked, 0);
    await tester.tap(find.text('فعّل'));
    await tester.pump();
    await tester.pump();
    expect(asked, 1);
    expect(find.text('متفعّلة ✓'), findsOneWidget);
    expect(events, contains('onboarding.notifications_on'));
    // An expense and notifications: the button says the steps are done.
    expect(find.text('اتسجل ✓'), findsOneWidget);
    await tester.tap(find.text('يلا على زاد'));
    await tester.pump();
    expect(events, contains('onboarding.done'));
  });

  testWidgets('notifications already allowed show as done without asking', (
    tester,
  ) async {
    allowed = true;
    await pump(tester);
    await tester.pump();
    expect(find.text('متفعّلة ✓'), findsOneWidget);
    expect(asked, 0);
  });

  test('never in kids mode', () {
    final c = ProviderContainer(
      overrides: [
        firstStepsControllerProvider.overrideWith(_Steps.new),
        kidsModeActiveProvider.overrideWithValue(true),
      ],
    );
    addTearDown(c.dispose);
    expect(c.read(firstStepsDueProvider), isFalse);
  });
}
