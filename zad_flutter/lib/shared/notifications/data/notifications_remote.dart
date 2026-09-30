/// The server side of the notification list.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads and marks `app_notifications`.
///
/// RLS: select and update are `user_id = auth.uid()`, so every call here only
/// ever sees or touches the caller's own rows.
abstract interface class NotificationsRemote {
  /// The newest [limit] rows, newest first.
  Future<List<Map<String, dynamic>>> fetchLatest({
    required String userId,
    required int limit,
  });

  /// Marks one row read and returns it as it now reads, or null when the row
  /// is gone.
  Future<Map<String, dynamic>?> markReadReturning(String id);

  /// Marks every unread row written at or before [upTo] read.
  Future<void> markAllRead({required String userId, required DateTime upTo});

  /// How many rows written at or before [upTo] are still unread.
  Future<int> unreadUpTo({required String userId, required DateTime upTo});
}

/// The real table.
class SupabaseNotificationsRemote implements NotificationsRemote {
  /// Creates a remote over a Supabase client.
  const new(this._client);

  final SupabaseClient _client;

  static const String _table = 'app_notifications';

  @override
  Future<List<Map<String, dynamic>>> fetchLatest({
    required String userId,
    required int limit,
  }) async {
    final rows = await _client
        .from(_table)
        .select('id, title, message, is_read, created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.cast<Map<String, dynamic>>();
  }

  @override
  Future<Map<String, dynamic>?> markReadReturning(String id) async {
    await _client
        .from(_table)
        .update(<String, dynamic>{'is_read': true})
        .eq('id', id);
    return await _client
        .from(_table)
        .select('id, is_read')
        .eq('id', id)
        .maybeSingle();
  }

  @override
  Future<void> markAllRead({
    required String userId,
    required DateTime upTo,
  }) async {
    // `not is true` rather than `eq false`: the column is nullable and a null
    // is unread too.
    await _client
        .from(_table)
        .update(<String, dynamic>{'is_read': true})
        .eq('user_id', userId)
        .not('is_read', 'is', true)
        .lte('created_at', upTo.toUtc().toIso8601String());
  }

  @override
  Future<int> unreadUpTo({
    required String userId,
    required DateTime upTo,
  }) async {
    final rows = await _client
        .from(_table)
        .select('id')
        .eq('user_id', userId)
        .not('is_read', 'is', true)
        .lte('created_at', upTo.toUtc().toIso8601String());
    return rows.length;
  }
}
