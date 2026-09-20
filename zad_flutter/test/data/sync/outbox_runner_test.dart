// The runner closes the sync cycle. Its job is small and its failure modes are
// not: two triggers firing together must not send the same row twice, a write
// made during a flush must not wait for an unrelated trigger, and a flush
// against a dead network must not spin.
//
// These tests wait on the runner's own future rather than on pumpEventQueue.
// Pumping only turns the event loop a fixed number of times, and a flush writes
// to Hive, which touches the disk — the flush can outlive the pump and make the
// test read the state from the middle of one.

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/data/sync/outbox.dart';
import 'package:zad/data/sync/outbox_entry.dart';
import 'package:zad/data/sync/outbox_runner.dart';

void main() {
  late Directory dir;
  late Box<String> box;
  late StreamController<SyncTrigger> triggers;
  OutboxRunner? runner;
  var now = DateTime.utc(2026, 9, 19, 12);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('zad_runner_test');
    Hive.init(dir.path);
    box = await Hive.openBox<String>('outbox');
    triggers = StreamController<SyncTrigger>.broadcast();
    now = DateTime.utc(2026, 9, 19, 12);
  });

  tearDown(() async {
    // Order matters: the runner goes first. A flush still in flight when the
    // boxes are deleted would reach a closed box.
    await runner?.dispose();
    runner = null;
    await triggers.close();
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  Outbox outboxThat(Future<void> Function(OutboxEntry) send) =>
      Outbox(box: box, send: send, clock: () => now);

  OutboxRunner runnerFor(Outbox outbox) =>
      runner = OutboxRunner(outbox: outbox, triggers: triggers.stream);

  Future<void> enqueue(Outbox outbox, String id) => outbox.enqueue(
    id: id,
    kind: OutboxKind.insertTransaction,
    payload: <String, dynamic>{'id': id},
  );

  /// Lets a trigger reach the listener, then waits for the flush it started.
  /// `flushNow` joins a running flush instead of starting a second one, so this
  /// returns only once the queue has actually been worked.
  Future<void> settle(OutboxRunner r) async {
    await pumpEventQueue();
    await r.flushNow();
  }

  test('start() flushes at once — the queue may predate this launch', () async {
    final sent = <String>[];
    final outbox = outboxThat((e) async => sent.add(e.id));
    await enqueue(outbox, 'a');

    final r = runnerFor(outbox)..start();
    await r.flushNow();

    expect(sent, <String>['a']);
  });

  test('an empty queue costs no round trip, so the tick is cheap', () async {
    var calls = 0;
    final outbox = outboxThat((e) async => calls++);
    final r = runnerFor(outbox)..start();

    triggers
      ..add(SyncTrigger.tick)
      ..add(SyncTrigger.tick);
    await settle(r);

    expect(calls, 0);
  });

  test('each trigger drains the queue', () async {
    final sent = <String>[];
    final outbox = outboxThat((e) async => sent.add(e.id));
    final r = runnerFor(outbox)..start();

    await enqueue(outbox, 'a');
    triggers.add(SyncTrigger.resumed);
    await settle(r);
    expect(sent, <String>['a']);

    now = now.add(const Duration(seconds: 1));
    await enqueue(outbox, 'b');
    triggers.add(SyncTrigger.networkChanged);
    await settle(r);
    expect(sent, <String>['a', 'b']);
  });

  test('two triggers at once produce one flush, not two', () async {
    final sent = <String>[];
    final gate = Completer<void>();
    final outbox = outboxThat((e) async {
      sent.add(e.id);
      await gate.future;
    });
    final r = runnerFor(outbox)..start();

    await enqueue(outbox, 'a');

    // A resume and a network change arriving together is routine, not exotic.
    triggers
      ..add(SyncTrigger.resumed)
      ..add(SyncTrigger.networkChanged);
    await pumpEventQueue();

    expect(r.isFlushing, isTrue);
    expect(sent, <String>['a'], reason: 'the entry was sent twice');

    gate.complete();
    await settle(r);
    expect(sent, <String>['a']);
  });

  test('a write made during a flush is not left for a later trigger', () async {
    final sent = <String>[];
    final gate = Completer<void>();
    final outbox = outboxThat((e) async {
      sent.add(e.id);
      if (e.id == 'a') await gate.future;
    });
    final r = runnerFor(outbox)..start();

    await enqueue(outbox, 'a');
    triggers.add(SyncTrigger.resumed);
    await pumpEventQueue();
    expect(sent, <String>['a'], reason: "'a' should be in flight");

    // 'b' is written while 'a' is still in flight. The request to send it folds
    // into the running flush, which must then come back round for it — without
    // that, 'b' waits for an unrelated trigger that may never come.
    now = now.add(const Duration(seconds: 1));
    await enqueue(outbox, 'b');

    final joined = r.flushNow();
    expect(r.isFlushing, isTrue);

    gate.complete();
    await joined;

    expect(sent, <String>['a', 'b']);
    expect(outbox.entries(includeDead: false), isEmpty);
  });

  test('being offline does not spin — one attempt, then it waits', () async {
    var calls = 0;
    final outbox = outboxThat((e) async {
      calls++;
      throw const SocketException('offline');
    });
    final r = runnerFor(outbox)..start();

    await enqueue(outbox, 'a');
    triggers
      ..add(SyncTrigger.resumed)
      ..add(SyncTrigger.networkChanged)
      ..add(SyncTrigger.tick);
    await settle(r);

    expect(calls, 1, reason: 'the runner retried inside one outage');
  });

  test('the tick is what wakes an entry out of its backoff', () async {
    var calls = 0;
    var offline = true;
    final outbox = outboxThat((e) async {
      calls++;
      if (offline) throw const SocketException('offline');
    });
    final r = runnerFor(outbox)..start();

    await enqueue(outbox, 'a');
    triggers.add(SyncTrigger.resumed);
    await settle(r);
    expect(calls, 1);

    offline = false;
    triggers.add(SyncTrigger.tick); // still inside the backoff
    await settle(r);
    expect(calls, 1, reason: 'the backoff was ignored');

    now = now.add(const Duration(minutes: 10));
    triggers.add(SyncTrigger.tick);
    await settle(r);
    expect(calls, 2);
    expect(outbox.entries(includeDead: false), isEmpty);
  });

  test('no session stops the run without charging the entry', () async {
    final outbox = outboxThat(
      (e) async => throw const AuthException('expired'),
    );
    final r = runnerFor(outbox)..start();

    await enqueue(outbox, 'a');
    triggers.add(SyncTrigger.resumed);
    await settle(r);

    expect(outbox.entries().single.attempts, 0);
  });

  test('reports are published for a UI that shows what is unsent', () async {
    final outbox = outboxThat((e) async {});
    final r = runnerFor(outbox);

    final reports = <OutboxFlushReport>[];
    r.reports.listen(reports.add);
    r.start();

    await enqueue(outbox, 'a');
    triggers.add(SyncTrigger.resumed);
    await settle(r);
    await pumpEventQueue();

    expect(reports, hasLength(1));
    expect(reports.single.sent, 1);
    expect(reports.single.stop, FlushStop.finished);
  });

  group('beforeFlush', () {
    test('runs before the queue is worked, not after', () async {
      // Ordering is the point. A notification captured while the app was shut
      // must become a queued entry *and* be sent on the same cycle, not wait
      // for the next trigger.
      final order = <String>[];
      late Outbox outbox;
      outbox = outboxThat((e) async => order.add('sent ${e.id}'));

      final r = OutboxRunner(
        outbox: outbox,
        triggers: triggers.stream,
        beforeFlush: () async {
          order.add('filled');
          await enqueue(outbox, 'a');
        },
      );
      runner = r;
      r.start();
      await r.flushNow();

      expect(order, <String>['filled', 'sent a']);
    });

    test('a failure to fill does not stop the queue being emptied', () async {
      // The inbox is a source of work, not the work. A missing plugin on a
      // test host must not strand rows that are already queued.
      final sent = <String>[];
      final outbox = outboxThat((e) async => sent.add(e.id));
      await enqueue(outbox, 'already-queued');

      final r = OutboxRunner(
        outbox: outbox,
        triggers: triggers.stream,
        beforeFlush: () async => throw StateError('no plugin here'),
      );
      runner = r;
      r.start();
      await r.flushNow();

      expect(sent, <String>['already-queued']);
      expect(r.lastPrefillError, isA<StateError>());
    });

    test('a successful fill clears the last error', () async {
      var shouldFail = true;
      final outbox = outboxThat((e) async {});
      final r = OutboxRunner(
        outbox: outbox,
        triggers: triggers.stream,
        beforeFlush: () async {
          if (shouldFail) throw StateError('once');
        },
      );
      runner = r;
      r.start();
      await r.flushNow();
      expect(r.lastPrefillError, isNotNull);

      shouldFail = false;
      await r.flushNow();
      expect(r.lastPrefillError, isNull);
    });
  });

  test('dispose stops it responding to triggers', () async {
    var calls = 0;
    final outbox = outboxThat((e) async => calls++);
    final r = runnerFor(outbox)..start();
    await r.dispose();

    await enqueue(outbox, 'a');
    triggers.add(SyncTrigger.resumed);
    await pumpEventQueue();

    expect(calls, 0);
  });
}
