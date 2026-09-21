/// The server side of "سجل تعديلات زاد".
library;

import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads `agent_actions` and asks `zad_agent_undo` to take one back.
///
/// RLS on `agent_actions` is select-only, owner rows (`user_reads_own_agent_
/// actions`). The undo is a security-definer function that checks ownership,
/// the newer-action rule and the table itself; the phone never restores a row
/// on its own.
abstract interface class AgentActionsRemote {
  /// The newest [limit] actions, newest first.
  Future<List<Map<String, dynamic>>> fetchLatest({
    required String userId,
    required int limit,
  });

  /// Asks the server to undo [actionId]; returns its answer as it gave it.
  Future<Map<String, dynamic>> undo(String actionId);

  /// The action's status as the server now has it, or null when it is gone.
  Future<String?> statusOf(String actionId);
}

/// The real table and function.
class SupabaseAgentActionsRemote implements AgentActionsRemote {
  /// Creates a remote over a Supabase client.
  const new(this._client);

  final SupabaseClient _client;

  static const String _table = 'agent_actions';

  @override
  Future<List<Map<String, dynamic>>> fetchLatest({
    required String userId,
    required int limit,
  }) async {
    final rows = await _client
        .from(_table)
        .select(
          'id, tool_name, source, target_table, target_id, status, '
          'result_summary, created_at',
        )
        .eq('user_id', userId)
        // `seq`, not `created_at`: two tools in one turn share a timestamp to
        // the microsecond, and the undo rule ("newest first") is by seq.
        .order('seq', ascending: false)
        .limit(limit);
    return rows.cast<Map<String, dynamic>>();
  }

  @override
  Future<Map<String, dynamic>> undo(String actionId) async {
    final result = await _client.rpc<dynamic>(
      'zad_agent_undo',
      params: <String, dynamic>{'p_action_id': actionId},
    );
    return Map<String, dynamic>.from(result as Map);
  }

  @override
  Future<String?> statusOf(String actionId) async {
    final row = await _client
        .from(_table)
        .select('status')
        .eq('id', actionId)
        .maybeSingle();
    return row?['status'] as String?;
  }
}
