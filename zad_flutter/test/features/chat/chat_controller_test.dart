// The conversation, and the two claims it must not make.
//
// The first is about time. What the customer typed is theirs and is already
// saved, so it is on screen before a byte goes out — a composer that waits for
// the server loses the text on a bad connection and makes a slow turn look
// like a dropped one. These drive the stream by hand to prove the message is
// there while nothing has arrived.
//
// The second is about who wrote what. The agent's tools run on the server
// inside the turn; `executed` is a receipt for writes that already happened.
// Replaying them through the repositories would double every row the agent
// records, so the controller refreshes the screens instead — and the test that
// matters is the one asserting no transaction was written locally.

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/core/period/account_time_zone.dart';
import 'package:zad/data/local/boxes.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/data/sync/outbox.dart';
import 'package:zad/features/budget/data/budget_repository.dart';
import 'package:zad/features/chat/application/chat_controller.dart';
import 'package:zad/features/chat/data/agent_remote.dart';
import 'package:zad/features/chat/data/chat_repository.dart';
import 'package:zad/features/chat/domain/agent_turn.dart';
import 'package:zad/features/chat/domain/chat_message.dart';
import 'package:zad/features/transactions/data/transactions_remote.dart';
import 'package:zad/features/transactions/data/transactions_repository.dart';

class _FakeAgent implements AgentRemote {
  /// Driven by the test, so a turn can be observed mid-flight.
  StreamController<AgentEvent>? live;

  List<AgentHistoryEntry>? sentHistory;
  String? sentMessage;

  /// How many turns have been opened.
  int turns = 0;

  AgentExecuted confirmation = const AgentExecuted(
    tool: 'log_transaction',
    summary: 'اتسجلت',
  );
  Exception? confirmFailsWith;
  int confirms = 0;

  @override
  Stream<AgentEvent> turn({
    required String message,
    required List<AgentHistoryEntry> history,
    bool voiceMode = false,
  }) {
    turns++;
    sentMessage = message;
    sentHistory = history;
    return (live = StreamController<AgentEvent>()).stream;
  }

  @override
  Future<AgentExecuted> confirm({
    required String tool,
    required Map<String, dynamic> input,
  }) async {
    confirms++;
    if (confirmFailsWith case final e?) throw e;
    return confirmation;
  }
}

class _CountingBudget implements BudgetRemote {
  int fetches = 0;

  @override
  Future<Map<String, dynamic>> fetch({
    required String userId,
    required String timeZone,
  }) {
    fetches++;
    return Future<Map<String, dynamic>>.error(const SocketException('offline'));
  }
}

