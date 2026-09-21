/// Reads the tables the brain's health is judged from.
///
/// The one reader in the app with no cache on disk, deliberately: this screen
/// exists to stop an all-clear being shown over a brain nobody can see, and a
/// cached snapshot from yesterday is that all-clear. So a failed read is a
/// failure — never a snapshot of zeros — and the screen says it cannot see.
///
/// Every table here is owner-readable under RLS (checked 2026-09-21), so it is
/// nine plain selects, no function and no migration.
library;

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/features/brain/domain/brain_health.dart';

/// The nine reads, as rows.
abstract interface class BrainHealthRemote {
  /// `zad_brain_runs` started at or after [since].
  Future<List<Map<String, dynamic>>> runs(String userId, DateTime since);

  /// The newest [limit] `agent_tasks`, any kind, with `kind` and `created_at`.
  Future<List<Map<String, dynamic>>> cadenceTasks(String userId, int limit);

  /// `agent_tasks` pending or running.
  Future<List<Map<String, dynamic>>> openTasks(String userId);

  /// How many `agent_tasks` failed at or after [since].
  Future<int> failedTasks(String userId, DateTime since);

  /// How many `zad_brain_queue` rows were written at or after [since].
  Future<int> queueRows(String userId, DateTime since);

  /// The newest `zad_insights`, with `created_at` and `status`.
  Future<List<Map<String, dynamic>>> insights(String userId);

  /// How many `agent_drift_events` at or after [since].
  Future<int> driftEvents(String userId, DateTime since);

  /// How many `agent_goals` are active.
  Future<int> activeGoals(String userId);

  /// Today's `agent_usage` row ([utcDate] as `yyyy-mm-dd`), or null.
  Future<Map<String, dynamic>?> usage(String userId, String utcDate);
}

/// The real tables.
class SupabaseBrainHealthRemote implements BrainHealthRemote {
  /// Creates a remote over a Supabase client.
  const new(this._client);

  final SupabaseClient _client;

  /// A ceiling on each read — far above any real week.
  static const int _rows = 500;

  String _iso(DateTime t) => t.toUtc().toIso8601String();

  @override
  Future<List<Map<String, dynamic>>> runs(
    String userId,
    DateTime since,
  ) async =>
      (await _client
              .from('zad_brain_runs')
              .select('started_at, status, error')
              .eq('user_id', userId)
              .gte('started_at', _iso(since))
              .order('started_at', ascending: false)
              .limit(_rows))
          .cast<Map<String, dynamic>>();

  @override
  Future<List<Map<String, dynamic>>> cadenceTasks(
    String userId,
    int limit,
  ) async =>
      (await _client
              .from('agent_tasks')
              .select('kind, created_at')
              .eq('user_id', userId)
              .order('created_at', ascending: false)
              .limit(limit))
          .cast<Map<String, dynamic>>();

  @override
  Future<List<Map<String, dynamic>>> openTasks(String userId) async =>
      (await _client
              .from('agent_tasks')
              .select('status, scheduled_for, updated_at')
              .eq('user_id', userId)
              .inFilter('status', <String>['pending', 'running'])
              .limit(200))
          .cast<Map<String, dynamic>>();

  @override
  Future<int> failedTasks(String userId, DateTime since) async =>
      (await _client
              .from('agent_tasks')
              .select('id')
              .eq('user_id', userId)
              .eq('status', 'failed')
              .gte('updated_at', _iso(since))
              .limit(_rows))
          .length;

  @override
  Future<int> queueRows(String userId, DateTime since) async =>
      (await _client
              .from('zad_brain_queue')
              .select('created_at')
              .eq('user_id', userId)
              .gte('created_at', _iso(since))
              .limit(_rows))
          .length;

  @override
  Future<List<Map<String, dynamic>>> insights(String userId) async =>
      (await _client
              .from('zad_insights')
              .select('created_at, status')
              .eq('user_id', userId)
              .order('created_at', ascending: false)
              .limit(_rows))
          .cast<Map<String, dynamic>>();

