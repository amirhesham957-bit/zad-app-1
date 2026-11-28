/// Obligations, offline first — the subscriptions repository's contract:
/// cache before send, one outbox entry per row, a refresh that keeps queued
/// rows, and a read-back before a write is believed. These rows decide what
/// the budget reserves, so a write that did not land is a wrong budget.
///
/// They are cached in the documents box under `obligation:<id>` rather than a
/// box of their own; sign-out clears that box whole.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:zad/core/data/commit_my_intent.dart';
import 'package:zad/core/data/edge_client.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/data/sync/outbox.dart';
import 'package:zad/core/data/sync/outbox_entry.dart';
import 'package:zad/core/data/sync/sync_failure.dart';
import 'package:zad/features/obligations/domain/obligation.dart';

/// Reads `zad_obligations` and writes it through the one door (P1.6b). RLS is
/// `user_own_obligations`.
abstract interface class ObligationsRemote {
  /// The account's active rows.
  Future<List<Map<String, dynamic>>> fetchActive({required String userId});

  /// Writes [row] and returns what the table holds for it afterwards.
  Future<Map<String, dynamic>?> upsertReturning(Map<String, dynamic> row);

  /// Deletes [id].
  Future<void> remove(String id);

  /// Whether [id] is still there.
  Future<bool> exists(String id);
}

/// The real table.
class SupabaseObligationsRemote implements ObligationsRemote {
  /// Creates a remote over a Supabase client.
  const new(this._client);

  final SupabaseClient _client;

  static const String _table = 'zad_obligations';

  @override
  Future<List<Map<String, dynamic>>> fetchActive({
    required String userId,
  }) async {
    // Active only, as Kotlin's `getObligations` reads them: a stopped
    // obligation is history, not something to pay.
    final rows = await _client
        .from(_table)
        .select()
        .eq('user_id', userId)
        .eq('active', true)
        .order('created_at');
    return rows.cast<Map<String, dynamic>>();
  }

  /// What `obligation.added` reads from a row; `id` travels as `item_id`.
  static const List<String> _addKeys = <String>[
    'title',
    'amount',
    'kind',
    'recurrence',
    'due_day',
    'due_date',
    'confirmed',
  ];

  /// What `obligation.updated` accepts in a patch.
  static const List<String> _patchKeys = <String>[
    'title',
    'amount',
    'kind',
    'recurrence',
    'due_day',
    'due_date',
    'confirmed',
    'active',
  ];

  @override
  Future<Map<String, dynamic>?> upsertReturning(
    Map<String, dynamic> row,
  ) async {
    final id = row['id'] as String;
    final exists =
        await _client.from(_table).select('id').eq('id', id).maybeSingle() !=
        null;
    if (!exists) {
      // A replay of the add (same event id, or the same row id under a new
      // one) is answered by the door without a second row.
      await commitMyIntent(
        _client,
        kind: 'obligation.added',
        clientEventId: 'obligation:$id',
        payload: <String, dynamic>{
          'item_id': id,
          for (final key in _addKeys)
            if (row[key] != null) key: row[key],
        },
      );
    }
    // The door adds a row active; an edit (or an add that was already stopped)
    // carries the rest. An edit is an absolute write, so a fresh id per attempt
    // is safe: the same edit twice leaves the same row.
    if (exists || row['active'] == false) {
      await commitMyIntent(
        _client,
        kind: 'obligation.updated',
        clientEventId: 'obligation_edit:$id:${newTraceId()}',
        payload: <String, dynamic>{
          'item_id': id,
          'patch': <String, dynamic>{
            for (final key in _patchKeys)
              if (row.containsKey(key)) key: row[key],
          },
        },
      );
    }
    return await _client.from(_table).select().eq('id', id).maybeSingle();
  }

  @override
  Future<void> remove(String id) async {
    try {
      await commitMyIntent(
        _client,
        kind: 'obligation.deleted',
        clientEventId: 'obligation_delete:$id',
        payload: <String, dynamic>{'item_id': id},
      );
    } on ServerRefusal catch (e) {
      // Already gone: the delete has nothing left to do.
      if (e.reason != 'item_not_found') rethrow;
    }
  }

  @override
  Future<bool> exists(String id) async =>
      await _client.from(_table).select('id').eq('id', id).maybeSingle() !=
      null;
}

/// Holds the obligations.
class ObligationsRepository {
  /// Creates a repository.
  const new({
    required Box<String> cache,
    required ObligationsRemote remote,
    required Outbox Function() outbox,
    required String Function() newId,
    required String? Function() signedInUserId,
  }) : _cache = cache,
       _remote = remote,
       _outbox = outbox,
       _newId = newId,
       _signedInUserId = signedInUserId;

  final Box<String> _cache;
  final ObligationsRemote _remote;
  final Outbox Function() _outbox;
  final String Function() _newId;
  final String? Function() _signedInUserId;

  static const String _prefix = 'obligation:';

  /// The outbox id for a queued write of [id].
  static String outboxIdFor(String id) => 'obligation:$id';

  /// The outbox id for a queued delete of [id].
  static String deleteOutboxIdFor(String id) => 'obligation_delete:$id';

