// The verdict that decides "the brain has stopped". Ported case for case from
// Kotlin's BrainHealthTest: each one pins a way the first version lied.

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/features/brain/domain/brain_health.dart';

final _now = DateTime.utc(2026, 9, 10, 12);
DateTime _hoursAgo(int h) => _now.subtract(Duration(hours: h));
DateTime _daysAgo(int d) => _now.subtract(Duration(days: d));
DateTime _minutesAgo(int m) => _now.subtract(Duration(minutes: m));

/// A working brain: a daily proactive rhythm over eleven days, the newest two
/// hours ago, and ten successful runs in the last day. Each case changes one
/// thing.
BrainHealthInput _base() => BrainHealthInput(
  now: _now,
  recentRuns: <RunSample>[
    for (var i = 0; i < 10; i++)
      RunSample(startedAt: _hoursAgo(i + 1), status: 'success'),
  ],
  recentTasksForCadence: <TaskSample>[
    for (var d = 0; d <= 10; d++)
      TaskSample(
        kind: 'home_weekly_digest',
        createdAt: _hoursAgo(2).subtract(Duration(days: d)),
      ),
  ],
  insightsLast7Days: 3,
  activeGoals: 1,
  requestsToday: 5,
  tokensToday: 10000,
);

List<TaskSample> _digestsFrom(int daysAgo) => <TaskSample>[
  for (var d = 0; d <= 10; d++)
    TaskSample(kind: 'home_weekly_digest', createdAt: _daysAgo(daysAgo + d)),
];

