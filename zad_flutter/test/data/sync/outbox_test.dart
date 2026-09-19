// The outbox is what makes a write survive being offline, so what it does with
// a failure matters more than what it does with a success. These tests pin the
// three answers it can give — retry, give up, or stop and wait for a session —
// and the two properties that keep a retry safe: order, and idempotency.

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/data/sync/outbox.dart';
import 'package:zad/data/sync/outbox_entry.dart';
import 'package:zad/data/sync/sync_failure.dart';

void main() {
  late Directory dir;
  late Box<String> box;
  var now = DateTime.utc(2026, 9, 19, 12);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('zad_outbox_test');
    Hive.init(dir.path);
    box = await Hive.openBox<String>('outbox');
    now = DateTime.utc(2026, 9, 19, 12);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  Outbox outboxThat(
    Future<void> Function(OutboxEntry entry) send, {
    int maxAttempts = 8,
  }) =>
      Outbox(box: box, send: send, maxAttempts: maxAttempts, clock: () => now);

  Future<void> enqueue(Outbox outbox, String id) => outbox.enqueue(
    id: id,
    kind: OutboxKind.insertTransaction,
    payload: <String, dynamic>{'id': id, 'amount': 50.0},
  );

  group('classification', () {
    test('a constraint violation is permanent — the row is wrong', () {
      // 23514 is check_violation: what transfer_needs_target raises.
      const error = PostgrestException(
        message: 'violates check',
        code: '23514',
      );
      expect(classifySyncFailure(error), SyncFailureKind.permanent);
    });

    test('a dropped connection is transient', () {
      expect(
        classifySyncFailure(const SocketException('failed host lookup')),
        SyncFailureKind.transient,
      );
      expect(
        classifySyncFailure(TimeoutException('too slow')),
        SyncFailureKind.transient,
      );
    });

    test('5xx and 429 are transient, plain 4xx is not', () {
      expect(
        classifySyncFailure(
          const PostgrestException(message: 'x', code: '503'),
        ),
        SyncFailureKind.transient,
      );
      expect(
        classifySyncFailure(
          const PostgrestException(message: 'x', code: '429'),
        ),
        SyncFailureKind.transient,
      );
      expect(
        classifySyncFailure(
          const PostgrestException(message: 'x', code: '400'),
        ),
        SyncFailureKind.permanent,
      );
    });

    test('an RLS refusal asks for a session, not a retry', () {
      expect(
        classifySyncFailure(
          const PostgrestException(message: 'x', code: '42501'),
        ),
        SyncFailureKind.unauthenticated,
      );
      expect(
        classifySyncFailure(const AuthException('expired')),
        SyncFailureKind.unauthenticated,
      );
    });

    test('an unrecognised error is retried, never discarded', () {
      expect(
        classifySyncFailure(Exception('something new')),
        SyncFailureKind.transient,
      );
    });
  });

  group('flush', () {
    test('a successful send leaves the queue empty', () async {
      final sent = <String>[];
      final outbox = outboxThat((e) async => sent.add(e.id));

      await enqueue(outbox, 'a');
      final report = await outbox.flush();

      expect(sent, <String>['a']);
      expect(report.sent, 1);
      expect(report.remaining, 0);
      expect(report.stop, FlushStop.finished);
      expect(outbox.entries(), isEmpty);
    });

    test('the entry id is the row id, so a replay collides', () async {
      final outbox = outboxThat((e) async {});
      await enqueue(outbox, 'a');

      final entry = outbox.entries().single;
      expect(entry.payload['id'], entry.id);
    });

    test('a transient failure keeps the entry and backs off', () async {
      final outbox = outboxThat(
        (e) async => throw const SocketException('offline'),
      );
      await enqueue(outbox, 'a');

      final report = await outbox.flush();

      expect(report.sent, 0);
      expect(report.died, 0);
      expect(report.stop, FlushStop.offline);

      final entry = outbox.entries().single;
      expect(entry.state, OutboxState.pending);
      expect(entry.attempts, 1);
      expect(entry.nextAttemptAt, isNotNull);
      expect(entry.nextAttemptAt!.isAfter(now), isTrue);
    });

    test('an entry inside its backoff is skipped, not retried', () async {
      var calls = 0;
      final outbox = outboxThat((e) async {
        calls++;
        throw const SocketException('offline');
      });
      await enqueue(outbox, 'a');

      await outbox.flush();
      expect(calls, 1);

      await outbox.flush(); // same instant: still backed off
      expect(calls, 1, reason: 'the backoff was ignored');

      now = now.add(const Duration(minutes: 10));
      await outbox.flush();
      expect(calls, 2);
    });

    test(
      'being offline stops the flush instead of charging every entry',
      () async {
        final tried = <String>[];
        final outbox = outboxThat((e) async {
          tried.add(e.id);
          throw const SocketException('offline');
        });

        await enqueue(outbox, 'a');
        now = now.add(const Duration(seconds: 1));
        await enqueue(outbox, 'b');

        await outbox.flush();

        expect(tried, <String>[
          'a',
        ], reason: 'b should not have been attempted');
        final b = outbox.entries().firstWhere((e) => e.id == 'b');
        expect(b.attempts, 0);
        expect(b.nextAttemptAt, isNull);
      },
    );

    test(
      'a permanent failure dies at once and lets the next entry through',
      () async {
        final tried = <String>[];
        final outbox = outboxThat((e) async {
          tried.add(e.id);
          if (e.id == 'a') {
            throw const PostgrestException(
              message: 'violates check',
              code: '23514',
            );
          }
        });

        await enqueue(outbox, 'a');
        now = now.add(const Duration(seconds: 1));
        await enqueue(outbox, 'b');

        final report = await outbox.flush();

        expect(tried, <String>['a', 'b']);
        expect(report.died, 1);
        expect(report.sent, 1);
        expect(report.stop, FlushStop.finished);

        final dead = outbox.deadLetters();
        expect(dead.single.id, 'a');
        expect(dead.single.lastError, contains('23514'));
      },
    );

    test('no session stops the flush without charging an attempt', () async {
      final outbox = outboxThat(
        (e) async => throw const AuthException('session expired'),
      );
      await enqueue(outbox, 'a');

      final report = await outbox.flush();

      expect(report.stop, FlushStop.unauthenticated);
      final entry = outbox.entries().single;
      expect(entry.attempts, 0, reason: 'the data was never the problem');
      expect(entry.state, OutboxState.pending);
    });

    test(
      'an entry that runs out of attempts dies rather than retrying forever',
      () async {
        var calls = 0;
        final outbox = outboxThat((e) async {
          calls++;
          throw const SocketException('offline');
        }, maxAttempts: 3);
        await enqueue(outbox, 'a');

        for (var i = 0; i < 5; i++) {
          await outbox.flush();
          now = now.add(const Duration(minutes: 10));
        }

        expect(calls, 3);
        expect(outbox.deadLetters().single.id, 'a');
        expect(outbox.entries(includeDead: false), isEmpty);
      },
    );

    test(
      'order is kept — a later write never overtakes an earlier one',
      () async {
        final sent = <String>[];
        final outbox = outboxThat((e) async => sent.add(e.id));

        for (final id in <String>['a', 'b', 'c']) {
          await enqueue(outbox, id);
          now = now.add(const Duration(seconds: 1));
        }
        await outbox.flush();

        expect(sent, <String>['a', 'b', 'c']);
      },
    );
  });

  group('dead letters', () {
    test('are kept, not dropped — the user was told this saved', () async {
      final outbox = outboxThat(
        (e) async =>
            throw const PostgrestException(message: 'nope', code: '23514'),
      );
      await enqueue(outbox, 'a');
      await outbox.flush();

      expect(outbox.deadLetters(), hasLength(1));
      expect(box.containsKey('a'), isTrue);
    });

    test('can be discarded, and re-queued with a clean slate', () async {
      var shouldFail = true;
      final outbox = outboxThat((e) async {
        if (shouldFail) {
          throw const PostgrestException(message: 'nope', code: '23514');
        }
      });
      await enqueue(outbox, 'a');
      await outbox.flush();
      expect(outbox.deadLetters(), hasLength(1));

      shouldFail = false;
      await outbox.retryDead('a');
      final requeued = outbox.entries().single;
      expect(requeued.state, OutboxState.pending);
      expect(requeued.attempts, 0);

      final report = await outbox.flush();
      expect(report.sent, 1);
      expect(outbox.entries(), isEmpty);
    });
  });

  test('the queue survives the app being killed', () async {
    final outbox = outboxThat((e) async {});
    await enqueue(outbox, 'a');
    await box.close();

    final reopened = await Hive.openBox<String>('outbox');
    final after = Outbox(box: reopened, send: (e) async {}, clock: () => now);

    final entry = after.entries().single;
    expect(entry.id, 'a');
    expect(entry.payload['amount'], 50.0);
    expect(entry.kind, OutboxKind.insertTransaction);
  });
}
