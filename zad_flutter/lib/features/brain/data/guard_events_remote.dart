/// The server side of "صحة العقل": reads `zad_guard_events`.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads the refusals. Read only: the phone never writes this table — the
/// door does, and RLS lets the customer read their own rows.
abstract interface class GuardEventsRemote {
  /// The newest [limit] refusals, newest first.
  Future<List<Map<String, dynamic>>> fetchLatest({
    required String userId,
    required int limit,
  });

  /// The `reason` of every refusal since [since].
  Future<List<String>> reasonsSince({
    required String userId,
    required DateTime since,
  });
}

/// The real table.
class SupabaseGuardEventsRemote implements GuardEventsRemote {
  /// Creates a remote over a Supabase client.
  const new(this._client);

  final SupabaseClient _client;

  static const String _table = 'zad_guard_events';

  @override
  Future<List<Map<String, dynamic>>> fetchLatest({
    required String userId,
    required int limit,
  }) async {
    final rows = await _client
        .from(_table)
        .select('id, kind, reason, intent, created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.cast<Map<String, dynamic>>();
  }

  @override
  Future<List<String>> reasonsSince({
    required String userId,
    required DateTime since,
  }) async {
    final rows = await _client
        .from(_table)
        .select('reason')
        .eq('user_id', userId)
        .gte('created_at', since.toUtc().toIso8601String())
        .limit(5000);
    return <String>[for (final row in rows) (row['reason'] as String?) ?? ''];
  }
}
