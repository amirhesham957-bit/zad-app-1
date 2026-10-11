// What Home shows of the brain's insights, what a dismissal teaches it, and
// that a decision is believed only when the row says so.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/core/data/sync/outbox.dart';
import 'package:zad/core/data/sync/outbox_entry.dart';
import 'package:zad/shared/insights/data/insights_repository.dart';
import 'package:zad/shared/insights/domain/insight.dart';

ZadInsight _i(
  String id, {
  String priority = 'normal',
  String kind = 'insight',
  int day = 1,
  String? about,
}) => ZadInsight(
  id: id,
  title: 'عنوان $id',
  body: 'نص $id',
  kind: kind,
  priority: priority,
  aboutItem: about,
  createdAt: DateTime.utc(2026, 9, day),
);

class _Remote implements InsightsRemote {
  final Map<String, Map<String, dynamic>> rows = <String, Map<String, dynamic>>{
    'a': <String, dynamic>{
      'id': 'a',
      'kind': 'insight',
      'title': 'اشتراكك في نتفليكس',
      'body': 'بيتجدد بكرة',
      'status': 'pending',
      'about_item': 'نتفليكس',
      'created_at': '2026-09-20T10:00:00Z',
    },
    'q': <String, dynamic>{
      'id': 'q',
      'kind': 'question',
      'title': 'فاضل قد إيه من البنادول؟',
      'body': '',
      'status': 'pending',
      'created_at': '2026-09-21T10:00:00Z',
    },
  };
  final List<({String scope, String note, double confidence})> notes =
      <({String scope, String note, double confidence})>[];
  bool offline = false;
  bool ignoresUpdates = false;

  @override
  Future<List<Map<String, dynamic>>> fetchPending(String userId) async {
    if (offline) throw const SocketException('offline');
    return <Map<String, dynamic>>[
      for (final r in rows.values)
        if (r['status'] == 'pending') <String, dynamic>{...r},
    ];
  }

  @override
  Future<void> setStatus(String id, String status, {String? reason}) async {
    if (offline) throw const SocketException('offline');
    if (ignoresUpdates) return;
    rows[id]?['status'] = status;
    rows[id]?['dismiss_reason'] = reason;
  }

  @override
  Future<String?> statusOf(String id) async => rows[id]?['status'] as String?;

  final List<({String id, DateTime at})> seenCalls =
      <({String id, DateTime at})>[];

  @override
  Future<DateTime?> markSeen(String id, DateTime at) async {
    if (offline) throw const SocketException('offline');
    seenCalls.add((id: id, at: at));
    final row = rows[id];
    if (row == null) return null;
    // The server keeps the first report.
    row['seen_at'] ??= at.toUtc().toIso8601String();
    return DateTime.parse(row['seen_at'] as String);
  }

  @override
  Future<void> remember({
    required String userId,
    required String scope,
    required String note,
    required double confidence,
  }) async => notes.add((scope: scope, note: note, confidence: confidence));
}

const Duration _hour = Duration(hours: 1);
final DateTime _noon = DateTime.utc(2026, 10, 11, 12);

