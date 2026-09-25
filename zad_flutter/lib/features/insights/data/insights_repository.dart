/// The brain's pending insights: cached for Home's first frame, moved on
/// through the outbox.
///
/// A decision about a card — dismissed, answered — is queued like any other
/// write, and a queued one hides its card at once, so a dismissal made with no
/// signal does not come back on the next refresh. Each send is read back: the
/// row must say the new status before the entry is dropped.
library;

import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/data/sync/outbox.dart';
import 'package:zad/data/sync/outbox_entry.dart';
import 'package:zad/features/insights/domain/insight.dart';

/// The server side.
///
/// RLS on `zad_insights` is the owner's for everything (`user_own_insights`);
/// `zad_memory_upsert` is security definer and refuses a `p_user` that is not
/// the caller (read off the live function 2026-09-21).
abstract interface class InsightsRemote {
  /// Pending insights, newest first.
  Future<List<Map<String, dynamic>>> fetchPending(String userId);

  /// Sets [id]'s status, and its dismiss reason when there is one.
  Future<void> setStatus(String id, String status, {String? reason});

  /// [id]'s status as the server has it, or null when the row is gone.
  Future<String?> statusOf(String id);

  /// Leaves the brain a memory note.
  Future<void> remember({
    required String userId,
    required String scope,
    required String note,
    required double confidence,
  });
}

/// The real table and function.
class SupabaseInsightsRemote implements InsightsRemote {
  /// Creates a remote over a Supabase client.
  const new(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Map<String, dynamic>>> fetchPending(String userId) async =>
      (await _client
              .from('zad_insights')
              .select(
                'id, kind, surface, priority, title, body, about_item, '
                'created_at',
              )
              .eq('user_id', userId)
              .eq('status', 'pending')
              .order('created_at', ascending: false)
              .limit(50))
          .cast<Map<String, dynamic>>();

  @override
  Future<void> setStatus(String id, String status, {String? reason}) => _client
      .from('zad_insights')
      .update(<String, dynamic>{
        'status': status,
        'dismiss_reason': ?reason,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', id);

  @override
  Future<String?> statusOf(String id) async =>
      (await _client
              .from('zad_insights')
              .select('status')
              .eq('id', id)
              .maybeSingle())?['status']
          as String?;

  @override
  Future<void> remember({
    required String userId,
    required String scope,
    required String note,
    required double confidence,
  }) => _client.rpc<dynamic>(
    'zad_memory_upsert',
    params: <String, dynamic>{
      'p_user': userId,
      'p_scope': scope,
      'p_note': note,
      'p_conf': confidence,
    },
  );
}

/// Holds the insights.
class InsightsRepository {
  /// Creates a repository.
  const new({
    required Box<String> cache,
    required InsightsRemote remote,
    required Outbox Function() outbox,
    required String? Function() signedInUserId,
  }) : _cache = cache,
       _remote = remote,
       _outbox = outbox,
       _signedInUserId = signedInUserId;

  final Box<String> _cache;
  final InsightsRemote _remote;
  final Outbox Function() _outbox;
  final String? Function() _signedInUserId;

  static const String _key = 'zad_insights';

  /// The outbox id for a decision about [id].
  static String outboxIdFor(String id) => 'insight:$id';

  /// Pending insights, minus any with a decision still queued.
  List<ZadInsight> cached() {
    final decided = <String>{
      for (final e in _outbox().entries(includeDead: false))
        if (e.kind == OutboxKind.resolveInsight) e.payload['id'] as String,
    };
    return <ZadInsight>[
      for (final i in _stored())
        if (!decided.contains(i.id)) i,
    ];
  }

  /// Reads the pending insights and caches them.
  Future<List<ZadInsight>> refresh() async {
    final rows = await _remote.fetchPending(_requireUserId());
    await _cache.put(_key, jsonEncode(rows));
    return cached();
  }

  /// Dismisses [insight] — with a [reason] for an insight, without one for a
  /// question put off.
  Future<void> dismiss(ZadInsight insight, {DismissReason? reason}) =>
      _queue(insight, status: 'dismissed', reason: reason);

  /// Marks [insight] acted on (a question answered).
  Future<void> markActed(ZadInsight insight) =>
      _queue(insight, status: 'acted');

  Future<void> _queue(
    ZadInsight insight, {
    required String status,
    DismissReason? reason,
  }) {
    final note = reason == null ? null : dismissalNote(reason, insight);
    return _outbox().enqueue(
      id: outboxIdFor(insight.id),
      kind: OutboxKind.resolveInsight,
      payload: <String, dynamic>{
        'id': insight.id,
        'user_id': _requireUserId(),
        'status': status,
        'reason': ?reason?.wire,
        if (note != null) ...<String, dynamic>{
          'note_scope': note.scope,
          'note': note.note,
          'note_confidence': note.confidence,
        },
      },
    );
  }

  /// Sends a queued decision, checks it took, then leaves the memory note.
  Future<void> sendQueued(OutboxEntry entry) async {
    final p = entry.payload;
    final id = p['id'] as String;
    final status = p['status'] as String;
    await _remote.setStatus(id, status, reason: p['reason'] as String?);
    final now = await _remote.statusOf(id);
    // A row that is gone has nothing left to decide.
    if (now == null) return;
    if (now != status) {
      throw StateError('insight $id still reads "$now", not "$status"');
    }
    if (p['note'] case final String note) {
      await _remote.remember(
        userId: p['user_id'] as String,
        scope: p['note_scope'] as String,
        note: note,
        confidence: (p['note_confidence'] as num).toDouble(),
      );
    }
  }

  List<ZadInsight> _stored() {
    final raw = _cache.get(_key);
    if (raw == null) return const <ZadInsight>[];
    try {
      return <ZadInsight>[
        for (final row in jsonDecode(raw) as List<dynamic>)
          ZadInsight.fromJson(Map<String, dynamic>.from(row as Map)),
      ];
    } on Object {
      return const <ZadInsight>[];
    }
  }

  String _requireUserId() {
    final id = _signedInUserId();
    if (id == null || id.isEmpty) {
      throw StateError('no signed-in user to read insights for');
    }
    return id;
  }
}
