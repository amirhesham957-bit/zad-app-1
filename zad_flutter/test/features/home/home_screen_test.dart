// The claim this screen makes is that the figure is on screen in the first
// frame. This holds it to that: one pump, no settle, no awaiting the network.
//
// Everything that touches the disk happens in setUp, never in a test body.
// `testWidgets` runs its body against a faked clock and a real Hive write
// inside it does not progress — the test hangs rather than fails, which costs
// far more to diagnose than it does to avoid. The remote here refuses
// immediately for the same reason: a refresh that succeeded would write to the
// cache mid-body. What a *successful* refresh does is covered next door in
// budget_controller_test.dart, which is a plain test() with a real event loop.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:zad/core/data/local/boxes.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/data/sync/outbox.dart';
import 'package:zad/core/design/components/zad_balance_card.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/home/presentation/home_care_bar.dart';
import 'package:zad/features/home/presentation/home_screen.dart';
import 'package:zad/features/home/presentation/home_today_card.dart';
import 'package:zad/features/home/presentation/home_world_scene.dart';
import 'package:zad/features/home/presentation/metrics_duo.dart';
import 'package:zad/features/home/presentation/tasbiha_home_widget.dart';
import 'package:zad/features/settings/presentation/monthly_limit_sheet.dart';
import 'package:zad/features/transactions/presentation/quick_expense_sheet.dart';
import 'package:zad/shared/ads/presentation/native_ad.dart';
import 'package:zad/shared/budget/application/budget_controller.dart';
import 'package:zad/shared/budget/data/budget_repository.dart';
import 'package:zad/shared/budget/domain/budget_snapshot.dart';
import 'package:zad/shared/insights/data/insights_repository.dart';
import 'package:zad/shared/inventory/application/pantry_controller.dart';
import 'package:zad/shared/inventory/domain/inventory_item.dart';
import 'package:zad/shared/inventory/domain/shortage.dart';
import 'package:zad/shared/navigation/zad_slots.dart';
import 'package:zad/shared/notifications/data/notifications_remote.dart';
import 'package:zad/shared/notifications/data/notifications_repository.dart';
import 'package:zad/shared/pharmacy/application/pharmacy_controller.dart';
import 'package:zad/shared/pharmacy/domain/dose_slot.dart';
import 'package:zad/shared/pharmacy/domain/dose_time.dart';
import 'package:zad/shared/pharmacy/domain/medicine.dart';
import 'package:zad/shared/settings/data/settings_repository.dart';
import 'package:zad/shared/subscriptions/application/subscriptions_controller.dart';
import 'package:zad/shared/subscriptions/data/subscriptions_remote.dart';
import 'package:zad/shared/subscriptions/data/subscriptions_repository.dart';
import 'package:zad/shared/subscriptions/domain/subscription.dart';
import 'package:zad/shared/transactions/data/transactions_remote.dart';
import 'package:zad/shared/transactions/data/transactions_repository.dart';
import 'package:zad/shared/worlds/world_scene.dart' show ScaledScene;

import '../../support/fonts.dart';
import '../../support/quiet_household.dart';

/// Refuses at once, so the screen's background refresh never writes to disk
/// while the faked clock is in charge.
class _OfflineRemote implements BudgetRemote {
  int calls = 0;

  @override
  Future<Map<String, dynamic>> fetch({
    required String userId,
    required String timeZone,
  }) {
    calls++;
    return Future<Map<String, dynamic>>.error(const SocketException('offline'));
  }
}

/// The settings row, without a server. The home screen reaches it the moment
/// the "set a budget" sheet opens, and the controller behind that sheet reads
/// `zad_users` as it builds.
///
/// It refuses immediately, for the same reason [_OfflineRemote] does: a read
/// that succeeded would write to the cache while the faked clock is in charge,
/// and a Hive write there never completes — the test hangs rather than fails.
/// This one did hang, before the refusal was added.
class _FakeSettingsRemote implements SettingsRemote {
  @override
  Future<Map<String, dynamic>?> fetch({required String userId}) =>
      Future<Map<String, dynamic>?>.error(const SocketException('offline'));