  /// Every cached row of the signed-in account.
  List<Obligation> cached() {
    final userId = _signedInUserId();
    if (userId == null) return const <Obligation>[];
    return <Obligation>[
      for (final key in _cache.keys)
        if (key is String && key.startsWith(_prefix))
          if (_read(_cache.get(key)) case final o? when o.userId == userId) o,
    ];
  }

  /// Asks the server and replaces what it answered for, keeping queued rows.
  Future<List<Obligation>> refresh() async {
    final rows = await _remote.fetchActive(userId: _requireUserId());
    final server = <Obligation>[for (final r in rows) Obligation.fromJson(r)];
    final serverIds = server.map((o) => o.id).toSet();
    final queuedDeletes = <String>{
      for (final e in _outbox().entries(includeDead: false))
        if (e.kind == OutboxKind.deleteObligation) e.payload['id'] as String,
    };

    for (final o in cached()) {
      if (!o.isPending && !serverIds.contains(o.id)) {
        await _cache.delete('$_prefix${o.id}');
      }
    }
    final pendingIds = <String>{
      for (final o in cached())
        if (o.isPending) o.id,
    };
    await _cache.putAll(<String, String>{
      for (final o in server)
        if (!pendingIds.contains(o.id) && !queuedDeletes.contains(o.id))
          '$_prefix${o.id}': jsonEncode(o.toCacheJson()),
    });
    return cached();
  }

  /// Adds an obligation.
  Future<Obligation> add({
    required String title,
    required double amount,
    required ObligationKind kind,
    required Recurrence recurrence,
    int? dueDay,
  }) async {
    final o = Obligation(
      id: _newId(),
      userId: _requireUserId(),
      title: title.trim(),
      amount: amount,
      kind: kind,
      dueDay: dueDay,
      recurrence: recurrence,
      isPending: true,
    );
    await _save(o);
    return o;
  }

  /// Writes a changed row.
  Future<Obligation> update(Obligation o) async {
    final pending = o.copyWith(isPending: true);
    await _save(pending);
    return pending;
  }

  /// Deletes a row.
  Future<void> remove(String id) async {
    await _cache.delete('$_prefix$id');
    await _outbox().discard(outboxIdFor(id));
    await _outbox().enqueue(
      id: deleteOutboxIdFor(id),
      kind: OutboxKind.deleteObligation,
      payload: <String, dynamic>{'id': id},
    );
  }

  /// Sends one queued write and refuses to believe it until it reads back.
  Future<void> sendQueued(OutboxEntry entry) async {
    final stored = await _remote.upsertReturning(entry.payload);
    if (stored == null) {
      throw StateError('zad_obligations has no row ${entry.payload['id']}');
    }
    _verify(sent: entry.payload, stored: stored);
    final id = stored['id'] as String;
    // A newer edit of the same row is still queued: keep showing it.
    final sent = jsonEncode(entry.payload);
    final superseded = _outbox()
        .entries(includeDead: false)
        .any((e) => e.id == outboxIdFor(id) && jsonEncode(e.payload) != sent);
    if (superseded) return;
    final confirmed = Obligation.fromJson(stored);
    await _cache.put('$_prefix$id', jsonEncode(confirmed.toCacheJson()));
  }

  /// Sends one queued delete and checks the row is gone.
  Future<void> sendQueuedDelete(OutboxEntry entry) async {
    final id = entry.payload['id'] as String;
    await _remote.remove(id);
    if (await _remote.exists(id)) {
      throw StateError('obligation $id is still there after its delete');
    }
  }

  Future<void> _save(Obligation o) async {
    // Queued before the cache is written, for the reason the subscriptions
    // repository gives: a settling send of the previous version must be able
    // to see that a newer one is waiting.
    await _outbox().enqueue(
      id: outboxIdFor(o.id),
      kind: OutboxKind.upsertObligation,
      payload: o.toUpsertJson(),
    );
    await _cache.put('$_prefix${o.id}', jsonEncode(o.toCacheJson()));
  }

  static void _verify({
    required Map<String, dynamic> sent,
    required Map<String, dynamic> stored,
  }) {
    final want = (sent['amount'] as num).toDouble();
    final got = (stored['amount'] as num?)?.toDouble();
    if (got == null || (got - want).abs() >= 0.005) {
      throw StateError('amount read back as $got, wanted $want');
    }
    for (final column in const <String>[
      'kind',
      'due_day',
      'recurrence',
      'active',
      'confirmed',
    ]) {
      if (stored[column] != sent[column]) {
        throw StateError(
          '$column read back as ${stored[column]}, wanted ${sent[column]}',
        );
      }
    }
  }

  Obligation? _read(String? raw) {
    if (raw == null) return null;
    try {
      return Obligation.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      return null;
    }
  }

  String _requireUserId() {
    final id = _signedInUserId();
    if (id == null || id.isEmpty) {
      throw StateError('no signed-in user to read obligations for');
    }
    return id;
  }
}

/// Fixed obligations — rent, instalments, bills — cached in the documents
/// box.
final Provider<ObligationsRepository> obligationsRepositoryProvider =
    Provider<ObligationsRepository>((ref) {
      final store = ref.watch(localStoreProvider);
      return ObligationsRepository(
        cache: store.documents,
        remote: SupabaseObligationsRemote(ref.watch(supabaseClientProvider)),
        outbox: () => ref.read(outboxProvider),
        newId: const Uuid().v4,
        signedInUserId: ref.watch(signedInUserIdProvider),
      );
    });
