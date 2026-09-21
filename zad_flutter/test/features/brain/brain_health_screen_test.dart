// The reader turns rows into a verdict and never a snapshot of zeros; the
// screen says "I cannot see" rather than "all clear" when it cannot read.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/design/zad_theme.dart';
import 'package:zad/features/brain/data/brain_health_repository.dart';
import 'package:zad/features/brain/domain/brain_health.dart';
import 'package:zad/features/brain/presentation/brain_health_screen.dart';

class _Remote implements BrainHealthRemote {
  bool fail = false;
  String? askedDate;
  List<Map<String, dynamic>> cadence = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> open = <Map<String, dynamic>>[];
  Map<String, dynamic>? usageRow;

  Future<T> _answer<T>(T value) async {
    if (fail) throw StateError('offline');
    return value;
  }

  @override
  Future<List<Map<String, dynamic>>> runs(String userId, DateTime since) =>
      _answer(<Map<String, dynamic>>[]);

  @override
  Future<List<Map<String, dynamic>>> cadenceTasks(String userId, int limit) =>
      _answer(cadence);

  @override
  Future<List<Map<String, dynamic>>> openTasks(String userId) => _answer(open);

  @override
  Future<int> failedTasks(String userId, DateTime since) => _answer(0);

  @override
  Future<int> queueRows(String userId, DateTime since) => _answer(0);

  @override
  Future<List<Map<String, dynamic>>> insights(String userId) => _answer(
    <Map<String, dynamic>>[
      <String, dynamic>{
        'created_at': '2026-09-21T08:00:00Z',
        'status': 'pending',
      },
      <String, dynamic>{'created_at': '2026-08-01T08:00:00Z', 'status': 'seen'},
    ],
  );

  @override
  Future<int> driftEvents(String userId, DateTime since) => _answer(0);

  @override
  Future<int> activeGoals(String userId) => _answer(2);

  @override
  Future<Map<String, dynamic>?> usage(String userId, String utcDate) {
    askedDate = utcDate;
    return _answer(usageRow);
  }
}

void main() {
  late _Remote remote;
  // 23:30 in Cairo on the 21st is still the 21st in UTC — and 00:30 Cairo on
  // the 22nd is 21:30 UTC on the 21st. The server's usage_date is UTC.
  final now = DateTime.utc(2026, 9, 21, 21, 30);

  BrainHealthRepository repo() => BrainHealthRepository(
    remote: remote,
    signedInUserId: () => 'user-1',
    now: () => now,
  );

  setUp(() => remote = _Remote());

  group('the reader', () {
    test('asks for usage by the UTC date the server writes', () async {
      await repo().read();
      expect(remote.askedDate, '2026-09-21');
    });

    test('rows become a verdict: insights, goals, quota', () async {
      remote
        ..cadence = <Map<String, dynamic>>[
          <String, dynamic>{
            'kind': 'home_weekly_digest',
            'created_at': '2026-09-21T09:00:00Z',
          },
        ]
        ..usageRow = <String, dynamic>{
          'request_count': 10,
          'input_tokens': 150000,
          'output_tokens': 15000,
        };
      final h = await repo().read();
      expect(h.insightsLast7Days, 1);
      expect(h.pendingInsights, 1);
      expect(h.activeGoals, 2);
      expect(h.tokensToday, 165000);
      expect(h.reasons, contains(BrainHealthReason.chatQuotaNearLimit));
    });

    test('a failed read throws — it is never a snapshot of zeros', () async {
      remote.fail = true;
      await expectLater(repo().read(), throwsA(anything));
    });
  });

  group('the screen', () {
    Future<void> pump(WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(1080, 2400)
        ..devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            brainHealthRepositoryProvider.overrideWithValue(repo()),
            nowProvider.overrideWithValue(() => now),
          ],
          child: MaterialApp(
            theme: ZadTheme.light(),
            home: const Directionality(
              textDirection: TextDirection.rtl,
              child: BrainHealthScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('cannot read: says it cannot see, never "all clear"', (
      tester,
    ) async {
      remote.fail = true;
      await pump(tester);

      expect(find.text('مش شايف العقل دلوقتي'), findsOneWidget);
      expect(find.text('العقل شغال تمام'), findsNothing);
    });

    testWidgets('a new customer reads healthy, with the reason said', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('العقل شغال تمام'), findsOneWidget);
      expect(find.textContaining('زاد لسه بيتعرف عليك'), findsOneWidget);
      expect(find.text('ولا مرة'), findsOneWidget);
    });

    testWidgets('a stalled brain says so, and how long it has been quiet', (
      tester,
    ) async {
      remote.cadence = <Map<String, dynamic>>[
        <String, dynamic>{
          'kind': 'home_weekly_digest',
          'created_at': '2026-09-16T21:30:00Z',
        },
      ];
      await pump(tester);

      expect(find.text('العقل واقف ومحتاج تدخّل'), findsOneWidget);
      expect(
        find.text('زاد بطّل يبعت تنبيهات استباقية من 5 أيام'),
        findsOneWidget,
      );
    });
  });

  test('Arabic counts agree with the number', () {
    expect(durationSince(null), 'ولا مرة');
    expect(durationSince(0), 'دلوقتي');
    expect(durationSince(1), 'ساعة واحدة');
    expect(durationSince(2), 'ساعتين');
    expect(durationSince(5), '5 ساعات');
    expect(durationSince(11), '11 ساعة');
    expect(durationSince(24), 'يوم واحد');
    expect(durationSince(48), 'يومين');
    expect(durationSince(24 * 12), '12 يوم');
  });
}