void main() {
  group('homeInsights', () {
    test('critical first, then newest, three at most', () {
      final shown = homeInsights(<ZadInsight>[
        _i('old'),
        _i('new', day: 9),
        _i('crit', priority: 'critical', day: 2),
        _i('mid', day: 5),
      ]);
      expect(shown.map((i) => i.id), <String>['crit', 'new', 'mid']);
    });
  });

  test("dismissal notes are Kotlin's, word for word", () {
    final i = _i('x', about: 'نتفليكس');
    expect(dismissalNote(DismissReason.notRelevant, i), (
      scope: 'dismissal',
      note: 'مش مهتم بتنبيهات زي "نتفليكس"',
      confidence: 0.5,
    ));
    expect(dismissalNote(DismissReason.wrongData, i), (
      scope: 'data_quality',
      note: 'العميل قال إن "نتفليكس" غلط — البيانات المصدر محتاجة مراجعة',
      confidence: 0.7,
    ));
    expect(dismissalNote(DismissReason.timing, _i('y')), (
      scope: 'dismissal',
      note: 'عرف بالفعل عن "عنوان y" وقت الرفض ده',
      confidence: 0.3,
    ));
    // The wire values zad-brain's snapshot reads.
    expect(DismissReason.values.map((r) => r.wire), <String>[
      'not_relevant',
      'wrong_data',
      'timing',
    ]);
  });

  test('an answer names the question it answers', () {
    expect(
      answerMessage(_i('q', kind: 'question'), '  تلات شرايط '),
      'ردًا على سؤالك «عنوان q»: تلات شرايط',
    );
  });

  group('the repository', () {
    late Directory dir;
    late Box<String> documents;
    late Box<String> outboxBox;
    late _Remote remote;
    late Outbox outbox;
    late InsightsRepository repo;
    var run = 0;
    // How far the outbox's clock is ahead — past a failed send's backoff.
    var later = Duration.zero;

    setUp(() async {
      run++;
      dir = await Directory.systemTemp.createTemp('zad_insights_test');
      Hive.init(dir.path);
      documents = await Hive.openBox<String>('documents$run');
      outboxBox = await Hive.openBox<String>('outbox$run');
      remote = _Remote();
      later = Duration.zero;
      outbox = Outbox(
        box: outboxBox,
        clock: () => DateTime.now().add(later),
        send: (entry) => switch (entry.kind) {
          OutboxKind.resolveInsight => repo.sendQueued(entry),
          OutboxKind.markInsightSeen => repo.sendQueuedSeen(entry),
          _ => throw StateError('no sender'),
        },
      );
      repo = InsightsRepository(
        cache: documents,
        remote: remote,
        outbox: () => outbox,
        signedInUserId: () => 'user-1',
      );
    });

    tearDown(() async {
      await Hive.deleteFromDisk();
      await dir.delete(recursive: true);
    });

    test('a dismissal made offline hides the card through a refresh', () async {
      await repo.refresh();
      final a = repo.cached().firstWhere((i) => i.id == 'a');

      remote.offline = true;
      await repo.dismiss(a, reason: DismissReason.notRelevant);
      await outbox.flush();
      remote.offline = false;

      // The server still says pending; the queued dismissal wins on screen.
      expect((await repo.refresh()).map((i) => i.id), <String>['q']);
    });

    test(
      'a reasoned dismissal lands with its reason and teaches the brain',
      () async {
        await repo.refresh();
        final a = repo.cached().firstWhere((i) => i.id == 'a');

        await repo.dismiss(a, reason: DismissReason.wrongData);
        await outbox.flush();

        expect(remote.rows['a']!['status'], 'dismissed');
        expect(remote.rows['a']!['dismiss_reason'], 'wrong_data');
        expect(remote.notes.single.scope, 'data_quality');
        expect(outbox.entries(), isEmpty);
      },
    );

    test('a question put off carries no reason and teaches nothing', () async {
      await repo.refresh();
      final q = repo.cached().firstWhere((i) => i.id == 'q');

      await repo.dismiss(q);
      await outbox.flush();

      expect(remote.rows['q']!['status'], 'dismissed');
      expect(remote.rows['q']!['dismiss_reason'], isNull);
      expect(remote.notes, isEmpty);
    });

    test('a card shown is reported once, at the first showing', () async {
      await repo.refresh();
      final first = DateTime.utc(2026, 10, 11, 14);
      expect(await repo.markSeen(repo.cached(), first), 2);
      // Shown again before the queue drains: nothing new is queued.
      expect(await repo.markSeen(repo.cached(), first.add(_hour)), 0);
      await outbox.flush();

      expect(remote.seenCalls.map((c) => c.id), unorderedEquals(['a', 'q']));
      expect(remote.seenCalls.every((c) => c.at == first), isTrue);
      expect(outbox.entries(), isEmpty);
      // The cache knows now, so a later showing queues nothing.
      expect(repo.cached().every((i) => i.seenAt == first), isTrue);
      expect(await repo.markSeen(repo.cached(), first.add(_hour)), 0);
    });

    test(
      'a card shown offline is reported when the signal comes back',
      () async {
        await repo.refresh();
        remote.offline = true;
        await repo.markSeen(repo.cached().where((i) => i.id == 'a'), _noon);
        await outbox.flush();
        expect(outbox.entries().single.kind, OutboxKind.markInsightSeen);

        remote.offline = false;
        later = const Duration(hours: 1);
        await outbox.flush();
        expect(remote.rows['a']!['seen_at'], _noon.toIso8601String());
        expect(remote.rows['a']!['status'], 'pending', reason: 'still on Home');
        expect(outbox.entries(), isEmpty);
      },
    );

    test(
      'a card deleted on the server before the report lands is let go',
      () async {
        await repo.refresh();
        await repo.markSeen(repo.cached().where((i) => i.id == 'a'), _noon);
        remote.rows.remove('a');
        await outbox.flush();
        expect(outbox.entries(), isEmpty);
      },
    );

    test('a status the row does not show is not believed', () async {
      await repo.refresh();
      remote.ignoresUpdates = true;
      final a = repo.cached().firstWhere((i) => i.id == 'a');

      await repo.markActed(a);
      final entry = outbox.entries().single;
      await expectLater(repo.sendQueued(entry), throwsA(isA<StateError>()));
      expect(remote.notes, isEmpty, reason: 'no note for an unlanded decision');
    });
  });
}