  @override
  Future<Map<String, dynamic>?> upsertReturning(Map<String, dynamic> sent) =>
      Future<Map<String, dynamic>?>.error(const SocketException('offline'));
}

class _FakeTransactionsRemote implements TransactionsRemote {
  @override
  Future<Map<String, dynamic>?> updateReturning(
    Map<String, dynamic> patch,
  ) async => null;

  @override
  Future<void> delete(String id) async {}

  @override
  Future<bool> exists(String id) async => false;

  @override
  Future<List<Map<String, dynamic>>> fetchPeriod({
    required String userId,
    required DateTime startsAt,
    required DateTime endsAt,
  }) async => <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>?> upsertReturning(
    Map<String, dynamic> row,
  ) async => row;
}

Map<String, dynamic> _state() => <String, dynamic>{
  'user_id': 'user-1',
  'currency': 'ج.م',
  'timezone': 'Africa/Cairo',
  'spent': 3179.5,
  'income': 0,
  'committed': 1200,
  'days_left': 5,
  'cycle_length_days': 31,
  'threat': 'SAFE',
  'unverified_count': 0,
  'computed_at': '2026-09-19T12:00:00Z',
  'available': 3620.5,
  'remaining': 4820.5,
  'opening_balance': 8000,
  'limit_confirmed': true,
  'cycle_start': '2026-08-25',
  'cycle_end': '2026-09-25',
};

/// The same account before it has told us anything: the server answers with
/// nulls, not zeroes, for an unconfirmed limit.
Map<String, dynamic> _stateWithNoBudget() => <String, dynamic>{
  ..._state(),
  'available': null,
  'remaining': null,
  'opening_balance': null,
  'limit_confirmed': false,
  'threat': 'UNKNOWN',
};

/// Refuses at once: a widget test must not let a background refresh reach a
/// Hive write, which never completes under the fake clock.
class _OfflineSubscriptions implements SubscriptionsRemote {
  @override
  Future<List<Map<String, dynamic>>> fetchAll({required String userId}) =>
      Future<List<Map<String, dynamic>>>.error(
        const SocketException('offline'),
      );

  @override
  Future<Map<String, dynamic>?> upsertReturning(Map<String, dynamic> row) =>
      Future<Map<String, dynamic>?>.error(const SocketException('offline'));

  @override
  Future<void> remove(String id) =>
      Future<void>.error(const SocketException('offline'));
}

/// Insights with no server: every call refuses at once, so Home's section
/// renders from the (empty) cache and a background refresh cannot write.
class _OfflineInsights implements InsightsRemote {
  @override
  Future<List<Map<String, dynamic>>> fetchPending(String userId) =>
      Future<List<Map<String, dynamic>>>.error(
        const SocketException('offline'),
      );

  @override
  Future<void> setStatus(String id, String status, {String? reason}) =>
      Future<void>.error(const SocketException('offline'));

  @override
  Future<String?> statusOf(String id) =>
      Future<String?>.error(const SocketException('offline'));

  @override
  Future<DateTime?> markSeen(String id, DateTime at) =>
      Future<DateTime?>.error(const SocketException('offline'));

  @override
  Future<void> remember({
    required String userId,
    required String scope,
    required String note,
    required double confidence,
  }) => Future<void>.error(const SocketException('offline'));
}

/// Refuses at once, for the same reason as the subscriptions stand-in.
class _OfflineNotifications implements NotificationsRemote {
  @override
  Future<List<Map<String, dynamic>>> fetchLatest({
    required String userId,
    required int limit,
  }) => Future<List<Map<String, dynamic>>>.error(
    const SocketException('offline'),
  );

  @override
  Future<Map<String, dynamic>?> markReadReturning(String id) =>
      Future<Map<String, dynamic>?>.error(const SocketException('offline'));

  @override
  Future<void> markAllRead({required String userId, required DateTime upTo}) =>
      Future<void>.error(const SocketException('offline'));

  @override
  Future<int> unreadUpTo({required String userId, required DateTime upTo}) =>
      Future<int>.error(const SocketException('offline'));
}

class _Subs extends SubscriptionsController {
  new(this.items);

  final List<Subscription> items;

  @override
  SubscriptionsView build() =>
      SubscriptionsView(items: items, today: DateTime.utc(2026, 9, 19));