void main() {
  test('a healthy baseline has no reasons and is healthy', () {
    final h = evaluateBrainHealth(_base());
    expect(h.reasons, isEmpty);
    expect(h.status, BrainHealthStatus.healthy);
  });

  test('chat activity does not mask a dead proactive brain', () {
    final h = evaluateBrainHealth(
      _base().copyWith(
        recentTasksForCadence: _digestsFrom(5),
        recentRuns: <RunSample>[
          for (var i = 0; i < 20; i++)
            RunSample(startedAt: _hoursAgo(i + 1), status: 'success'),
        ],
      ),
    );
    expect(h.reasons, contains(BrainHealthReason.proactiveSilent));
    expect(h.status, BrainHealthStatus.stalled);
  });

  test('a store visit or a delivery test does not mask a dead brain', () {
    final h = evaluateBrainHealth(
      _base().copyWith(
        recentTasksForCadence: <TaskSample>[
          TaskSample(kind: 'store_arrival', createdAt: _hoursAgo(1)),
          TaskSample(kind: 'delivery_test', createdAt: _hoursAgo(2)),
          TaskSample(kind: 'reminder', createdAt: _hoursAgo(3)),
          ..._digestsFrom(5),
        ],
      ),
    );
    expect(h.reasons, contains(BrainHealthReason.proactiveSilent));
    expect(h.status, BrainHealthStatus.stalled);
  });

  test('a queued run counts as a failure, like failed', () {
    expect(
      RunSample(startedAt: _hoursAgo(1), status: 'queued').isFailure(_now),
      isTrue,
    );
  });

  test('queued rows push the failure ratio over the threshold', () {
    const statuses = <String>[
      'success', 'success', 'success', 'failed', 'success', //
      'success', 'queued', 'queued', 'success', 'success',
    ];
    final h = evaluateBrainHealth(
      _base().copyWith(
        recentRuns: <RunSample>[
          for (var i = 0; i < statuses.length; i++)
            RunSample(
              startedAt: _hoursAgo(i + 1),
              status: statuses[i],
              error: statuses[i] == 'success' ? null : 'boom',
            ),
        ],
      ),
    );
    expect(h.reasons, contains(BrainHealthReason.runsFailing));
  });

  test('three failures in a row trip it under the sample floor', () {
    final h = evaluateBrainHealth(
      _base().copyWith(
        recentRuns: <RunSample>[
          for (var i = 1; i <= 3; i++)
            RunSample(startedAt: _hoursAgo(i), status: 'failed'),
        ],
      ),
    );
    expect(h.reasons, contains(BrainHealthReason.runsFailing));
  });

  test('two in a row on a small sample do not', () {
    final h = evaluateBrainHealth(
      _base().copyWith(
        recentRuns: <RunSample>[
          for (var i = 1; i <= 2; i++)
            RunSample(startedAt: _hoursAgo(i), status: 'failed'),
        ],
      ),
    );
    expect(h.reasons, isNot(contains(BrainHealthReason.runsFailing)));
  });

  test('a running run only fails once it is stuck', () {
    expect(
      RunSample(startedAt: _minutesAgo(5), status: 'running').isFailure(_now),
      isFalse,
    );
    expect(
      RunSample(startedAt: _minutesAgo(45), status: 'running').isFailure(_now),
      isTrue,
    );
  });

  test('an overdue pending task trips tasksBackedUp; inside grace not', () {
    final overdue = evaluateBrainHealth(
      _base().copyWith(
        openTasks: <TaskSample>[
          TaskSample(status: 'pending', scheduledFor: _minutesAgo(20)),
        ],
      ),
    );
    expect(overdue.reasons, contains(BrainHealthReason.tasksBackedUp));
    expect(overdue.status, BrainHealthStatus.stalled);

    final inGrace = evaluateBrainHealth(
      _base().copyWith(
        openTasks: <TaskSample>[
          TaskSample(status: 'pending', scheduledFor: _minutesAgo(10)),
        ],
      ),
    );
    expect(inGrace.reasons, isNot(contains(BrainHealthReason.tasksBackedUp)));
  });

  test('a stuck running task trips it on its own', () {
    final stuck = evaluateBrainHealth(
      _base().copyWith(
        openTasks: <TaskSample>[
          TaskSample(status: 'running', updatedAt: _minutesAgo(40)),
        ],
      ),
    );
    expect(stuck.reasons, contains(BrainHealthReason.tasksBackedUp));

    final fresh = evaluateBrainHealth(
      _base().copyWith(
        openTasks: <TaskSample>[
          TaskSample(status: 'running', updatedAt: _minutesAgo(5)),
        ],
      ),
    );
    expect(fresh.reasons, isNot(contains(BrainHealthReason.tasksBackedUp)));
  });

  test('a new customer is noProactiveYet and healthy, not stalled', () {
    final h = evaluateBrainHealth(
      _base().copyWith(recentTasksForCadence: const <TaskSample>[]),
    );
    expect(h.reasons, <BrainHealthReason>[BrainHealthReason.noProactiveYet]);
    expect(h.status, BrainHealthStatus.healthy);
    expect(h.lastProactiveAt, isNull);
  });

  test("a weekly rhythm's usual gap is fine and a longer one is not", () {
    List<TaskSample> weekly(List<int> days) => <TaskSample>[
      for (final d in days)
        TaskSample(kind: 'weekly_digest', createdAt: _daysAgo(d)),
    ];
    final usual = evaluateBrainHealth(
      _base().copyWith(recentTasksForCadence: weekly(<int>[35, 28, 21, 14, 5])),
    );
    expect(usual.reasons, isNot(contains(BrainHealthReason.proactiveSilent)));

    final silent = evaluateBrainHealth(
      _base().copyWith(recentTasksForCadence: weekly(<int>[35, 28, 21, 14])),
    );
    expect(silent.reasons, contains(BrainHealthReason.proactiveSilent));
  });

  test('the rhythm needs two distinct days and uses the median gap', () {
    expect(expectedProactiveSilenceHours(const <DateTime>[]), isNull);
    expect(expectedProactiveSilenceHours(<DateTime>[_hoursAgo(1)]), isNull);
    expect(expectedProactiveSilenceHours(<DateTime>[_now, _now, _now]), isNull);
    // Gaps of 7, 7, 7, 9 days: median 7 → 7 × 24 × 1.5 = 252 hours.
    expect(
      expectedProactiveSilenceHours(<DateTime>[
        for (final d in <int>[35, 28, 21, 14, 5]) _daysAgo(d),
      ]),
      252,
    );
  });

  test('with no known rhythm the 36-hour floor judges', () {
    BrainHealth single(int hoursSilent) => evaluateBrainHealth(
      _base().copyWith(
        recentTasksForCadence: <TaskSample>[
          TaskSample(
            kind: 'home_weekly_digest',
            createdAt: _hoursAgo(hoursSilent),
          ),
        ],
      ),
    );
    expect(
      single(35).reasons,
      isNot(contains(BrainHealthReason.proactiveSilent)),
    );
    expect(single(37).reasons, contains(BrainHealthReason.proactiveSilent));
  });

  test('queue rows alone only reach quiet', () {
    final h = evaluateBrainHealth(_base().copyWith(queueRowsLast7Days: 3));
    expect(h.reasons, contains(BrainHealthReason.requestsNotRetried));
    expect(h.status, BrainHealthStatus.quiet);
  });

  test('the chat allowance near its cap is quiet, by tokens or requests', () {
    final tokens = evaluateBrainHealth(_base().copyWith(tokensToday: 190000));
    expect(tokens.reasons, contains(BrainHealthReason.chatQuotaNearLimit));
    expect(tokens.status, BrainHealthStatus.quiet);

    final requests = evaluateBrainHealth(_base().copyWith(requestsToday: 54));
    expect(requests.reasons, contains(BrainHealthReason.chatQuotaNearLimit));
    expect(requests.status, BrainHealthStatus.quiet);
  });

  test('failures are bucketed busy, configuration or other', () {
    expect(
      classifyBrainFailure('429 Too Many Requests'),
      BrainFailureKind.providerBusy,
    );
    expect(
      classifyBrainFailure('RESOURCE_EXHAUSTED: quota'),
      BrainFailureKind.providerBusy,
    );
    expect(
      classifyBrainFailure('400 INVALID_ARGUMENT: bad function_declarations'),
      BrainFailureKind.configuration,
    );
    expect(
      classifyBrainFailure('connection reset by peer'),
      BrainFailureKind.other,
    );
    expect(classifyBrainFailure(null), isNull);
    expect(classifyBrainFailure(''), isNull);
    expect(classifyBrainFailure('   '), isNull);
  });

  test('the last failure kind is the newest failing run', () {
    final h = evaluateBrainHealth(
      _base().copyWith(
        recentRuns: <RunSample>[
          RunSample(startedAt: _hoursAgo(1), status: 'success'),
          RunSample(
            startedAt: _hoursAgo(2),
            status: 'failed',
            error: '429 quota exceeded',
          ),
          RunSample(
            startedAt: _hoursAgo(3),
            status: 'failed',
            error: '400 invalid_argument',
          ),
        ],
      ),
    );
    expect(h.lastFailureKind, BrainFailureKind.providerBusy);
  });

  test('reasons come most severe first', () {
    final h = evaluateBrainHealth(
      _base().copyWith(
        openTasks: <TaskSample>[
          TaskSample(status: 'pending', scheduledFor: _minutesAgo(30)),
        ],
        queueRowsLast7Days: 2,
        tokensToday: 170000,
      ),
    );
    expect(
      h.reasons,
      containsAll(<BrainHealthReason>[
        BrainHealthReason.tasksBackedUp,
        BrainHealthReason.requestsNotRetried,
        BrainHealthReason.chatQuotaNearLimit,
      ]),
    );
    final severities = h.reasons.map((r) => r.severity.index).toList();
    expect(severities, [...severities]..sort((a, b) => b.compareTo(a)));
    expect(h.status, BrainHealthStatus.stalled);
  });

  test('no runs never trips runsFailing and never divides by zero', () {
    final h = evaluateBrainHealth(
      _base().copyWith(recentRuns: const <RunSample>[]),
    );
    expect(h.runsLast7Days, 0);
    expect(h.failedRunsLast7Days, 0);
    expect(h.reasons, isNot(contains(BrainHealthReason.runsFailing)));
  });

  test('hours since the last proactive never go negative', () {
    final h = evaluateBrainHealth(
      _base().copyWith(
        recentTasksForCadence: <TaskSample>[
          TaskSample(
            kind: 'home_weekly_digest',
            createdAt: _now.add(const Duration(days: 5)),
          ),
        ],
      ),
    );
    expect(h.hoursSinceLastProactive, 0);
  });

  test('pending counts every pending task, overdue or not', () {
    final h = evaluateBrainHealth(
      _base().copyWith(
        openTasks: <TaskSample>[
          TaskSample(status: 'pending', scheduledFor: _minutesAgo(5)),
          TaskSample(status: 'pending', scheduledFor: _minutesAgo(30)),
          TaskSample(status: 'running', updatedAt: _minutesAgo(5)),
          const TaskSample(status: 'done'),
        ],
      ),
    );
    expect(h.pendingTasksCount, 2);
  });
}
