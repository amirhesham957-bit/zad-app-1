/// Broke mode and the savings challenge on the server.
///
/// Both are online and read back rather than queued: each is one state row
/// the brain writes too (a customer can say "أنا مفلس" in the chat), so a
/// write this phone queued could land on top of a newer one from the brain.
/// What was last read is cached for the first frame.
library;

import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/features/modes/domain/modes.dart';

/// The two tables. RLS is owner-only on both; the challenge's counters are
/// the server's — the client may update only `status` and `updated_at`.
abstract interface class ModesRemote {
  /// The account's broke-mode row, or null.
  Future<Map<String, dynamic>?> brokeMode(String userId);

  /// Upserts the broke-mode row.
  Future<void> upsertBrokeMode(Map<String, dynamic> row);

  /// Closes broke mode now.
  Future<void> endBrokeMode(String userId, DateTime at);

  /// The active challenge, or null.
  Future<Map<String, dynamic>?> activeChallenge(String userId);

  /// Starts a challenge.
  Future<void> insertChallenge(Map<String, dynamic> row);

  /// Marks a challenge abandoned.
  Future<void> abandonChallenge(String id, DateTime at);
}

/// The real tables.
class SupabaseModesRemote implements ModesRemote {
  /// Creates a remote over a Supabase client.
  const new(this._client);

  final SupabaseClient _client;

  @override
  Future<Map<String, dynamic>?> brokeMode(String userId) => _client
      .from('zad_broke_mode')
      .select()
      .eq('user_id', userId)
      .maybeSingle();

  @override
  Future<void> upsertBrokeMode(Map<String, dynamic> row) =>
      _client.from('zad_broke_mode').upsert(row, onConflict: 'user_id');

  @override
  Future<void> endBrokeMode(String userId, DateTime at) => _client
      .from('zad_broke_mode')
      .update(<String, dynamic>{
        'ended_at': at.toUtc().toIso8601String(),
        'updated_at': at.toUtc().toIso8601String(),
      })
      .eq('user_id', userId);

  @override
  Future<Map<String, dynamic>?> activeChallenge(String userId) => _client
      .from('zad_savings_challenges')
      .select()
      .eq('user_id', userId)
      .eq('status', 'active')
      .maybeSingle();

  @override
  Future<void> insertChallenge(Map<String, dynamic> row) =>
      _client.from('zad_savings_challenges').insert(row);

  @override
  Future<void> abandonChallenge(String id, DateTime at) => _client
      .from('zad_savings_challenges')
      .update(<String, dynamic>{
        'status': 'abandoned',
        'updated_at': at.toUtc().toIso8601String(),
      })
      .eq('id', id);
}

/// Both states, read, written and cached.
class ModesRepository {
  /// Creates a repository.
  const new({
    required Box<String> cache,
    required ModesRemote remote,
    required String? Function() signedInUserId,
  }) : _cache = cache,
       _remote = remote,
       _signedInUserId = signedInUserId;

  final Box<String> _cache;
  final ModesRemote _remote;
  final String? Function() _signedInUserId;

  static const String _brokeKey = 'broke_mode';
  static const String _challengeKey = 'savings_challenge';

  /// What was last read.
  ({BrokeMode? broke, SavingsChallenge? challenge}) cached() => (
    broke: _decode(_cache.get(_brokeKey), BrokeMode.fromJson),
    challenge: _decode(_cache.get(_challengeKey), SavingsChallenge.fromJson),
  );

  /// Reads both and caches them.
  Future<({BrokeMode? broke, SavingsChallenge? challenge})> refresh() async {
    final userId = _requireUserId();
    final broke = await _remote.brokeMode(userId);
    final challenge = await _remote.activeChallenge(userId);
    await _store(_brokeKey, broke);
    await _store(_challengeKey, challenge);
    return cached();
  }

  /// Turns broke mode on with [plan]; true once the row reads back running.
  Future<bool> activateBrokeMode(
    BrokePlan plan, {
    required String? currency,
    required DateTime now,
  }) async {
    final userId = _requireUserId();
    final at = now.toUtc().toIso8601String();
    await _remote.upsertBrokeMode(<String, dynamic>{
      'user_id': userId,
      'started_at': at,
      'ends_at': plan.endsAt.toIso8601String(),
      'ended_at': null,
      'cash_left': plan.cashLeft,
      'daily_cap': plan.dailyCap,
      'currency': currency,
      'source': 'app',
      'updated_at': at,
    });
    final back = (await refresh()).broke;
    return back != null && back.isActiveAt(now);
  }

  /// Turns it off; true once the row reads back closed.
  Future<bool> endBrokeMode({required DateTime now}) async {
    await _remote.endBrokeMode(_requireUserId(), now);
    final back = (await refresh()).broke;
    return back == null || !back.isActiveAt(now);
  }

  /// Starts a challenge; true once it reads back active.
  Future<bool> startChallenge({
    required double dailyCap,
    required int lengthDays,
    required DateTime today,
    required String? currency,
  }) async {
    await _remote.insertChallenge(<String, dynamic>{
      'user_id': _requireUserId(),
      'started_on':
          '${today.year.toString().padLeft(4, '0')}-'
          '${today.month.toString().padLeft(2, '0')}-'
          '${today.day.toString().padLeft(2, '0')}',
      'length_days': lengthDays.clamp(7, 90),
      'daily_cap': dailyCap,
      'currency': currency,
      'source': 'app',
    });
    return (await refresh()).challenge != null;
  }

  /// Stops [id]; true once no active challenge reads back.
  Future<bool> abandonChallenge(String id, {required DateTime now}) async {
    await _remote.abandonChallenge(id, now);
    return (await refresh()).challenge == null;
  }

  Future<void> _store(String key, Map<String, dynamic>? row) async {
    if (row == null) {
      await _cache.delete(key);
    } else {
      await _cache.put(key, jsonEncode(row));
    }
  }

  static T? _decode<T>(String? raw, T Function(Map<String, dynamic>) read) {
    if (raw == null) return null;
    try {
      return read(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      return null;
    }
  }

  String _requireUserId() {
    final id = _signedInUserId();
    if (id == null || id.isEmpty) {
      throw StateError('no signed-in user');
    }
    return id;
  }
}
