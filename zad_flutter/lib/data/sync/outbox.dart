/// The outbox: writes are saved locally first and sent afterwards, so the app
/// is never waiting on the network to accept what the user typed.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/data/sync/outbox_entry.dart';
import 'package:zad/data/sync/sync_failure.dart';

/// Sends one entry, or throws. The thrown error is classified by
/// [classifySyncFailure], so an implementation should let the transport's own
/// exceptions out rather than wrapping them in something generic.
typedef OutboxSender = Future<void> Function(OutboxEntry entry);

/// Why a flush stopped before the queue was empty.
enum FlushStop {
  /// The queue was emptied, or everything left is waiting out a backoff.
  finished,

  /// The network is not answering. Later entries were left untouched rather
  /// than charged an attempt each for the same outage.
  offline,

  /// Nobody is signed in. Nothing was charged an attempt; the fix is a session,
  /// not a change to the data.
  unauthenticated,
}

/// What a flush did.
class OutboxFlushReport {
  /// Creates a report.
  const new({
    required this.sent,
    required this.died,
    required this.remaining,
    required this.stop,
  });

  /// Entries that reached the server and left the queue.
  final int sent;

  /// Entries that became dead letters during this flush.
  final int died;

  /// Entries still queued, including ones waiting out a backoff.
  final int remaining;

  /// Why the flush ended.
  final FlushStop stop;

  @override
  String toString() =>
      'OutboxFlushReport(sent: $sent, died: $died, '
      'remaining: $remaining, stop: ${stop.name})';
}

/// A durable, ordered queue of writes.
class Outbox {
  /// Creates an outbox over an already-open [box].
  new({
    required Box<String> box,
    required OutboxSender send,
    this.maxAttempts = 8,
    DateTime Function() clock = DateTime.now,
    Duration maxBackoff = const Duration(minutes: 5),
  }) : _box = box,
       _send = send,
       _clock = clock,
       _maxBackoff = maxBackoff;

  final Box<String> _box;
  final OutboxSender _send;
  final DateTime Function() _clock;
  final Duration _maxBackoff;

  /// How many transient failures an entry survives before it is declared dead.
  final int maxAttempts;

  /// Adds a write to the queue.
  ///
  /// [id] is the row id the write will use, supplied by the caller so that the
  /// same id is already in the local cache — see [OutboxEntry.id].
  Future<OutboxEntry> enqueue({
    required String id,
    required String kind,
    required Map<String, dynamic> payload,
  }) async {
    final entry = OutboxEntry(
      id: id,
      kind: kind,
      payload: payload,
      createdAt: _clock(),
    );
    await _put(entry);
    return entry;
  }

  /// Every entry, oldest first.
  List<OutboxEntry> entries({bool includeDead = true}) {
    final all =
        _box.values
            .map(
              (raw) =>
                  OutboxEntry.fromJson(jsonDecode(raw) as Map<String, dynamic>),
            )
            .where((e) => includeDead || e.state != OutboxState.dead)
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return all;
  }

  /// Entries that were given up on, for a screen that can show the user what
  /// did not save and offer to discard or re-queue it.
  List<OutboxEntry> deadLetters() =>
      entries().where((e) => e.state == OutboxState.dead).toList();

  /// Drops an entry. This is the only way anything leaves the queue other than
  /// succeeding, and it exists so the user can dismiss a dead letter.
  Future<void> discard(String id) => _box.delete(id);

  /// Re-queues a dead entry with its attempt count reset.
  Future<void> retryDead(String id) async {
    final raw = _box.get(id);
    if (raw == null) return;
    final entry = OutboxEntry.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    if (entry.state != OutboxState.dead) return;
    await _put(
      OutboxEntry(
        id: entry.id,
        kind: entry.kind,
        payload: entry.payload,
        createdAt: entry.createdAt,
      ),
    );
  }

  /// Tries to send everything that is due, in the order it was written.
  ///
  /// Order is kept strictly. Two writes to the same row must not arrive
  /// reversed, and the cheapest way to guarantee that is never to overtake.
  Future<OutboxFlushReport> flush() async {
    var sent = 0;
    var died = 0;
    var stop = FlushStop.finished;

    for (final entry in entries(includeDead: false)) {
      if (!entry.isDueAt(_clock())) continue;

      try {
        await _send(entry);
        await _box.delete(entry.id);
        sent++;
      } on Object catch (error) {
        switch (classifySyncFailure(error)) {
          case SyncFailureKind.unauthenticated:
            // No attempt charged: the row is fine, the session is not.
            stop = FlushStop.unauthenticated;
          case SyncFailureKind.permanent:
            await _put(
              entry.copyWith(
                attempts: entry.attempts + 1,
                lastError: error.toString(),
                state: OutboxState.dead,
              ),
            );
            died++;
            continue;
          case SyncFailureKind.transient:
            final attempts = entry.attempts + 1;
            final exhausted = attempts >= maxAttempts;
            await _put(
              entry.copyWith(
                attempts: attempts,
                lastError: error.toString(),
                nextAttemptAt: exhausted
                    ? null
                    : _clock().add(_backoff(attempts)),
                state: exhausted ? OutboxState.dead : OutboxState.pending,
              ),
            );
            if (exhausted) died++;
            stop = FlushStop.offline;
        }
        break;
      }
    }

    return OutboxFlushReport(
      sent: sent,
      died: died,
      remaining: entries(includeDead: false).length,
      stop: stop,
    );
  }

  /// Doubling backoff, capped. Capped because an app that has been offline for
  /// an hour should still send within seconds of coming back, not wait out a
  /// backoff computed while it was away.
  Duration _backoff(int attempts) {
    final seconds = math.min(
      _maxBackoff.inSeconds,
      math.pow(2, attempts).toInt(),
    );
    return Duration(seconds: seconds);
  }

  Future<void> _put(OutboxEntry entry) =>
      _box.put(entry.id, jsonEncode(entry.toJson()));
}
