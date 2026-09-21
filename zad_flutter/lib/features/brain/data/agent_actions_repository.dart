/// The action log: cached for an instant open, undone only online.
///
/// An undo does not go through the outbox, for the same reason joining a
/// family does not: it is the server deciding whether it still can (nothing
/// newer on the row, the row still there), and "taken back" told to a customer
/// who is offline would be false the moment something else touched that row
/// before the queue drained. So it happens now or says why not.
///
/// And it is read back. `zad_agent_undo` answering `ok` is its own report; the
/// action's row reading `undone` afterwards is the proof.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:zad/features/brain/data/agent_actions_remote.dart';
import 'package:zad/features/brain/domain/agent_action.dart';

/// How an undo ended.
sealed class UndoOutcome {
  const new();
}

/// Taken back; [table] is what the server restored.
final class Undone extends UndoOutcome {
  /// Creates the outcome.
  const new(this.table);

  /// The table the undone action had written.
  final String? table;
}

/// Not taken back, and why.
final class UndoRefused extends UndoOutcome {
  /// Creates the outcome.
  const new(this.failure);

  /// Why.
  final UndoFailure failure;
}

/// Holds the action log.
class AgentActionsRepository {
  /// Creates a repository.
  const new({
    required Box<String> cache,
    required AgentActionsRemote remote,
    required String? Function() signedInUserId,
  }) : _cache = cache,
       _remote = remote,
       _signedInUserId = signedInUserId;

  final Box<String> _cache;
  final AgentActionsRemote _remote;
  final String? Function() _signedInUserId;

  /// How many rows a refresh reads. The busiest account had 75 on 2026-09-21;
  /// Kotlin reads 50.
  static const int pageSize = 100;

  static const String _key = 'agent_actions';

  /// The cached page, newest first. Synchronous; call it from `build`.
  List<AgentAction> cached() {
    final raw = _cache.get(_key);
    if (raw == null) return const <AgentAction>[];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return <AgentAction>[
        for (final row in decoded)
          AgentAction.fromJson(Map<String, dynamic>.from(row as Map)),
      ];
    } on Object {
      return const <AgentAction>[];
    }
  }

  /// Reads the newest page and caches it.
  Future<List<AgentAction>> refresh() async {
    final rows = await _remote.fetchLatest(
      userId: _requireUserId(),
      limit: pageSize,
    );
    final items = rows.map(AgentAction.fromJson).toList();
    await _store(items);
    return items;
  }

  /// Asks the server to take [action] back, and checks that it did.
  Future<UndoOutcome> undo(AgentAction action) async {
    final Map<String, dynamic> answer;
    final String? status;
    try {
      answer = await _remote.undo(action.id);
      if (answer['ok'] != true) {
        return UndoRefused(UndoFailure.fromCode(answer['error'] as String?));
      }
      // The server's word, checked against its own row.
      status = await _remote.statusOf(action.id);
    } on Object catch (error) {
      return UndoRefused(_failureOf(error));
    }
    if (status != 'undone') {
      return const UndoRefused(UndoFailure.unknown);
    }

    await _store(<AgentAction>[
      for (final a in cached())
        if (a.id == action.id)
          AgentAction(
            id: a.id,
            toolName: a.toolName,
            source: a.source,
            status: 'undone',
            createdAt: a.createdAt,
            targetTable: a.targetTable,
            targetId: a.targetId,
            resultSummary: a.resultSummary,
          )
        else
          a,
    ]);
    return Undone(answer['table'] as String? ?? action.targetTable);
  }

  /// What a raw error means to the customer — the same reading the family
  /// repository makes of a call that never got an answer.
  static UndoFailure _failureOf(Object error) {
    if (error is SocketException ||
        error is TimeoutException ||
        error is HandshakeException ||
        error.toString().contains('ClientException')) {
      return UndoFailure.offline;
    }
    if (error is PostgrestException && error.code == '42501') {
      return UndoFailure.notAllowed;
    }
    return UndoFailure.unknown;
  }

  Future<void> _store(List<AgentAction> items) => _cache.put(
    _key,
    jsonEncode(<Map<String, dynamic>>[for (final a in items) a.toJson()]),
  );

  String _requireUserId() {
    final id = _signedInUserId();
    if (id == null || id.isEmpty) {
      throw StateError('no signed-in user to read the action log for');
    }
    return id;
  }
}
