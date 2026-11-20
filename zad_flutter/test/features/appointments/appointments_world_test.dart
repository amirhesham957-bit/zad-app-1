// The appointments world: the next appointment sits on top with its
// countdown, and an empty list shows a real empty state with the docked
// «ميعاد جديد» action still reachable.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/features/appointments/data/appointments_repository.dart';
import 'package:zad/features/appointments/domain/appointments.dart';
import 'package:zad/features/appointments/presentation/appointments_screen.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';

import '../../support/quiet_household.dart';

class _Repo implements AppointmentsRepository {
  new(this.items);
  final List<Appointment> items;

  @override
  List<Appointment>? view() => items;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() async {
    tz_data.initializeTimeZones();
    await initializeDateFormatting('ar');
  });

  Future<void> open(WidgetTester tester, List<Appointment> items) async {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!
          ..physicalSize = const Size(800, 2800)
          ..devicePixelRatio = 1;
    addTearDown(view.reset);
    TestWidgetsFlutterBinding
        .instance
        .platformDispatcher
        .accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );
    addTearDown(
      TestWidgetsFlutterBinding
          .instance
          .platformDispatcher
          .clearAccessibilityFeaturesTestValue,
    );
    final now = DateTime.utc(2026, 11, 20, 8);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...quietHouseholdOverrides,
          accountTimeZoneProvider.overrideWithValue('Africa/Cairo'),
          appointmentsRepositoryProvider.overrideWithValue(_Repo(items)),
          nowProvider.overrideWithValue(() => now),
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
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('the next appointment shows with its countdown', (tester) async {
    await open(tester, <Appointment>[
      (
        id: 'a1',
        title: 'دكتور الأسنان',
        kind: 'medical',
        startsAt: DateTime.utc(2026, 11, 20, 10),
        startsAtRaw: '2026-11-20T10:00:00Z',
        placeLabel: null,
        recurrence: 'once',
        status: 'upcoming',
        forPerson: null,
      ),
    ]);
    expect(find.text('بعد ساعتين'), findsOneWidget);
    expect(find.text('دكتور الأسنان'), findsWidgets);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('no appointments shows the empty state and the add action', (
    tester,
  ) async {
    await open(tester, const <Appointment>[]);
    expect(find.text('مفيش مواعيد جاية'), findsWidgets);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}
