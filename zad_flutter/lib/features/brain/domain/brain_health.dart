/// Whether the proactive brain is working — the pure verdict.
///
/// A port of Kotlin's `data/BrainHealth.kt` (version 2), kept free of the
/// clock, storage and network so the part that decides "the brain has
/// stopped" is covered by plain tests. If it broke silently, the screen would
/// show a green all-clear over a dead brain — the exact failure it exists to
/// make visible.
///
/// The decisions carried over, each paid for on the live database
/// (2026-09-13):
///
/// 1. **The sign of life is proactive tasks only** — `agent_tasks` of any kind
///    but `reminder`, `store_arrival` and `delivery_test`, the same list as
///    `zad_proactive_silence_check`. 257 of 263 `zad_brain_runs` rows were
///    chat turns; counting them let a week of dead scanner read as fine.
/// 2. **The silence threshold follows the customer's own rhythm**: the larger
///    of [BrainHealthLimits.minSilenceHours] and 1.5 × the *median* gap
///    between active days in the last 60 — the median, so the outage's own gap
///    cannot widen the threshold that should catch it.
/// 3. **`queued` is a failure, exactly like `failed`.** The analysis path
///    writes it when the model call falls over and nothing retries it. Plus
///    the server's own ratio check (20 % of at least 5 runs) and a streak of
///    three, which catches a current outage on a small sample.
/// 4. **The retry queue is counted over seven days**, so it clears with time
///    instead of staying red forever — nothing ever marks a row handled.
/// 5. **Overdue or stuck tasks are a real stall**, not just a number.
/// 6. **A new customer with no proactive task yet is healthy**, with a note —
///    "still getting to know you" is not "stopped".
///
/// No text here: reasons are an enum the screen puts into words.
library;

import 'package:flutter/foundation.dart';

/// The thresholds.
abstract final class BrainHealthLimits {
  /// Mirrors `zad-brain/index.ts`'s `DAILY_REQUEST_CAP` default. A cap on
  /// free-plan chat turns only — the scanner never reads `agent_usage`.
  static const int dailyRequests = 60;

  /// Mirrors `DAILY_TOKEN_CAP`.
  static const int dailyTokens = 200000;

  /// Above this the free chat allowance is nearly spent.
  static const double chatQuotaWarnRatio = 0.80;

  /// The shortest silence that counts, even for a daily digest (a day plus
  /// half a day's grace).
  static const int minSilenceHours = 36;

  /// Slack over the usual rhythm before silence is a problem.
  static const double cadenceSlack = 1.5;

  /// How far back the rhythm is read.
  static const int cadenceWindowDays = 60;

  /// The server's `zad_brain_health_check` threshold: 20 % …
  static const double runFailureRatio = 0.20;

  /// … of at least five runs.
  static const int runFailureMinSample = 5;

  /// This many failures in a row are enough on their own.
  static const int consecutiveFailures = 3;

  /// A pending task this late means the executor is not running (the cron is
  /// every five minutes).
  static const int overdueGraceMinutes = 15;

  /// A `running` row older than this was killed half way.
  static const int stuckRunningMinutes = 30;
}

/// One line. `stalled` needs someone to act, not just a quiet day.
enum BrainHealthStatus {
  /// Working.
  healthy,

  /// Worth a look.
  quiet,

  /// Stopped.
  stalled,
}

/// One specific reason. Its [severity] is the only source of how bad it is.
enum BrainHealthReason {
  /// زاد was sending on a known rhythm and stopped.
  proactiveSilent(BrainHealthStatus.stalled),

  /// Tasks past due, or stuck in `running`.
  tasksBackedUp(BrainHealthStatus.stalled),

  /// A real share of runs failing, or the last few in a row.
  runsFailing(BrainHealthStatus.stalled),

  /// Tasks that ran and came back failed this week.
  tasksFailed(BrainHealthStatus.stalled),

  /// Requests written to the retry queue — which nothing on the server
  /// actually retries.
  requestsNotRetried(BrainHealthStatus.quiet),

  /// The free chat allowance is nearly spent.
  chatQuotaNearLimit(BrainHealthStatus.quiet),

  /// No proactive message ever — a new customer. Information, not a fault.
  noProactiveYet(BrainHealthStatus.healthy);

  new(this.severity);

  /// How bad it is.
  final BrainHealthStatus severity;
}

/// What kind the last failure was, instead of its raw text (provider JSON
/// with key numbers and quota names — meaningless to a family, and not theirs
/// to see).
enum BrainFailureKind {
  /// The model provider was busy or out of quota.
  providerBusy,

  /// A request the provider refused as malformed.
  configuration,

  /// Anything else.
  other,
}

