// Which app opens.
//
// A fresh install has no session, and every repository in this app refuses to
// act without one — the transactions repo throws, the budget repo returns null,
// the drain does not even read its inbox. So landing on the shell while signed
// out is not a cosmetic mistake; it is an app where nothing works and nothing
// says why.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:zad/app/auth_gate.dart';
import 'package:zad/app/zad_shell.dart';
import 'package:zad/data/local/boxes.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/data/sync/outbox.dart';
import 'package:zad/design/zad_theme.dart';
import 'package:zad/features/auth/data/auth_gateway.dart';
import 'package:zad/features/auth/presentation/login_screen.dart';
import 'package:zad/features/budget/data/budget_repository.dart';
import 'package:zad/features/budget/domain/budget_snapshot.dart';
import 'package:zad/features/market/presentation/market_selection_screen.dart';
import 'package:zad/features/onboarding/presentation/intro_screen.dart';
import 'package:zad/features/proposals/data/proposals_repository.dart';
import 'package:zad/features/proposals/domain/transaction_proposal.dart';
import 'package:zad/features/settings/data/settings_repository.dart';
import 'package:zad/features/settings/domain/account_settings.dart';
import 'package:zad/features/subscriptions/data/subscriptions_remote.dart';
import 'package:zad/features/subscriptions/data/subscriptions_repository.dart';
import 'package:zad/features/transactions/data/transactions_remote.dart';
import 'package:zad/features/transactions/data/transactions_repository.dart';

class _Gateway implements AuthGateway {
  new(this.userId);

  final String? userId;

  @override
  String? get currentUserId => userId;

  @override
  Stream<String?> get userIdChanges => const Stream<String?>.empty();

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
    required String name,
  }) async => SignUpOutcome.signedIn;

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> signOut() async {}
}

class _Offline implements TransactionsRemote {
  @override
  Future<List<Map<String, dynamic>>> fetchPeriod({
    required String userId,
    required DateTime startsAt,
    required DateTime endsAt,
  }) => Future<List<Map<String, dynamic>>>.error(
    const SocketException('offline'),
  );

  @override
  Future<Map<String, dynamic>?> upsertReturning(Map<String, dynamic> row) =>
      Future<Map<String, dynamic>?>.error(const SocketException('offline'));
}

class _OfflineBudget implements BudgetRemote {
  @override
  Future<Map<String, dynamic>> fetch({
    required String userId,
    required String timeZone,
  }) => Future<Map<String, dynamic>>.error(const SocketException('offline'));
}

/// Refuses at once. A widget test cannot let a background refresh reach a
/// Hive write — under the fake clock that write never completes.
class _OfflineSettings implements SettingsRemote {
  int fetches = 0;

  @override
  Future<Map<String, dynamic>?> fetch({required String userId}) {
    fetches++;
    return Future<Map<String, dynamic>?>.error(
      const SocketException('offline'),
    );
  }

  @override
  Future<Map<String, dynamic>?> upsertReturning(Map<String, dynamic> row) =>
      Future<Map<String, dynamic>?>.error(const SocketException('offline'));
}

class _OfflineProposals implements ProposalsRemote {
  @override
  Future<List<Map<String, dynamic>>> fetchOpen({required String userId}) =>
      Future<List<Map<String, dynamic>>>.error(
        const SocketException('offline'),
      );

  @override
  Future<Map<String, dynamic>> resolve({
    required String proposalId,
    required ProposalDecision decision,
  }) => Future<Map<String, dynamic>>.error(const SocketException('offline'));
}

