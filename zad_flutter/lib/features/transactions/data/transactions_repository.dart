/// Transactions, offline first.
///
/// The read path is cache-then-network and the cache read is **synchronous**:
/// that is what makes the first frame show real figures instead of a spinner.
/// The write path is local-then-outbox: the row is in the cache before the
/// method returns, and the network is somebody else's problem.
library;

import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/core/period/budget_period.dart';
import 'package:zad/data/sync/outbox.dart';
import 'package:zad/data/sync/outbox_entry.dart';
import 'package:zad/features/transactions/data/transactions_remote.dart';
import 'package:zad/features/transactions/domain/transaction.dart';

/// Reads and records transactions.
class TransactionsRepository {
  /// Creates a repository.
  ///
  /// [outbox] is a getter rather than the outbox itself because the outbox
  /// sends through this repository and this repository queues through it. One
  /// of the two has to be resolved late, and a getter is cheaper than a
  /// registry.
  new({
    required Box<String> cache,
    required TransactionsRemote remote,
    required Outbox Function() outbox,
    required String Function() newId,
    required String? Function() signedInUserId,
  }) : _cache = cache,
       _remote = remote,
       _outbox = outbox,
       _newId = newId,
       _signedInUserId = signedInUserId;

  final Box<String> _cache;
  final TransactionsRemote _remote;
  final Outbox Function() _outbox;
  final String Function() _newId;
  final String? Function() _signedInUserId;

  /// The cached rows falling inside [period], newest first.
  ///
  /// Synchronous, and the whole point of the cache. Containment is decided by
  /// [BudgetPeriod.contains], so a cached row is filtered by exactly the range
  /// the server would have filtered it by.
  List<ZadTransaction> cachedPeriod(BudgetPeriod period) {
    final rows = <ZadTransaction>[];
    for (final raw in _cache.values) {
      final txn = ZadTransaction.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      if (period.contains(txn.createdAt)) rows.add(txn);
    }
    rows.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return rows;
  }

  /// Fetches [period] from the server and replaces the cached copy of it.
  ///
  /// Only rows inside the period are replaced, and pending rows are kept. A
  /// pending row is a write the server has not acknowledged yet; dropping it
  /// because the server did not mention it would make the user's entry vanish
  /// from the screen and then reappear when the outbox drains.
  Future<List<ZadTransaction>> refreshPeriod(BudgetPeriod period) async {
    final fresh = await _remote.fetchPeriod(
      userId: _requireUserId(),
      startsAt: period.startsAt,
      endsAt: period.endsAt,
    );

    final server = fresh
        .map(ZadTransaction.fromJson)
        .map((t) => t.markPending(pending: false))
        .toList();
    final serverIds = server.map((t) => t.id).toSet();

    final stale = cachedPeriod(period)
        .where((t) => !t.isPending && !serverIds.contains(t.id))
        .map((t) => t.id);
    await _cache.deleteAll(stale);

    await _cache.putAll(<String, String>{
      for (final txn in server) txn.id: jsonEncode(txn.toCacheJson()),
    });

    return cachedPeriod(period);
  }

  /// Records a transaction: cache first, queue second, network never.
  ///
  /// [build] receives the row id so the id cannot be forgotten or reused — the
  /// cached row, the outbox entry and the eventual server row all share it, and
  /// that shared id is what makes a retry idempotent.
  Future<ZadTransaction> record(
    ZadTransaction Function(String id) build,
  ) async {
    final txn = build(_newId()).markPending(pending: true);

    await _cache.put(txn.id, jsonEncode(txn.toCacheJson()));
    await _outbox().enqueue(
      id: txn.id,
      kind: OutboxKind.insertTransaction,
      payload: txn.toInsertJson(),
    );

    return txn;
  }

  /// Sends one queued insert. Registered as the outbox's sender for
  /// [OutboxKind.insertTransaction].
  ///
  /// Throws on failure and lets the transport's own exception out, because the
  /// outbox classifies it to decide between retrying and giving up.
  Future<void> sendQueued(OutboxEntry entry) async {
    final stored = await _remote.upsertReturning(entry.payload);
    if (stored == null) return;

    // The server's row wins over the one this device sent: the amount may have
    // been converted into the account's currency and txn_kind may have been
    // reconciled against is_expense.
    final confirmed = ZadTransaction.fromJson(stored)
        .markPending(pending: false);
    await _cache.put(confirmed.id, jsonEncode(confirmed.toCacheJson()));
  }

  String _requireUserId() {
    final id = _signedInUserId();
    if (id == null || id.isEmpty) {
      throw StateError('no signed-in user to read transactions for');
    }
    return id;
  }
}