  @override
  Future<void> refresh({bool force = false}) async {}
}

void main() {
  late Directory dir;
  late Box<String> documents;
  late Box<String> transactions;
  late Box<String> outboxBox;
  late Box<String> subsBox;
  late _OfflineRemote remote;

  final now = DateTime.parse('2026-09-19T12:00:00Z');

  setUpAll(() async {
    tz_data.initializeTimeZones();
  });

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('zad_home_test');
    Hive.init(dir.path);
    documents = await Hive.openBox<String>('documents');
    transactions = await Hive.openBox<String>('transactions');
    outboxBox = await Hive.openBox<String>('outbox');
    subsBox = await Hive.openBox<String>('subscriptions');
    remote = _OfflineRemote();

    await documents.put(
      'budget_state',
      jsonEncode(BudgetSnapshot.fromJson(_state()).toJson()),
    );
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  ProviderContainer containerWith({
    DateTime? at,
    List<Override>? household,
    List<Override> extra = const <Override>[],
  }) {
    late TransactionsRepository txns;
    final outbox = Outbox(
      box: outboxBox,
      send: (entry) => txns.sendQueued(entry),
      clock: () => now,
    );
    txns = TransactionsRepository(
      cache: transactions,
      remote: _FakeTransactionsRemote(),
      outbox: () => outbox,
      newId: () => 'txn',
      signedInUserId: () => 'user-1',
    );

    return ProviderContainer(
      overrides: [
        ...(household ?? quietHouseholdOverrides),
        // The home screen now carries the bank-access card, which reads the
        // documents box. A screen test that leaves it out is not testing the
        // app — localStoreProvider throws by design rather than opening boxes
        // lazily, so the omission surfaces here rather than on a device.
        localStoreProvider.overrideWithValue(
          ZadLocalStore(
            outbox: outboxBox,
            transactions: transactions,
            documents: documents,
            chat: documents,
            inventory: documents,
            shopping: documents,
            pharmacy: documents,
            subscriptions: subsBox,
            device: subsBox,
          ),
        ),
        nowProvider.overrideWithValue(() => at ?? now),
        transactionsRepositoryProvider.overrideWithValue(txns),
        insightsRepositoryProvider.overrideWithValue(
          InsightsRepository(
            cache: documents,
            remote: _OfflineInsights(),
            outbox: () => outbox,
            signedInUserId: () => 'user-1',
          ),
        ),
        notificationsRepositoryProvider.overrideWithValue(
          NotificationsRepository(
            cache: documents,
            remote: _OfflineNotifications(),
            outbox: () => outbox,
            signedInUserId: () => 'user-1',
          ),
        ),
        subscriptionsRepositoryProvider.overrideWithValue(
          SubscriptionsRepository(
            cache: subsBox,
            remote: _OfflineSubscriptions(),
            outbox: () => outbox,
            newId: () => 'sub',
            signedInUserId: () => 'user-1',
          ),
        ),
        settingsRepositoryProvider.overrideWithValue(
          SettingsRepository(
            cache: documents,
            remote: _FakeSettingsRemote(),
            outbox: () => outbox,
            signedInUserId: () => 'user-1',
            now: () => now,
          ),
        ),
        budgetRepositoryProvider.overrideWithValue(
          BudgetRepository(
            cache: documents,
            remote: remote,
            signedInUserId: () => 'user-1',
          ),
        ),
        ...extra,
      ],
    );
  }

  // Home's list is lazy, and the wallet card now sits under the companion
  // row, the modes and the market ticker — below an 800×600 test window.
  Future<void> pumpHome(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ZadTheme.light(),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: HomeScreen()),
          ),
        ),
      ),
    );
    // Every block enters through ZadAppearOnEntry, which draws from a timer
    // of at most 105ms (Kotlin's per-block delays) — frames, not a network
    // round trip.
    await tester.pump(Duration.zero);
    await tester.pump(const Duration(milliseconds: 120));
  }

  testWidgets('the cached figure is on screen in the first frame', (
    tester,
  ) async {
    final container = containerWith();
    addTearDown(container.dispose);

    // One pump. No pumpAndSettle, no awaiting anything — and the remote is
    // offline, so nothing on screen can have come from the network.
    await pumpHome(tester, container);

    expect(find.byType(ZadBalanceCard), findsOneWidget);
    // The cached number, marked "≈" because the offline refresh never
    // confirmed it — present either way, and never waited for.
    expect(find.text('≈ 3,620.5'), findsOneWidget);
    expect(find.text('المتاح في دورة الراتب'), findsOneWidget);
  });

  testWidgets(
    'the tasbih follows «النهارده في بيتك», rewards follow the chef',
    (tester) async {
      final chef = ZadSlots.homeChefSection;
      ZadSlots.homeChefSection = () =>
          const SizedBox(key: ValueKey<String>('chef'), height: 20);
      addTearDown(() => ZadSlots.homeChefSection = chef);
      final container = containerWith();
      addTearDown(container.dispose);

      await tester.binding.setSurfaceSize(const Size(412, 6000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ZadTheme.light(),
            home: const Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(body: HomeScreen()),
            ),
          ),
        ),
      );
      await tester.pump(Duration.zero);
      // Past every entrance slide, so positions are the settled ones.
      // (The timers fire in the first pump, the slides run in the second.)
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump(const Duration(milliseconds: 800));

      double top(Finder f) => tester.getTopLeft(f).dy;
      expect(find.byType(TasbihaHomeSlot), findsOneWidget);
      expect(
        top(find.byType(TasbihaHomeSlot)),
        greaterThan(top(find.byType(HomeTodayCard))),
      );
      final rewards = find.byKey(const ValueKey<String>('rewards-card'));
      expect(rewards, findsOneWidget);
      expect(
        top(rewards),
        greaterThan(top(find.byKey(const ValueKey('chef')))),
      );
      // The care bar sits under the money, above the day's card, and the one
      // native ad sits right before the chef, away from the reward buttons.
      expect(find.byType(HomeCareBar), findsOneWidget);
      expect(
        top(find.byType(HomeCareBar)),
        lessThan(top(find.byType(HomeTodayCard))),
      );
      expect(find.byType(ZadNativeAd), findsOneWidget);
      expect(
        top(find.byType(ZadNativeAd)),
        lessThanOrEqualTo(top(find.byKey(const ValueKey('chef')))),
      );
    },
  );

  HomeDayPhase? scenePhase(WidgetTester tester) {
    for (final p in tester.widgetList<CustomPaint>(find.byType(CustomPaint))) {
      final painter = p.painter;
      if (painter is ScaledScene && painter.inner is HomeWorldScene) {
        return (painter.inner as HomeWorldScene).phase;
      }
    }
    return null;
  }

  testWidgets('home is a world: noon sky, greeting, money line, empty day', (
    tester,
  ) async {
    final container = containerWith();
    addTearDown(container.dispose);

    await pumpHome(tester, container);

    // 12:00 UTC is 15:00 in the account's zone (Cairo): the noon sky.
    expect(scenePhase(tester), HomeDayPhase.noon);
    expect(find.textContaining('نهارك سعيد يا'), findsOneWidget);
    expect(find.textContaining('متاح'), findsWidgets);
    // Nothing short, no dose, no renewal: the card says so.
    expect(find.text('النهارده في بيتك'), findsOneWidget);
    expect(find.text('مفيش نواقص ولا جرعات ولا تجديدات قريبة'), findsOneWidget);
  });

  testWidgets('the sky follows the account zone: 23:00 is night', (
    tester,
  ) async {
    // 20:00 UTC is 23:00 in Cairo, whatever the device zone says.
    final container = containerWith(at: DateTime.parse('2026-09-19T20:00:00Z'));
    addTearDown(container.dispose);

    await pumpHome(tester, container);

    expect(scenePhase(tester), HomeDayPhase.night);
    expect(find.textContaining('ليلة هادية يا'), findsOneWidget);
  });

  test('the hours fall into the five skies', () {
    expect(homeDayPhaseOf(5), HomeDayPhase.dawn);
    expect(homeDayPhaseOf(9), HomeDayPhase.morning);
    expect(homeDayPhaseOf(13), HomeDayPhase.noon);
    expect(homeDayPhaseOf(17), HomeDayPhase.evening);
    expect(homeDayPhaseOf(23), HomeDayPhase.night);
    expect(homeDayPhaseOf(3), HomeDayPhase.night);
  });

  testWidgets('screenshot: the home world', (tester) async {
    await loadZadFonts();
    const milk = InventoryItem(
      id: '1',
      userId: 'u',
      itemName: 'لبن',
      quantity: 0,
    );
    const rice = InventoryItem(
      id: '2',
      userId: 'u',
      itemName: 'رز',
      quantity: 1,
    );
    const pills = Medicine(id: 'm', userId: 'u', name: 'فيتامين د');
    final container = containerWith(
      household: [
        pantryControllerProvider.overrideWith(
          () => QuietPantry(
            const PantryView(
              items: <InventoryItem>[milk, rice],
              shortages: <Shortage>[
                Shortage(item: milk, reason: ShortageReason.outOfStock),
                Shortage(item: rice, reason: ShortageReason.runningLow),
              ],
            ),
          ),
        ),
        pharmacyControllerProvider.overrideWith(
          () => QuietPharmacy(
            PharmacyView(
              medicines: const <Medicine>[pills],
              today: <DoseSlot>[
                DoseSlot(
                  medicine: pills,
                  time: const DoseTime(18, 0),
                  scheduledAt: DateTime.utc(2026, 9, 19, 15),
                ),
              ],
            ),
          ),
        ),
        ...quietHouseholdOverrides.skip(2),
      ],
      extra: [
        subscriptionsControllerProvider.overrideWith(
          () => _Subs(const <Subscription>[
            Subscription(
              id: 'n',
              userId: 'u',
              title: 'Netflix',
              amount: 199,
              dueDay: 22,
            ),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);
    tester.view
      ..physicalSize = const Size(860, 4400)
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ZadTheme.light(),
          locale: const Locale('ar'),
          localizationsDelegates: ZadL10n.localizationsDelegates,
          supportedLocales: ZadL10n.supportedLocales,
          home: const Scaffold(body: HomeScreen()),
        ),
      ),
    );
    await tester.pump(Duration.zero);
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 800));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../../build/screens/world_home.png'),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  }, skip: Platform.environment['ZAD_SCREENS'] != '1');

  testWidgets('the two small cards sit under the green one', (tester) async {
    final container = containerWith();
    addTearDown(container.dispose);

    await pumpHome(tester, container);

    expect(find.byType(HomeMetricsDuo), findsOneWidget);
    expect(find.text('معدل الصرف اليومي الآمن'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Text && (w.data == 'لحد القبض' || w.data == 'لحد آخر الشهر'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('home says how much of the spending it sees (٣.٤)', (
    tester,
  ) async {
    final container = containerWith();
    addTearDown(container.dispose);

    await pumpHome(tester, container);

    // Day 27 of 31, 3179.5 recorded against a confirmed 8000.
    expect(find.text('أنا شايف حوالي 50–60٪ من مصروفك'), findsOneWidget);
  });

  testWidgets('the coverage card opens «اقفل يومك» (٣.٢)', (tester) async {
    final container = containerWith();
    addTearDown(container.dispose);

    await pumpHome(tester, container);
    await tester.tap(find.text('أنا شايف حوالي 50–60٪ من مصروفك'));
    // Home never settles (the sky moves); the sheet is up in well under 1s.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('🌙 اقفل يومك'), findsOneWidget);
    expect(find.text('اربط البنك عشان أشوف لوحدي'), findsOneWidget);
  });

  testWidgets(
    '"خصم سريع" opens the quick expense sheet, send held till valid',
    (tester) async {
      final container = containerWith();
      addTearDown(container.dispose);

      await pumpHome(tester, container);
      await tester.tap(find.text('خصم سريع'));
      // An autofocused field: pumpAndSettle would wait on the cursor forever.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(QuickExpenseSheet), findsOneWidget);
      FilledButton send() => tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('إرسال'),
          matching: find.byWidgetPredicate((w) => w is FilledButton),
        ),
      );
      expect(send().onPressed, isNull, reason: 'nothing typed yet');

      await tester.enterText(find.byType(TextField).at(1), '0');
      await tester.pump();
      expect(send().onPressed, isNull, reason: 'a zero is not an expense');

      await tester.enterText(find.byType(TextField).at(1), '75');
      await tester.pump();
      expect(send().onPressed, isNull, reason: 'an amount with no name');

      await tester.enterText(find.byType(TextField).at(0), 'حلاقة');
      await tester.pump();
      expect(send().onPressed, isNotNull);
    },
  );

  testWidgets('the figure does not count up from zero on open', (tester) async {
    // Reading the balance should not mean watching it arrive. The count-up is
    // for a value that *changed*, not for one the device already had.
    final container = containerWith();
    addTearDown(container.dispose);

    await pumpHome(tester, container);

    expect(find.text('≈ 3,620.5'), findsOneWidget);
    expect(find.text('≈ 0'), findsNothing);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('a failing refresh marks the figure without hiding it', (
    tester,
  ) async {
    final container = containerWith();
    addTearDown(container.dispose);

    await pumpHome(tester, container);
    await tester.pump();

    expect(remote.calls, 1, reason: 'the screen never asked the server');
    // The number is still there. A failed refresh is a reason to say it is not
    // confirmed, never a reason to replace it with an error — so it reads
    // "≈", as Kotlin's unconfirmed figure does.
    expect(find.text('≈ 3,620.5'), findsOneWidget);
    expect(container.read(budgetControllerProvider).isStale, isTrue);
  });

  group('with nothing cached', () {
    // A nested setUp, not a flag set in the test body: the shared setUp has
    // already run by the time a body starts, and clearing the box from inside
    // one would be a disk write against the faked clock.
    setUp(() => documents.delete('budget_state'));

    testWidgets('shows a state, never a blank screen', (tester) async {
      final container = containerWith();
      addTearDown(container.dispose);

      await pumpHome(tester, container);

      expect(find.byType(ZadBalanceCard), findsNothing);
      // The remote here is offline, so the waiting state has already turned
      // into the one that says so — a state either way, never a blank.
      expect(find.text('مقدرتش أوصل للسيرفر'), findsOneWidget);
    });
  });

  group('with no confirmed limit', () {
    // The cache is rewritten here rather than in the test body. A Hive write
    // inside `testWidgets` runs against the faked clock and never completes —
    // the suite hangs instead of failing, which is the trap this file's header
    // warns about and which this group walked straight into once.
    setUp(() async {
      await documents.put(
        'budget_state',
        jsonEncode(BudgetSnapshot.fromJson(_stateWithNoBudget()).toJson()),
      );
    });

    testWidgets('tapping "no budget yet" opens the sheet that sets one', (
      tester,
    ) async {
      // The regression this exists for: `ZadBalanceCard` has always offered
      // `onSetBudget` and `HomeScreen` has always passed null, so the card
      // that asks for a budget was not tappable at all —
      // `ZadPressable` disables the gesture outright when its callback is
      // null, so there was not even a scale to say the tap had landed. A
      // customer with no confirmed limit had no way to set one anywhere in
      // the app.
      final container = containerWith();
      addTearDown(container.dispose);

      await pumpHome(tester, container);
      expect(
        find.text('قوللي ميزانيتك الشهرية، وأقدر أقولك المتاح ليك كل يوم.'),
        findsOneWidget,
      );

      await tester.tap(find.byType(ZadBalanceCard));
      // Pumped past the sheet's entrance rather than settled: the sheet
      // autofocuses its amount field and a blinking text cursor is an
      // animation that never ends, so `pumpAndSettle` times out on a sheet
      // that opened perfectly well.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(MonthlyLimitSheet), findsOneWidget);
      expect(find.text('تعديل الرصيد'), findsOneWidget);
    });
  });

  testWidgets('home offers no sign-out', (tester) async {
    final container = containerWith();
    addTearDown(container.dispose);

    await pumpHome(tester, container);

    // Sign-out lives inside settings, beside the warning about unsent
    // writes. One tap from the balance to "log out" put the most destructive
    // action on this screen next to the least destructive one.
    expect(find.byTooltip('اخرج من الحساب'), findsNothing);
    expect(find.textContaining('تسجيل الخروج'), findsNothing);
  });
}
