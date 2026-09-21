/// The server side of "زاد عارف عني إيه".
library;

import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads and changes what زاد knows about the customer.
///
/// RLS, read off the live project 2026-09-21: `zad_memory` is the owner's for
/// everything (members of a family can also read notes shared to it — the
/// `user_id` filter keeps those out of this list); `zad_customer_profile` is
/// the owner's for everything; `user_behavior_profile` owner-read;
/// `zad_place_visits` owner read and delete only.
abstract interface class MemoryRemote {
  /// The account's own notes, most certain first.
  Future<List<Map<String, dynamic>>> fetchNotes({
    required String userId,
    required int limit,
  });

  /// Deletes one note.
  Future<void> deleteNote(String id);

  /// Whether a note is still there.
  Future<bool> noteExists(String id);

  /// The profile row, or null when the brain has not started one.
  Future<Map<String, dynamic>?> fetchProfile(String userId);

  /// Writes the form's columns.
  Future<void> upsertProfile(String userId, Map<String, dynamic> columns);

  /// The weekly spending profile, or null.
  Future<Map<String, dynamic>?> fetchBehavior(String userId);

  /// Outings that ended at or after [since], newest first.
  Future<List<Map<String, dynamic>>> fetchVisits({
    required String userId,
    required DateTime since,
  });

  /// Deletes every outing.
  Future<void> deleteVisits(String userId);

  /// Whether any outing is left.
  Future<bool> anyVisits(String userId);
}

/// The real tables.
class SupabaseMemoryRemote implements MemoryRemote {
  /// Creates a remote over a Supabase client.
  const new(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Map<String, dynamic>>> fetchNotes({
    required String userId,
    required int limit,
  }) async {
    final rows = await _client
        .from('zad_memory')
        .select('id, scope, note, confidence, evidence_count')
        .eq('user_id', userId)
        .order('confidence', ascending: false)
        .limit(limit);
    return rows.cast<Map<String, dynamic>>();
  }

  @override
  Future<void> deleteNote(String id) =>
      _client.from('zad_memory').delete().eq('id', id);

  @override
  Future<bool> noteExists(String id) async =>
      await _client
          .from('zad_memory')
          .select('id')
          .eq('id', id)
          .maybeSingle() !=
      null;

  @override
  Future<Map<String, dynamic>?> fetchProfile(String userId) => _client
      .from('zad_customer_profile')
      .select(
        'preferred_name, gender, household_role, age_range, occupation, '
        'pay_day, pay_frequency, household_size, kids_count, city, dialect',
      )
      .eq('user_id', userId)
      .maybeSingle();

  @override
  Future<void> upsertProfile(String userId, Map<String, dynamic> columns) =>
      _client.from('zad_customer_profile').upsert(<String, dynamic>{
        'user_id': userId,
        ...columns,
        'updated_by': 'app',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id');

  @override
  Future<Map<String, dynamic>?> fetchBehavior(String userId) => _client
      .from('user_behavior_profile')
      .select(
        'avg_weekly_spending, top_spending_categories, '
        'spending_pattern_by_weekday, subscription_load_monthly',
      )
      .eq('user_id', userId)
      .maybeSingle();

  @override
  Future<List<Map<String, dynamic>>> fetchVisits({
    required String userId,
    required DateTime since,
  }) async {
    final rows = await _client
        .from('zad_place_visits')
        .select('returned_at, spent_total, merchants, stores')
        .eq('user_id', userId)
        .gte('returned_at', since.toUtc().toIso8601String())
        .order('returned_at', ascending: false)
        .limit(200);
    return rows.cast<Map<String, dynamic>>();
  }

  @override
  Future<void> deleteVisits(String userId) =>
      _client.from('zad_place_visits').delete().eq('user_id', userId);

  @override
  Future<bool> anyVisits(String userId) async {
    final rows = await _client
        .from('zad_place_visits')
        .select('id')
        .eq('user_id', userId)
        .limit(1);
    return rows.isNotEmpty;
  }
}
