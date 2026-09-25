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
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:zad/data/local/boxes.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/data/sync/outbox.dart';
import 'package:zad/design/components/zad_balance_card.dart';
import 'package:zad/design/zad_theme.dart';
import 'package:zad/features/budget/application/budget_controller.dart';
import 'package:zad/features/budget/data/budget_repository.dart';
import 'package:zad/features/budget/domain/budget_snapshot.dart';
import 'package:zad/features/home/presentation/home_screen.dart';
import 'package:zad/features/home/presentation/metrics_duo.dart';
import 'package:zad/features/insights/data/insights_repository.dart';
import 'package:zad/features/notifications/data/notifications_remote.dart';
import 'package:zad/features/notifications/data/notifications_repository.dart';
import 'package:zad/features/settings/data/settings_repository.dart';
import 'package:zad/features/settings/presentation/monthly_limit_sheet.dart';
import 'package:zad/features/subscriptions/data/subscriptions_remote.dart';
import 'package:zad/features/subscriptions/data/subscriptions_repository.dart';
import 'package:zad/features/transactions/data/transactions_remote.dart';
import 'package:zad/features/transactions/data/transactions_repository.dart';
import 'package:zad/features/transactions/presentation/quick_expense_sheet.dart';

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
    // The Lucide family has to be registered under its package-qualified name
    // or the empty state's glyph is a tofu box and Flutter logs a missing font
    // on every frame.
    final lucide = FontLoader('packages/lucide_icons_flutter/Lucide')
      ..addFont(
        rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
      );
    await lucide.load();
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

  ProviderContainer containerWith() {
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
        ...quietHouseholdOverrides,
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
        nowProvider.overrideWithValue(() => now),
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
      ],
    );
  }

  Future<void> pumpHome(WidgetTester tester, ProviderContainer container) =>
      tester.pumpWidget(
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

  testWidgets('the cached figure is on screen in the first frame', (
    tester,
  ) async {
    final container = containerWith();
    addTearDown(container.dispose);

    // One pump. No pumpAndSettle, no awaiting anything — and the remote is
    // offline, so nothing on screen can have come from the network.
    await pumpHome(tester, container);

    expect(find.byType(ZadBalanceCard), findsOneWidget);
    expect(find.text('3,620.5'), findsOneWidget);
    expect(find.text('المتاح في دورة الراتب'), findsOneWidget);
  });

  testWidgets('the two small cards sit under the green one', (tester) async {
    final container = containerWith();
    addTearDown(container.dispose);

    await pumpHome(tester, container);

    expect(find.byType(HomeMetricsDuo), findsOneWidget);
    expect(find.text('معدل الصرف اليومي الآمن'), findsOneWidget);
    expect(find.text('يوم متبقي'), findsOneWidget);
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

      await tester.enterText(find.byType(TextField).at(2), '0');
      await tester.pump();
      expect(send().onPressed, isNull, reason: 'a zero is not an expense');

      await tester.enterText(find.byType(TextField).at(2), '75');
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

    expect(find.text('3,620.5'), findsOneWidget);
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
      expect(find.text('بنجهّز ميزانيتك'), findsOneWidget);
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

  testWidgets('the app bar opens settings rather than signing out', (
    tester,
  ) async {
    final container = containerWith();
    addTearDown(container.dispose);

    await pumpHome(tester, container);

    // Sign-out lives inside settings now, beside the warning about unsent
    // writes. One tap from the balance to "log out" put the most destructive
    // action on this screen next to the least destructive one.
    expect(find.byTooltip('الإعدادات'), findsOneWidget);
    expect(find.byTooltip('اخرج من الحساب'), findsNothing);
  });
}