/// Buckets a raw error. Order matters: a busy message can carry a 400 in its
/// details.
BrainFailureKind? classifyBrainFailure(String? error) {
  if (error == null || error.trim().isEmpty) return null;
  final e = error.toLowerCase();
  const busy = <String>[
    '429',
    '503',
    'resource_exhausted',
    'unavailable',
    'quota',
    'providerunavailable',
    'overloaded',
  ];
  if (busy.any(e.contains)) return BrainFailureKind.providerBusy;
  const config = <String>[
    '400',
    'invalid_argument',
    'function_declarations',
    'thought_signature',
  ];
  if (config.any(e.contains)) return BrainFailureKind.configuration;
  return BrainFailureKind.other;
}

/// One `zad_brain_runs` row, any trigger.
@immutable
class RunSample {
  /// Creates a sample.
  const new({required this.startedAt, required this.status, this.error});

  /// When it started.
  final DateTime startedAt;

  /// `success`, `failed`, `queued`, `running`, … .
  final String status;

  /// The raw error, if any.
  final String? error;

  /// Failed: `failed` (the chat path), `queued` (the analysis path's failure,
  /// never retried), or `running` long enough to have been killed.
  bool isFailure(DateTime now) => switch (status) {
    'failed' || 'queued' => true,
    'running' =>
      now.difference(startedAt) >
          const Duration(minutes: BrainHealthLimits.stuckRunningMinutes),
    _ => false,
  };
}

/// One `agent_tasks` row. Which fields matter depends on the list it is in.
@immutable
class TaskSample {
  /// Creates a sample.
  const new({
    this.kind = '',
    this.status = '',
    this.createdAt,
    this.scheduledFor,
    this.updatedAt,
  });

  /// What it is — `reminder`, `home_weekly_digest`, … .
  final String kind;

  /// `pending`, `running`, `done`, `failed`.
  final String status;

  /// When it was written.
  final DateTime? createdAt;

  /// When it is due.
  final DateTime? scheduledFor;

  /// Last touched.
  final DateTime? updatedAt;
}

/// Raw samples, as read. Any time filter not named here is the reader's; the
/// decisions are [evaluateBrainHealth]'s.
@immutable
class BrainHealthInput {
  /// Creates the input.
  const new({
    required this.now,
    this.recentRuns = const <RunSample>[],
    this.recentTasksForCadence = const <TaskSample>[],
    this.openTasks = const <TaskSample>[],
    this.failedTasksLast7Days = 0,
    this.queueRowsLast7Days = 0,
    this.insightsLast7Days = 0,
    this.pendingInsights = 0,
    this.driftLast7Days = 0,
    this.activeGoals = 0,
    this.requestsToday = 0,
    this.tokensToday = 0,
  });

  /// The moment the verdict is for.
  final DateTime now;

  /// Runs of the last seven days, any trigger.
  final List<RunSample> recentRuns;

  /// The newest ~500 tasks of any kind; reminders are filtered here, not by
  /// the reader.
  final List<TaskSample> recentTasksForCadence;

  /// Tasks `pending` or `running` now, any age.
  final List<TaskSample> openTasks;

  /// Tasks that failed in the last seven days.
  final int failedTasksLast7Days;

  /// Retry-queue rows of the last seven days.
  final int queueRowsLast7Days;

  /// Insights written in the last seven days.
  final int insightsLast7Days;

  /// Insights not yet seen.
  final int pendingInsights;

  /// Drift events in the last seven days.
  final int driftLast7Days;

  /// Goals the brain is working on.
  final int activeGoals;

  /// Chat requests today (UTC).
  final int requestsToday;

  /// Chat tokens today (UTC), in and out.
  final int tokensToday;

  /// A copy with the given fields replaced.
  BrainHealthInput copyWith({
    List<RunSample>? recentRuns,
    List<TaskSample>? recentTasksForCadence,
    List<TaskSample>? openTasks,
    int? failedTasksLast7Days,
    int? queueRowsLast7Days,
    int? requestsToday,
    int? tokensToday,
  }) => BrainHealthInput(
    now: now,
    recentRuns: recentRuns ?? this.recentRuns,
    recentTasksForCadence: recentTasksForCadence ?? this.recentTasksForCadence,
    openTasks: openTasks ?? this.openTasks,
    failedTasksLast7Days: failedTasksLast7Days ?? this.failedTasksLast7Days,
    queueRowsLast7Days: queueRowsLast7Days ?? this.queueRowsLast7Days,
    insightsLast7Days: insightsLast7Days,
    pendingInsights: pendingInsights,
    driftLast7Days: driftLast7Days,
    activeGoals: activeGoals,
    requestsToday: requestsToday ?? this.requestsToday,
    tokensToday: tokensToday ?? this.tokensToday,
  );
}