Map<String, dynamic> _state() => <String, dynamic>{
  'user_id': 'user-1',
  'currency': 'ج.م',
  'timezone': 'Africa/Cairo',
  'spent': 0,
  'income': 0,
  'committed': 0,
  'days_left': 5,
  'cycle_length_days': 31,
  'threat': 'SAFE',
  'unverified_count': 0,
  'computed_at': '2026-09-20T12:00:00Z',
  'available': 1000,
  'remaining': 1000,
  'opening_balance': 8000,
  'limit_confirmed': true,
  'cycle_start': '2026-08-25',
  'cycle_end': '2026-09-25',
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

void main() {
  late Box<String> documents;
  late Box<String> chatBox;
  late Box<String> transactions;
  late Box<String> outboxBox;
  late Box<String> subsBox;
  late Box<String> deviceBox;
  late _OfflineSettings settingsRemote;

  final now = DateTime.parse('2026-09-20T12:00:00Z');

  setUpAll(tz_data.initializeTimeZones);

  setUp(() async {
    Hive.init('unused');
    documents = await Hive.openBox<String>('documents', bytes: Uint8List(0));
    transactions = await Hive.openBox<String>(
      'transactions',
      bytes: Uint8List(0),
    );
    outboxBox = await Hive.openBox<String>('outbox', bytes: Uint8List(0));
    subsBox = await Hive.openBox<String>('subscriptions', bytes: Uint8List(0));
    deviceBox = await Hive.openBox<String>('device', bytes: Uint8List(0));
    // A phone that has already been through the introduction — what every
    // case outside the introduction's own group is about.
    await deviceBox.put('intro_seen', 'true');
    chatBox = await Hive.openBox<String>('chat', bytes: Uint8List(0));
    settingsRemote = _OfflineSettings();
    await documents.put(
      'budget_state',
      jsonEncode(BudgetSnapshot.fromJson(_state()).toJson()),
    );
  });

  tearDown(Hive.close);

  ProviderContainer containerFor(String? userId) {
    late TransactionsRepository txns;
    final outbox = Outbox(
      box: outboxBox,
      send: (entry) => txns.sendQueued(entry),
      clock: () => now,
    );
    txns = TransactionsRepository(
      cache: transactions,
      remote: _Offline(),
      outbox: () => outbox,
      newId: () => 'txn',
      signedInUserId: () => userId,
    );

    return ProviderContainer(
      overrides: [
        authGatewayProvider.overrideWithValue(_Gateway(userId)),
        signedInUserIdProvider.overrideWithValue(() => userId),
        nowProvider.overrideWithValue(() => now),
        localStoreProvider.overrideWithValue(
          ZadLocalStore(
            outbox: outboxBox,
            transactions: transactions,
            documents: documents,
            chat: chatBox,
            inventory: chatBox,
            shopping: chatBox,
            pharmacy: chatBox,
            subscriptions: subsBox,
            device: deviceBox,
          ),
        ),
        transactionsRepositoryProvider.overrideWithValue(txns),
        budgetRepositoryProvider.overrideWithValue(
          BudgetRepository(
            cache: documents,
            remote: _OfflineBudget(),
            signedInUserId: () => userId,
          ),
        ),
        subscriptionsRepositoryProvider.overrideWithValue(
          SubscriptionsRepository(
            cache: subsBox,
            remote: _OfflineSubscriptions(),
            outbox: () => outbox,
            newId: () => 'sub',
            signedInUserId: () => userId,
          ),
        ),
        settingsRepositoryProvider.overrideWithValue(
          SettingsRepository(
            cache: documents,
            remote: settingsRemote,
            outbox: () => outbox,
            signedInUserId: () => userId,
            now: () => now,
          ),
        ),
        proposalsRepositoryProvider.overrideWithValue(
          ProposalsRepository(
            cache: documents,
            remote: _OfflineProposals(),
            signedInUserId: () => userId,
          ),
        ),
      ],
    );
  }

  Future<void> pumpGate(WidgetTester tester, ProviderContainer container) =>
      tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ZadTheme.light(),
            locale: const Locale('ar'),
            home: const Directionality(
              textDirection: TextDirection.rtl,
              child: ZadAuthGate(),
            ),
          ),
        ),
      );

  testWidgets(
    'with no session, the first frame is the login screen — not a spinner '
    'and not an empty shell',
    (tester) async {
      final container = containerFor(null);
      addTearDown(container.dispose);

      await pumpGate(tester, container);
      // One pump. The decision is made from the session already restored off
      // disk, so it does not get to arrive a frame later.
      await tester.pump(Duration.zero);

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(ZadShell), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  /// Writes a settings row into the cache, as an earlier read would have.
  Future<void> seedSettings(AccountSettings settings) =>
      documents.put('account_settings', jsonEncode(settings.toJson()));

  group('an account whose market is known', () {
    setUp(
      () => seedSettings(const AccountSettings(country: 'EG', currency: 'EGP')),
    );

    testWidgets('opens straight onto the shell, and asks nobody', (
      tester,
    ) async {
      final container = containerFor('user-1');
      addTearDown(container.dispose);

      await pumpGate(tester, container);
      await tester.pump(Duration.zero);

      expect(find.byType(ZadShell), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.byType(MarketSelectionScreen), findsNothing);
      expect(
        settingsRemote.fetches,
        0,
        reason: 'a returning customer waited on a settings read',
      );
    });
  });

  group('an account the server said has no market', () {
    setUp(() => seedSettings(const AccountSettings()));

    testWidgets('is asked in the first frame, and still asked offline', (
      tester,
    ) async {
      final container = containerFor('user-1');
      addTearDown(container.dispose);

      await pumpGate(tester, container);
      await tester.pump(Duration.zero);
      expect(find.byType(MarketSelectionScreen), findsOneWidget);

      // The re-check fails. The device already holds the server's "none",
      // and a dead network is no reason to believe that changed.
      await tester.pump(const Duration(milliseconds: 400));
      expect(settingsRemote.fetches, 1);
      expect(find.byType(MarketSelectionScreen), findsOneWidget);
      expect(find.byType(ZadShell), findsNothing);
    });
  });

  testWidgets(
    'a device that has never read the account checks first, and opens the '
    'app rather than asking again when it cannot',
    (tester) async {
      final container = containerFor('user-1');
      addTearDown(container.dispose);

      // The first frame: nothing on the device says either way, so neither
      // the picker nor the shell — the one short wait there is.
      await pumpGate(tester, container);
      expect(find.text('بنجهّز حسابك…'), findsOneWidget);
      expect(find.byType(MarketSelectionScreen), findsNothing);
      expect(find.byType(ZadShell), findsNothing);

      await tester.pump(const Duration(milliseconds: 400));
      expect(settingsRemote.fetches, 1);
      // Asking would risk making somebody who already chose choose again —
      // the Kotlin bug this gate is built around.
      expect(find.byType(ZadShell), findsOneWidget);
      expect(find.byType(MarketSelectionScreen), findsNothing);
    },
  );

  group('a phone that has never seen the introduction', () {
    setUp(() => deviceBox.delete('intro_seen'));

    testWidgets('signed out, it opens on the introduction', (tester) async {
      final container = containerFor(null);
      addTearDown(container.dispose);

      await pumpGate(tester, container);
      expect(find.byType(IntroScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('"عندي حساب" goes straight to signing in', (tester) async {
      final container = containerFor(null);
      addTearDown(container.dispose);

      await pumpGate(tester, container);
      await tester.tap(find.text('عندي حساب'));
      await tester.pump();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('اسمك'), findsNothing, reason: 'sign-in has no name');
    });

    testWidgets('"اعمل حساب جديد" opens the form in sign-up mode', (
      tester,
    ) async {
      final container = containerFor(null);
      addTearDown(container.dispose);

      await pumpGate(tester, container);
      await tester.tap(find.text('اعمل حساب جديد'));
      await tester.pump();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('اسمك'), findsOneWidget);
    });
  });

  group('a signed-in customer on a phone that never saw it', () {
    setUp(() async {
      await deviceBox.delete('intro_seen');
      await seedSettings(const AccountSettings(country: 'EG', currency: 'EGP'));
    });

    testWidgets('is never shown the introduction', (tester) async {
      final container = containerFor('user-1');
      addTearDown(container.dispose);

      await pumpGate(tester, container);
      await tester.pump(Duration.zero);
      expect(find.byType(IntroScreen), findsNothing);
      expect(find.byType(ZadShell), findsOneWidget);
    });
  });
}