class _NoTransactions implements TransactionsRemote {
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

void main() {
  late Directory dir;
  late Box<String> documents;
  late Box<String> transactions;
  late Box<String> outboxBox;
  late Box<String> chat;
  late _FakeAgent agent;
  late _CountingBudget budget;

  final now = DateTime.parse('2026-09-20T09:00:00Z');
  var ids = 0;
  // Box names are unique per test. `Hive.deleteFromDisk()` leaves the closed
  // handles in Hive's own registry, so reopening the same name in the next
  // test hands back a box that is already closed — which surfaces as
  // "HiveError: Box has already been closed" from whichever line touches it
  // first, several frames away from the cause.
  var run = 0;

  setUp(() async {
    run++;
    dir = await Directory.systemTemp.createTemp('zad_chat_test');
    Hive.init(dir.path);
    documents = await Hive.openBox<String>('documents$run');
    transactions = await Hive.openBox<String>('transactions$run');
    outboxBox = await Hive.openBox<String>('outbox$run');
    chat = await Hive.openBox<String>('chat$run');
    agent = _FakeAgent();
    budget = _CountingBudget();
    ids = 0;
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
      remote: _NoTransactions(),
      outbox: () => outbox,
      newId: () => 'txn-1',
      signedInUserId: () => 'user-1',
    );

    return ProviderContainer(
      overrides: [
        localStoreProvider.overrideWithValue(
          ZadLocalStore(
            outbox: outboxBox,
            transactions: transactions,
            documents: documents,
            chat: chat,
            inventory: chat,
            shopping: chat,
            pharmacy: chat,
            subscriptions: chat,
            device: chat,
          ),
        ),
        nowProvider.overrideWithValue(() => now),
        signedInUserIdProvider.overrideWithValue(() => 'user-1'),
        serverTimeZoneArgumentProvider.overrideWithValue(() => ''),
        transactionsRepositoryProvider.overrideWithValue(txns),
        agentRemoteProvider.overrideWithValue(agent),
        chatRepositoryProvider.overrideWithValue(
          ChatRepository(box: chat, newId: () => 'm${ids++}'),
        ),
        budgetRepositoryProvider.overrideWithValue(
          BudgetRepository(
            cache: documents,
            remote: budget,
            signedInUserId: () => 'user-1',
          ),
        ),
      ],
    );
  }

  /// Pumps the event loop until [ready], instead of guessing how many
  /// microtasks a Hive write takes.
  Future<void> until(bool Function() ready) async {
    for (var i = 0; i < 200 && !ready(); i++) {
      await Future<void>.delayed(Duration.zero);
    }
    if (!ready()) throw StateError('condition never became true');
  }

  /// A turn that answers in one JSON frame — the path every tool turn takes.
  AgentDone done({
    String reply = 'تمام.',
    List<AgentExecuted> executed = const <AgentExecuted>[],
    List<AgentProposal> proposals = const <AgentProposal>[],
    String? specialist,
  }) => AgentDone(
    AgentTurn(
      reply: reply,
      executed: executed,
      proposals: proposals,
      specialist: specialist,
    ),
  );

  group('the message is on screen before the server answers', () {
    test('the customer text is in state and in the box immediately', () async {
      final container = containerWith();
      addTearDown(container.dispose);
      final controller = container.read(chatControllerProvider.notifier);

      // Not awaited: the turn is still open, which is exactly the moment
      // under test.
      // Not awaited, and not pumped either: the state update happens before
      // `send` reaches its first `await`, so the message is on screen in the
      // same turn the customer pressed the button. A delay here would hide
      // exactly the property under test.
      final pending = controller.send('صرفت ٥٠ قهوة');

      final view = container.read(chatControllerProvider);
      expect(view.messages.first.text, 'صرفت ٥٠ قهوة');
      expect(view.messages.first.isUser, isTrue);
      expect(view.isAwaitingReply, isTrue);
      // And a place for the reply to land, so the wait has a shape.
      expect(view.messages.last.isUser, isFalse);
      expect(view.messages.last.isStreaming, isTrue);
      // Saved, not merely displayed.
      expect(
        container.read(chatRepositoryProvider).all().first.text,
        'صرفت ٥٠ قهوة',
      );

      await until(() => agent.live?.isClosed == false);
      agent.live!.add(done());
      await agent.live!.close();
      await pending;
    });

    test('an empty message is not sent', () async {
      final container = containerWith();
      addTearDown(container.dispose);

      await container.read(chatControllerProvider.notifier).send('   ');

      expect(container.read(chatControllerProvider).messages, isEmpty);
      expect(agent.sentMessage, isNull);
    });
  });

  group('receiving a reply', () {
    test('chunks accumulate into the bubble', () async {
      final container = containerWith();
      addTearDown(container.dispose);
      final controller = container.read(chatControllerProvider.notifier);

      final pending = controller.send('عامل إيه؟');
      await until(() => agent.live?.isClosed == false);

      agent.live!.add(const AgentChunk('أهلاً '));
      await until(
        () => container
            .read(chatControllerProvider)
            .messages
            .last
            .text
            .isNotEmpty,
      );
      expect(
        container.read(chatControllerProvider).messages.last.text,
        'أهلاً ',
      );

      agent.live!.add(const AgentChunk('بيك'));
      await until(
        () => container
            .read(chatControllerProvider)
            .messages
            .last
            .text
            .isNotEmpty,
      );
      expect(
        container.read(chatControllerProvider).messages.last.text,
        'أهلاً بيك',
      );

      agent.live!.add(done(reply: 'أهلاً بيك'));
      await agent.live!.close();
      await pending;

      final last = container.read(chatControllerProvider).messages.last;
      expect(last.status, ChatStatus.done);
      expect(container.read(chatControllerProvider).isAwaitingReply, isFalse);
    });

    test('a JSON-only turn still lands — that is every tool turn', () async {
      // The server sends SSE only for a long, clean, tool-free reply. Anything
      // that ran a tool comes back as one JSON object with no chunks at all,
      // and a client built only for the stream would show an empty bubble on
      // exactly the turns that did something.
      final container = containerWith();
      addTearDown(container.dispose);
      final controller = container.read(chatControllerProvider.notifier);

      final pending = controller.send('سجل ٥٠ قهوة');
      await until(() => agent.live?.isClosed == false);
      agent.live!.add(
        done(
          reply: 'سجلتها.',
          executed: const <AgentExecuted>[
            AgentExecuted(tool: 'log_transaction', summary: 'مصروف ٥٠'),
          ],
        ),
      );
      await agent.live!.close();
      await pending;

      final last = container.read(chatControllerProvider).messages.last;
      expect(last.text, 'سجلتها.');
      expect(last.executed.single.summary, 'مصروف ٥٠');
    });

    test(
      'the history sent is what was said before, not this message',
      () async {
        final container = containerWith();
        addTearDown(container.dispose);
        final controller = container.read(chatControllerProvider.notifier);

        var pending = controller.send('الأولى');
        await until(() => agent.live?.isClosed == false);
        agent.live!.add(done(reply: 'رد الأولى'));
        await agent.live!.close();
        await pending;

        pending = controller.send('التانية');
        await until(() => agent.live?.isClosed == false);

        expect(agent.sentMessage, 'التانية');
        expect(agent.sentHistory, hasLength(2));
        expect(agent.sentHistory!.first.role, 'user');
        expect(agent.sentHistory!.first.text, 'الأولى');
        expect(agent.sentHistory!.last.role, 'assistant');

        agent.live!.add(done());
        await agent.live!.close();
        await pending;
      },
    );
  });

  group('a turn that did not arrive', () {
    test('keeps the words, marks them, and drops the empty bubble', () async {
      final container = containerWith();
      addTearDown(container.dispose);
      final controller = container.read(chatControllerProvider.notifier);

      final pending = controller.send('سؤال');
      await until(() => agent.live?.isClosed == false);
      agent.live!.addError(const SocketException('offline'));
      await agent.live!.close();
      await pending;

      final view = container.read(chatControllerProvider);
      expect(view.messages, hasLength(1), reason: 'the blank reply is gone');
      expect(view.messages.single.text, 'سؤال');
      expect(view.messages.single.status, ChatStatus.failed);
      expect(view.isAwaitingReply, isFalse);
      expect(view.error, isNotNull);
    });

    test('an empty turn reads as a failure, not as an empty bubble', () async {
      // A reply with no text, no execution and no proposal is, from the
      // customer's side, the same as the agent having fallen over.
      final container = containerWith();
      addTearDown(container.dispose);
      final controller = container.read(chatControllerProvider.notifier);

      final pending = controller.send('سؤال');
      await until(() => agent.live?.isClosed == false);
      agent.live!.add(done(reply: ''));
      await agent.live!.close();
      await pending;

      final view = container.read(chatControllerProvider);
      expect(view.messages.single.status, ChatStatus.failed);
    });

    test('retry resends without the customer retyping', () async {
      final container = containerWith();
      addTearDown(container.dispose);
      final controller = container.read(chatControllerProvider.notifier);

      var pending = controller.send('سؤال');
      await until(() => agent.live?.isClosed == false);
      agent.live!.addError(const SocketException('offline'));
      await agent.live!.close();
      await pending;

      final failedId = container
          .read(chatControllerProvider)
          .messages
          .single
          .id;
      pending = controller.retry(failedId);
      await until(() => agent.live?.isClosed == false);

      expect(agent.sentMessage, 'سؤال');
      agent.live!.add(done(reply: 'أهلاً'));
      await agent.live!.close();
      await pending;

      final view = container.read(chatControllerProvider);
      expect(view.messages.first.status, ChatStatus.done);
      // One question, not two.
      expect(view.messages.where((m) => m.isUser), hasLength(1));
    });
  });

  group('tools the server already ran', () {
    test('are not replayed through the repositories', () async {
      // The write happened inside the turn. Recording it again here would
      // double every transaction the agent logs.
      final container = containerWith();
      addTearDown(container.dispose);
      final controller = container.read(chatControllerProvider.notifier);

      final pending = controller.send('سجل ٥٠ قهوة');
      await until(() => agent.live?.isClosed == false);
      agent.live!.add(
        done(
          executed: const <AgentExecuted>[
            AgentExecuted(tool: 'log_transaction', summary: 'مصروف ٥٠'),
          ],
        ),
      );
      await agent.live!.close();
      await pending;

      expect(
        container.read(transactionsRepositoryProvider).allCached(),
        isEmpty,
      );
      expect(outboxBox.values, isEmpty);
    });

    test('a money tool makes the budget ask the server again', () async {
      final container = containerWith();
      addTearDown(container.dispose);
      container.read(chatControllerProvider);
      final before = budget.fetches;

      final pending = container
          .read(chatControllerProvider.notifier)
          .send('سجل ٥٠ قهوة');
      await until(() => agent.live?.isClosed == false);
      agent.live!.add(
        done(
          executed: const <AgentExecuted>[
            AgentExecuted(tool: 'log_transaction', summary: 'مصروف ٥٠'),
          ],
        ),
      );
      await agent.live!.close();
      await pending;
      await Future<void>.delayed(Duration.zero);

      expect(budget.fetches, greaterThan(before));
    });

    test('a reply that touched nothing leaves the budget alone', () async {
      final container = containerWith();
      addTearDown(container.dispose);
      container.read(chatControllerProvider);
      await Future<void>.delayed(Duration.zero);
      final before = budget.fetches;

      final pending = container
          .read(chatControllerProvider.notifier)
          .send('عامل إيه؟');
      await until(() => agent.live?.isClosed == false);
      agent.live!.add(done(reply: 'تمام الحمد لله.'));
      await agent.live!.close();
      await pending;
      await Future<void>.delayed(Duration.zero);

      expect(budget.fetches, before);
    });
  });

  group('a proposal is a question, not a write', () {
    test('confirming asks the server and swaps it for a receipt', () async {
      final container = containerWith();
      addTearDown(container.dispose);
      final controller = container.read(chatControllerProvider.notifier);

      final pending = controller.send('اشتريت عيش بـ١٠');
      await until(() => agent.live?.isClosed == false);
      agent.live!.add(
        done(
          reply: 'أسجلها؟',
          proposals: const <AgentProposal>[
            AgentProposal(tool: 'log_transaction', summary: 'مصروف ١٠ عيش'),
          ],
        ),
      );
      await agent.live!.close();
      await pending;

      final message = container.read(chatControllerProvider).messages.last;
      expect(message.proposals, hasLength(1));

      expect(
        await controller.confirm(message.id, message.proposals.single),
        isTrue,
      );

      final after = container.read(chatControllerProvider).messages.last;
      expect(agent.confirms, 1);
      expect(after.proposals, isEmpty, reason: 'it was answered');
      expect(after.executed.single.summary, 'اتسجلت');
      // Still the server's write, not this client's.
      expect(
        container.read(transactionsRepositoryProvider).allCached(),
        isEmpty,
      );
    });

    test('a refusal leaves the proposal answered, not pending', () async {
      agent.confirmation = const AgentExecuted(
        tool: 'log_transaction',
        summary: 'مرفوض: مبلغ غير معقول',
        ok: false,
      );
      final container = containerWith();
      addTearDown(container.dispose);
      final controller = container.read(chatControllerProvider.notifier);

      final pending = controller.send('سجل مليون');
      await until(() => agent.live?.isClosed == false);
      agent.live!.add(
        done(
          proposals: const <AgentProposal>[
            AgentProposal(tool: 'log_transaction', summary: 'مصروف مليون'),
          ],
        ),
      );
      await agent.live!.close();
      await pending;

      final message = container.read(chatControllerProvider).messages.last;
      expect(
        await controller.confirm(message.id, message.proposals.single),
        isFalse,
      );

      final after = container.read(chatControllerProvider).messages.last;
      expect(after.proposals, isEmpty);
      expect(after.executed.single.ok, isFalse);
    });
  });
}