/// The verdict and everything the screen shows with it.
@immutable
class BrainHealth {
  /// Creates the verdict.
  const new({
    required this.now,
    required this.reasons,
    this.lastProactiveAt,
    this.proactiveTasksLast7Days = 0,
    this.expectedSilenceHours,
    this.runsLast7Days = 0,
    this.failedRunsLast7Days = 0,
    this.lastFailureKind,
    this.overdueTasks = 0,
    this.stuckRunningTasks = 0,
    this.pendingTasksCount = 0,
    this.failedTasksLast7Days = 0,
    this.queueRowsLast7Days = 0,
    this.insightsLast7Days = 0,
    this.pendingInsights = 0,
    this.driftLast7Days = 0,
    this.activeGoals = 0,
    this.requestsToday = 0,
    this.tokensToday = 0,
  });

  /// The moment it is for.
  final DateTime now;

  /// Every reason that applies, most severe first.
  final List<BrainHealthReason> reasons;

  /// The newest proactive task, or null for none ever.
  final DateTime? lastProactiveAt;

  /// Proactive tasks in the last seven days.
  final int proactiveTasksLast7Days;

  /// The silence allowed by the customer's rhythm; null when the rhythm is
  /// not known yet (the floor was used).
  final int? expectedSilenceHours;

  /// Runs in the last seven days.
  final int runsLast7Days;

  /// Of which failed.
  final int failedRunsLast7Days;

  /// The newest failure's kind.
  final BrainFailureKind? lastFailureKind;

  /// Pending tasks past their grace.
  final int overdueTasks;

  /// Tasks stuck in `running`.
  final int stuckRunningTasks;

  /// Pending tasks, due or not.
  final int pendingTasksCount;

  /// Tasks failed in the last seven days.
  final int failedTasksLast7Days;

  /// Retry-queue rows in the last seven days.
  final int queueRowsLast7Days;

  /// Insights in the last seven days.
  final int insightsLast7Days;

  /// Insights not yet seen.
  final int pendingInsights;

  /// Drift events in the last seven days.
  final int driftLast7Days;

  /// Active goals.
  final int activeGoals;

  /// Chat requests today.
  final int requestsToday;

  /// Chat tokens today.
  final int tokensToday;

  /// The worst reason that applies; none is healthy.
  BrainHealthStatus get status => reasons.fold(
    BrainHealthStatus.healthy,
    (worst, r) => r.severity.index > worst.index ? r.severity : worst,
  );

  /// The larger share used of the two chat allowances — either one closes the
  /// door.
  double get chatQuotaRatio => _quotaRatio(requestsToday, tokensToday);

  /// Whole hours since the last proactive task; null for none; never negative
  /// (a phone clock running ahead).
  int? get hoursSinceLastProactive {
    final last = lastProactiveAt;
    if (last == null) return null;
    final hours = now.difference(last).inHours;
    return hours < 0 ? 0 : hours;
  }

  /// Overdue plus stuck — the figure [BrainHealthReason.tasksBackedUp] names.
  int get tasksBackedUp => overdueTasks + stuckRunningTasks;
}

double _quotaRatio(int requests, int tokens) {
  final a = requests / BrainHealthLimits.dailyRequests;
  final b = tokens / BrainHealthLimits.dailyTokens;
  return a > b ? a : b;
}

/// Task kinds that are not the scanner speaking — the same list as
/// `zad_proactive_silence_check` (read off the live function 2026-09-21).
/// `reminder` is the customer's own ask; `store_arrival` comes from walking
/// into a shop's range, so a shop visit would hide a dead scanner;
/// `delivery_test` rows are tests.
const Set<String> kNonProactiveTaskKinds = <String>{
  'reminder',
  'store_arrival',
  'delivery_test',
};

const int _dayMs = 24 * 60 * 60 * 1000;

/// The silence allowed in hours, or null when the rhythm is not known yet
/// (fewer than two distinct UTC days). Uses the median gap between active
/// days, not the mean, so an outage cannot widen its own threshold.
int? expectedProactiveSilenceHours(List<DateTime> taskTimes) {
  final days =
      taskTimes
          .map((t) => (t.millisecondsSinceEpoch / _dayMs).floor())
          .toSet()
          .toList()
        ..sort();
  if (days.length < 2) return null;
  final gaps = <int>[
    for (var i = 1; i < days.length; i++) days[i] - days[i - 1],
  ]..sort();
  final mid = gaps.length ~/ 2;
  final median = gaps.length.isOdd
      ? gaps[mid].toDouble()
      : (gaps[mid - 1] + gaps[mid]) / 2;
  final cadenceHours = (median * 24 * BrainHealthLimits.cadenceSlack).floor();
  return cadenceHours > BrainHealthLimits.minSilenceHours
      ? cadenceHours
      : BrainHealthLimits.minSilenceHours;
}

