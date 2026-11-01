// ٨ج.٥ from the page: «حفظ» asks the brain's booking guard first — the same
// check the chat's add_appointment runs — shows its reasons, and only a
// second «احفظه برضه» saves. No answer (offline) saves as before.
//
// The repository and outbox are recording fakes: a Hive put inside a widget
// test never completes under the fake clock.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/data/sync/outbox.dart';
import 'package:zad/core/data/sync/outbox_entry.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/features/appointments/data/appointments_repository.dart';
import 'package:zad/features/appointments/data/booking_guard.dart';
import 'package:zad/features/appointments/domain/appointments.dart';
import 'package:zad/features/appointments/presentation/appointments_screen.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';

import '../../support/quiet_household.dart';

class _Guard implements BookingGuard {
  new(this.answer);

  final List<String>? answer;
  final List<String> asked = <String>[];

  @override
  Future<List<String>?> check({
    required String title,
    required String kind,
    required DateTime startsAt,
    required String recurrence,
    String? forPerson,
  }) async {
    asked.add('$title@${startsAt.toUtc().toIso8601String()}');
    return answer;
  }
}

class _Repo implements AppointmentsRepository {
  final List<String> added = <String>[];

  @override
  List<Appointment>? view() => null;

  @override
  Future<String> add({
    required String title,
    required String kind,
    required DateTime startsAt,
    required int remindMinutesBefore,
    required String recurrence,
    String? placeLabel,
    String? forPerson,
  }) async {
    added.add(title);
    return 'a1';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Outbox implements Outbox {
  @override
  Future<OutboxFlushReport> flush() => Future<OutboxFlushReport>.error('off');

  @override
  List<OutboxEntry> deadLetters() => const <OutboxEntry>[];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() async {
    tz_data.initializeTimeZones();
    await initializeDateFormatting('ar');
  });

  Future<(_Guard, _Repo)> open(
    WidgetTester tester,
    List<String>? answer,
  ) async {
    final guard = _Guard(answer);
    final repo = _Repo();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...quietHouseholdOverrides,
          accountTimeZoneProvider.overrideWithValue('Africa/Cairo'),
          appointmentsRepositoryProvider.overrideWithValue(repo),
          outboxProvider.overrideWithValue(_Outbox()),
          bookingGuardProvider.overrideWithValue(guard),
        ],
        child: MaterialApp(
          theme: ZadTheme.light(),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: AppointmentsScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('ميعاد جديد'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'دكتور الأسنان');
    await tester.pump();
    return (guard, repo);
  }

  testWidgets(
    "the guard's reasons stop the first save; «احفظه برضه» keeps it",
    (tester) async {
      final (guard, repo) = await open(tester, <String>[
        'الوقت ده جوه مواعيد شغلك («من ٩ لـ٥»)',
      ]);
      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();
      expect(guard.asked, hasLength(1));
      expect(repo.added, isEmpty);
      expect(find.textContaining('مواعيد شغلك'), findsOneWidget);

      await tester.tap(find.text('احفظه برضه'));
      await tester.pumpAndSettle();
      expect(
        guard.asked,
        hasLength(1),
        reason: 'already answered for this one',
      );
      expect(repo.added, <String>['دكتور الأسنان']);
    },
  );

  testWidgets('changing the appointment asks again', (tester) async {
    final (guard, repo) = await open(tester, <String>[
      'في نفس الوقت تقريباً فيه «البنك»',
    ]);
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'دكتور العيون');
    await tester.pump();
    expect(find.text('احفظه برضه'), findsNothing);
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();
    expect(guard.asked, hasLength(2));
    expect(repo.added, isEmpty);
  });

  testWidgets('no reasons, or no answer at all, saves on the first tap', (
    tester,
  ) async {
    for (final answer in <List<String>?>[const <String>[], null]) {
      final (guard, repo) = await open(tester, answer);
      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();
      expect(guard.asked, hasLength(1));
      expect(repo.added, <String>['دكتور الأسنان'], reason: '$answer');
    }
  });

  // CI, 2026-11-01 23:10 Cairo: the default was `(hour + 1) % 24` on today's
  // date — 00:00 today, already past — and the three tests above failed.
  test('the default is the next whole hour, on its own date', () {
    final cairo = tz.getLocation('Africa/Cairo');
    var (date, time) = nextWholeHour(tz.TZDateTime(cairo, 2026, 11, 1, 23, 10));
    expect(date, DateTime(2026, 11, 2));
    expect(time, const TimeOfDay(hour: 0, minute: 0));
    (date, time) = nextWholeHour(tz.TZDateTime(cairo, 2026, 10, 31, 23, 59));
    expect(date, DateTime(2026, 11));
    expect(time, const TimeOfDay(hour: 0, minute: 0));
    (date, time) = nextWholeHour(tz.TZDateTime(cairo, 2026, 11, 1, 14, 20));
    expect(date, DateTime(2026, 11));
    expect(time, const TimeOfDay(hour: 15, minute: 0));
  });

  test("the answer's say lines, or null when it is not an answer", () {
    expect(
      bookingConflictLines(<String, dynamic>{
        'ok': true,
        'conflicts': <Map<String, String>>[
          <String, String>{'kind': 'dose', 'say': 'الصيدلية بتفكّرك أصلاً'},
          <String, String>{'kind': 'clash'},
        ],
      }),
      <String>['الصيدلية بتفكّرك أصلاً'],
    );
    expect(
      bookingConflictLines(<String, dynamic>{
        'ok': true,
        'conflicts': <Object>[],
      }),
      isEmpty,
    );
    expect(bookingConflictLines(<String, dynamic>{'ok': false}), isNull);
    expect(bookingConflictLines('oops'), isNull);
  });
}
