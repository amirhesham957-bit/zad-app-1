// Who is signed in, and what a sign-out is obliged to leave behind.
//
// The claim that matters here is a privacy one: after a sign-out, nothing of
// the previous account is readable on the device — including when the sign-out
// call itself failed, because gotrue has already dropped the session by then.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/data/local/boxes.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/data/sync/outbox.dart';
import 'package:zad/data/sync/outbox_entry.dart';
import 'package:zad/data/sync/outbox_runner.dart';
import 'package:zad/features/auth/application/session_controller.dart';
import 'package:zad/features/auth/data/auth_gateway.dart';
import 'package:zad/features/auth/domain/auth_failure.dart';

class _FakeGateway implements AuthGateway {
  new(this.userId);

  String? userId;
  AuthFailure? signOutFails;
  int signOuts = 0;
  final StreamController<String?> ids = StreamController<String?>.broadcast();

  @override
  String? get currentUserId => userId;

  @override
  Stream<String?> get userIdChanges => ids.stream;

  @override
  Future<void> signOut() async {
    signOuts++;
    // Mirrors gotrue: the local session is gone before the server is told, so
    // a throw here still means "signed out on this device".
    userId = null;
    if (signOutFails case final failure?) throw failure;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    userId = 'user-2';
  }

  @override
  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
    required String name,
  }) async => SignUpOutcome.signedIn;

  @override
  Future<void> sendPasswordReset(String email) async {}
}

void main() {
  late Box<String> documents;
  late Box<String> chatBox;
  late Box<String> transactions;
  late Box<String> outboxBox;
  late ZadLocalStore store;
  late _FakeGateway gateway;
  late ProviderContainer container;
  late StreamController<SyncTrigger> triggers;
  late OutboxRunner runner;

  setUp(() async {
    Hive.init('unused');
    documents = await Hive.openBox<String>('documents', bytes: Uint8List(0));
    transactions = await Hive.openBox<String>(
      'transactions',
      bytes: Uint8List(0),
    );
    outboxBox = await Hive.openBox<String>('outbox', bytes: Uint8List(0));
    chatBox = await Hive.openBox<String>('chat', bytes: Uint8List(0));
    store = ZadLocalStore(
      outbox: outboxBox,
      transactions: transactions,
      documents: documents,
      chat: chatBox,
    );

    await documents.put('budget_state', jsonEncode(<String, String>{'a': 'b'}));
    await transactions.put('txn-1', jsonEncode(<String, String>{'a': 'b'}));

    gateway = _FakeGateway('user-1');
    triggers = StreamController<SyncTrigger>.broadcast();
    container = ProviderContainer(
      overrides: [
        localStoreProvider.overrideWithValue(store),
        authGatewayProvider.overrideWithValue(gateway),
        // The real provider builds AppSyncTriggers, which subscribes to
        // connectivity_plus over a platform channel that no unit test has.
        outboxRunnerProvider.overrideWith((ref) {
          runner = OutboxRunner(
            outbox: ref.watch(outboxProvider),
            triggers: triggers.stream,
          );
          ref.onDispose(runner.dispose);
          return runner;
        }),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await triggers.close();
    await gateway.ids.close();
    // close, not deleteFromDisk: a memory box has no disk.
    await Hive.close();
  });

  test('the id is known on the first read, with nothing awaited', () {
    // No pump, no await: the gate must be able to decide on frame one, and a
    // StreamProvider here would have opened on AsyncLoading instead.
    expect(container.read(sessionControllerProvider), 'user-1');
  });

  test('nobody signed in reads as null', () {
    final empty = ProviderContainer(
      overrides: [
        localStoreProvider.overrideWithValue(store),
        authGatewayProvider.overrideWithValue(_FakeGateway(null)),
      ],
    );
    addTearDown(empty.dispose);

    expect(empty.read(sessionControllerProvider), isNull);
  });

  test('a session that ends elsewhere reaches the gate', () async {
    expect(container.read(sessionControllerProvider), 'user-1');

    gateway.ids.add(null);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(sessionControllerProvider), isNull);
  });

  test(
    'signing in drains the queue rather than waiting for the next tick',
    () async {
      final signedOut = _FakeGateway(null);
      var sent = 0;
      final counting = Outbox(box: outboxBox, send: (_) async => sent++);

      final empty = ProviderContainer(
        overrides: [
          localStoreProvider.overrideWithValue(store),
          authGatewayProvider.overrideWithValue(signedOut),
          // The real sender dispatches into the repositories, which this test
          // does not build. What is being pinned here is that a flush is asked
          // for at all, so the sender is the simplest one that can answer.
          outboxProvider.overrideWithValue(counting),
          outboxRunnerProvider.overrideWith((ref) {
            final r = OutboxRunner(
              outbox: ref.watch(outboxProvider),
              triggers: const Stream<SyncTrigger>.empty(),
            );
            ref.onDispose(r.dispose);
            return r;
          }),
        ],
      );
      addTearDown(() async {
        empty.dispose();
        await signedOut.ids.close();
      });

      // Build the runner and let its own startup flush finish first, so what
      // this measures is the sign-in and not the runner waking up.
      expect(empty.read(sessionControllerProvider), isNull);
      empty.read(outboxRunnerProvider);
      await pumpEventQueue();

      await counting.enqueue(
        id: 'txn-9',
        kind: OutboxKind.insertTransaction,
        payload: <String, dynamic>{'id': 'txn-9'},
      );
      expect(sent, 0, reason: 'nothing should have gone up while signed out');

      signedOut.ids.add('user-1');
      await pumpEventQueue();

      expect(empty.read(sessionControllerProvider), 'user-1');
      expect(
        sent,
        1,
        reason: 'the backlog moved on sign-in, not thirty seconds later',
      );
      expect(counting.entries(), isEmpty);
    },
  );

  group('signing out', () {
    test('empties the caches and keeps the unsent writes', () async {
      final outbox = container.read(outboxProvider);
      await outbox.enqueue(
        id: 'txn-9',
        kind: OutboxKind.insertTransaction,
        payload: <String, dynamic>{'id': 'txn-9'},
      );

      await container.read(sessionControllerProvider.notifier).signOut();

      expect(container.read(sessionControllerProvider), isNull);
      expect(documents.isEmpty, isTrue, reason: 'the budget was cached');
      expect(transactions.isEmpty, isTrue, reason: 'the rows were cached');
      expect(
        outbox.entries(),
        hasLength(1),
        reason: 'the customer was told these were saved; they are not a cache',
      );
    });

    test(
      'empties the caches even when the call to the server failed',
      () async {
        gateway.signOutFails = const AuthFailure(AuthFailureKind.offline);

        await expectLater(
          container.read(sessionControllerProvider.notifier).signOut(),
          throwsA(isA<AuthFailure>()),
        );

        // The session is gone locally whatever the server heard, so leaving the
        // previous account's figures on screen would be the worst possible
        // reading of this error.
        expect(documents.isEmpty, isTrue);
        expect(transactions.isEmpty, isTrue);
        expect(container.read(sessionControllerProvider), isNull);
      },
    );

    test(
      'counts the unsent writes so the screen can warn before it asks',
      () async {
        final session = container.read(sessionControllerProvider.notifier);
        expect(session.pendingWriteCount, 0);

        await container
            .read(outboxProvider)
            .enqueue(
              id: 'txn-9',
              kind: OutboxKind.insertTransaction,
              payload: <String, dynamic>{'id': 'txn-9'},
            );

        expect(session.pendingWriteCount, 1);
      },
    );
  });
}