/// The verdict.
BrainHealth evaluateBrainHealth(BrainHealthInput input) {
  final now = input.now;
  final weekAgo = now.subtract(const Duration(days: 7));
  final windowStart = now.subtract(
    const Duration(days: BrainHealthLimits.cadenceWindowDays),
  );

  final runs = input.recentRuns
      .where((r) => !r.startedAt.isBefore(weekAgo))
      .toList();
  final failedRuns = runs.where((r) => r.isFailure(now)).toList();
  final newestFirst = [...runs]
    ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  final lastFailureRun = newestFirst.where((r) => r.isFailure(now)).firstOrNull;

  // Decided here rather than in the query, so a test covers it — this is the
  // line between this version and the one that chat activity fooled.
  final proactive = <DateTime>[
    for (final t in input.recentTasksForCadence)
      if (t.kind.trim().isNotEmpty &&
          !kNonProactiveTaskKinds.contains(t.kind) &&
          t.createdAt != null)
        t.createdAt!,
  ];
  final lastProactive = proactive.isEmpty
      ? null
      : proactive.reduce((a, b) => a.isAfter(b) ? a : b);
  final expectedSilence = expectedProactiveSilenceHours(<DateTime>[
    for (final t in proactive)
      if (!t.isBefore(windowStart)) t,
  ]);

  final overdue = input.openTasks.where((t) {
    final due = t.scheduledFor;
    return t.status == 'pending' &&
        due != null &&
        now.difference(due) >
            const Duration(minutes: BrainHealthLimits.overdueGraceMinutes);
  }).length;
  final stuckRunning = input.openTasks.where((t) {
    final touched = t.updatedAt;
    return t.status == 'running' &&
        touched != null &&
        now.difference(touched) >
            const Duration(minutes: BrainHealthLimits.stuckRunningMinutes);
  }).length;
  final pendingCount = input.openTasks
      .where((t) => t.status == 'pending')
      .length;

  final reasons = <BrainHealthReason>[];

  if (lastProactive == null) {
    reasons.add(BrainHealthReason.noProactiveYet);
  } else {
    final silentHours = now.difference(lastProactive).inHours;
    // Rhythm unknown is not "no verdict": the safe floor judges a long
    // silence anyway.
    final allowed = expectedSilence ?? BrainHealthLimits.minSilenceHours;
    if (silentHours > allowed) reasons.add(BrainHealthReason.proactiveSilent);
  }

  if (overdue + stuckRunning > 0) reasons.add(BrainHealthReason.tasksBackedUp);

  final ratioTrips =
      runs.length >= BrainHealthLimits.runFailureMinSample &&
      failedRuns.length / runs.length >= BrainHealthLimits.runFailureRatio;
  final streakTrips =
      newestFirst.length >= BrainHealthLimits.consecutiveFailures &&
      newestFirst
          .take(BrainHealthLimits.consecutiveFailures)
          .every((r) => r.isFailure(now));
  if (ratioTrips || streakTrips) reasons.add(BrainHealthReason.runsFailing);

  if (input.failedTasksLast7Days > 0) {
    reasons.add(BrainHealthReason.tasksFailed);
  }
  if (input.queueRowsLast7Days > 0) {
    reasons.add(BrainHealthReason.requestsNotRetried);
  }
  if (_quotaRatio(input.requestsToday, input.tokensToday) >=
      BrainHealthLimits.chatQuotaWarnRatio) {
    reasons.add(BrainHealthReason.chatQuotaNearLimit);
  }

  // Most severe first; a stable sort keeps equals in the order found.
  final sorted = <BrainHealthReason>[
    for (final level in BrainHealthStatus.values.reversed)
      ...reasons.where((r) => r.severity == level),
  ];

  return BrainHealth(
    now: now,
    reasons: sorted,
    lastProactiveAt: lastProactive,
    proactiveTasksLast7Days: proactive
        .where((t) => !t.isBefore(weekAgo))
        .length,
    expectedSilenceHours: expectedSilence,
    runsLast7Days: runs.length,
    failedRunsLast7Days: failedRuns.length,
    lastFailureKind: lastFailureRun == null
        ? null
        : classifyBrainFailure(lastFailureRun.error) ?? BrainFailureKind.other,
    overdueTasks: overdue,
    stuckRunningTasks: stuckRunning,
    pendingTasksCount: pendingCount,
    failedTasksLast7Days: input.failedTasksLast7Days,
    queueRowsLast7Days: input.queueRowsLast7Days,
    insightsLast7Days: input.insightsLast7Days,
    pendingInsights: input.pendingInsights,
    driftLast7Days: input.driftLast7Days,
    activeGoals: input.activeGoals,
    requestsToday: input.requestsToday,
    tokensToday: input.tokensToday,
  );
}