  @override
  Future<int> driftEvents(String userId, DateTime since) async =>
      (await _client
              .from('agent_drift_events')
              .select('created_at')
              .eq('user_id', userId)
              .gte('created_at', _iso(since))
              .limit(_rows))
          .length;

  @override
  Future<int> activeGoals(String userId) async =>
      (await _client
              .from('agent_goals')
              .select('status')
              .eq('user_id', userId)
              .eq('status', 'active')
              .limit(_rows))
          .length;

  @override
  Future<Map<String, dynamic>?> usage(String userId, String utcDate) => _client
      .from('agent_usage')
      .select('request_count, input_tokens, output_tokens')
      .eq('user_id', userId)
      .eq('usage_date', utcDate)
      .maybeSingle();
}

/// Turns the nine reads into a verdict.
class BrainHealthRepository {
  /// Creates a repository.
  const new({
    required BrainHealthRemote remote,
    required String? Function() signedInUserId,
    required DateTime Function() now,
  }) : _remote = remote,
       _signedInUserId = signedInUserId,
       _now = now;

  final BrainHealthRemote _remote;
  final String? Function() _signedInUserId;
  final DateTime Function() _now;

  /// How many tasks the rhythm is read from. A heavy user whose tasks are
  /// mostly reminders may have their real proactive history outside this —
  /// an accepted limit, as in Kotlin.
  static const int cadenceLimit = 500;

  /// Reads everything and judges it. Throws when any read fails.
  Future<BrainHealth> read() async {
    final userId = _signedInUserId();
    if (userId == null || userId.isEmpty) {
      throw StateError('no signed-in user to read brain health for');
    }
    final now = _now().toUtc();
    final weekAgo = now.subtract(const Duration(days: 7));
    // The server writes `usage_date` as a UTC date; asking in local time
    // would read yesterday's row after midnight in Cairo.
    final today =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';

    final (
      runs,
      cadence,
      open,
      failedTasks,
      queue,
      insights,
      drift,
      goals,
      usage,
    ) = await (
      _remote.runs(userId, weekAgo),
      _remote.cadenceTasks(userId, cadenceLimit),
      _remote.openTasks(userId),
      _remote.failedTasks(userId, weekAgo),
      _remote.queueRows(userId, weekAgo),
      _remote.insights(userId),
      _remote.driftEvents(userId, weekAgo),
      _remote.activeGoals(userId),
      _remote.usage(userId, today),
    ).wait;

    DateTime? at(Object? v) =>
        v is String ? DateTime.tryParse(v)?.toUtc() : null;
    int count(Object? v) => (v as num?)?.toInt() ?? 0;

    return evaluateBrainHealth(
      BrainHealthInput(
        now: now,
        recentRuns: <RunSample>[
          for (final r in runs)
            if (at(r['started_at']) case final DateTime started)
              RunSample(
                startedAt: started,
                status: (r['status'] as String?) ?? '',
                error: r['error'] as String?,
              ),
        ],
        recentTasksForCadence: <TaskSample>[
          for (final t in cadence)
            TaskSample(
              kind: (t['kind'] as String?) ?? '',
              createdAt: at(t['created_at']),
            ),
        ],
        openTasks: <TaskSample>[
          for (final t in open)
            TaskSample(
              status: (t['status'] as String?) ?? '',
              scheduledFor: at(t['scheduled_for']),
              updatedAt: at(t['updated_at']),
            ),
        ],
        failedTasksLast7Days: failedTasks,
        queueRowsLast7Days: queue,
        insightsLast7Days: insights.where((i) {
          final created = at(i['created_at']);
          return created != null && !created.isBefore(weekAgo);
        }).length,
        pendingInsights: insights.where((i) => i['status'] == 'pending').length,
        driftLast7Days: drift,
        activeGoals: goals,
        requestsToday: count(usage?['request_count']),
        tokensToday:
            count(usage?['input_tokens']) + count(usage?['output_tokens']),
      ),
    );
  }
}
