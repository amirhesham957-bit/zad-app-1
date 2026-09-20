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
import 'package:zad/features/proposals/data/proposals_repository.dart';
import 'package:zad/features/proposals/domain/transaction_proposal.dart';
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

void main() {
  late Box<String> documents;
  late Box<String> chatBox;
  late Box<String> transactions;
  late Box<String> outboxBox;

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
    chatBox = await Hive.openBox<String>('chat', bytes: Uint8List(0));
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

  testWidgets('with a session, the shell opens straight away', (tester) async {
    final container = containerFor('user-1');
    addTearDown(container.dispose);

    await pumpGate(tester, container);
    await tester.pump(Duration.zero);

    expect(find.byType(ZadShell), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });
}
