// م٦.٤: the three switches start off and write through the repository, and
// today's screen shows what was read or says plainly that nothing was.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/features/notification_reads/data/notification_reads_repository.dart';
import 'package:zad/features/notification_reads/presentation/notification_reads_screens.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';

class _Fake implements NotificationReadsRepository {
  new({this.reads = const <NotificationRead>[]});

  final List<NotificationRead> reads;
  final Map<ReadKind, bool> stored = <ReadKind, bool>{};
  final List<(ReadKind, bool)> calls = <(ReadKind, bool)>[];
  DateTime? since;

  @override
  Future<Map<ReadKind, bool>> switches() async => Map.of(stored);

  @override
  Future<void> setSwitch(ReadKind kind, {required bool enabled}) async {
    calls.add((kind, enabled));
    stored[kind] = enabled;
  }

  @override
  Future<List<NotificationRead>> readsSince(DateTime s) async {
    since = s;
    return reads;
  }
}

Future<void> _pump(WidgetTester tester, _Fake repo, Widget screen) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        notificationReadsRepositoryProvider.overrideWithValue(repo),
        accountTimeZoneProvider.overrideWithValue('Africa/Cairo'),
        // 2026-11-22 21:30 UTC is already the 23rd in Cairo (UTC+2).
        nowProvider.overrideWithValue(() => DateTime.utc(2026, 11, 22, 23, 30)),
      ],
      child: MaterialApp(
        theme: ZadTheme.light(),
        home: Directionality(textDirection: TextDirection.rtl, child: screen),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(tz_data.initializeTimeZones);

  testWidgets('all three switches are off by default, each with its line', (
    tester,
  ) async {
    await _pump(tester, _Fake(), const NotificationReadsSwitchesScreen());
    expect(find.text('حجوزات الدكتور'), findsOneWidget);
    expect(find.text('الطيران'), findsOneWidget);
    expect(find.text('أبشر والخدمات'), findsOneWidget);
    expect(find.textContaining('والنص بيتمسح'), findsNWidgets(3));
    final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
    expect(switches, hasLength(3));
    expect(switches.every((s) => !s.value), isTrue);
  });

  testWidgets('toggling calls the repository with the kind', (tester) async {
    final repo = _Fake();
    await _pump(tester, repo, const NotificationReadsSwitchesScreen());
    await tester.tap(find.byType(Switch).at(1));
    await tester.pumpAndSettle();
    expect(repo.calls, <(ReadKind, bool)>[(ReadKind.trip, true)]);
    expect(tester.widget<Switch>(find.byType(Switch).at(1)).value, isTrue);
    expect(tester.widget<Switch>(find.byType(Switch).at(0)).value, isFalse);
  });

  testWidgets('a stored switch shows as on', (tester) async {
    final repo = _Fake()..stored[ReadKind.documentDue] = true;
    await _pump(tester, repo, const NotificationReadsSwitchesScreen());
    expect(tester.widget<Switch>(find.byType(Switch).at(2)).value, isTrue);
  });

  testWidgets('empty state when nothing was read today', (tester) async {
    await _pump(tester, _Fake(), const NotificationReadsTodayScreen());
    expect(find.text('لسه مفيش حاجة اتقرت النهارده'), findsOneWidget);
  });

  testWidgets('today starts at midnight in the account zone', (tester) async {
    final repo = _Fake();
    await _pump(tester, repo, const NotificationReadsTodayScreen());
    // Cairo midnight of the 23rd is 22:00 UTC on the 22nd.
    expect(repo.since, DateTime.utc(2026, 11, 22, 22));
  });

  testWidgets('lists the reads with kind and extracted fields', (tester) async {
    final repo = _Fake(
      reads: <NotificationRead>[
        NotificationRead(
          id: '1',
          kind: ReadKind.appointment,
          readAt: DateTime.utc(2026, 11, 22, 23),
          date: '2026-11-25',
          time: '10:30',
          place: 'مستشفى السلام',
        ),
        NotificationRead(
          id: '2',
          kind: ReadKind.trip,
          readAt: DateTime.utc(2026, 11, 22, 23, 10),
          title: 'رحلة القاهرة - الرياض',
        ),
      ],
    );
    await _pump(tester, repo, const NotificationReadsTodayScreen());
    expect(find.text('حجوزات الدكتور'), findsOneWidget);
    expect(find.text('الطيران'), findsOneWidget);
    expect(find.textContaining('2026-11-25'), findsOneWidget);
    expect(find.textContaining('10:30'), findsOneWidget);
    expect(find.textContaining('مستشفى السلام'), findsOneWidget);
    expect(find.text('رحلة القاهرة - الرياض'), findsOneWidget);
    expect(find.text('لسه مفيش حاجة اتقرت النهارده'), findsNothing);
  });

  test('fromRow keeps only the extracted fields and skips unknown kinds', () {
    final r = NotificationRead.fromRow(<String, dynamic>{
      'id': 'x',
      'kind': 'document_due',
      'read_at': '2026-11-22T10:00:00Z',
      'extracted': <String, dynamic>{'date': '2026-12-01', 'place': ' '},
    });
    expect(r?.kind, ReadKind.documentDue);
    expect(r?.date, '2026-12-01');
    expect(r?.place, isNull);
    expect(
      NotificationRead.fromRow(<String, dynamic>{
        'id': 'y',
        'kind': 'other',
        'read_at': '2026-11-22T10:00:00Z',
      }),
      isNull,
    );
  });
}
