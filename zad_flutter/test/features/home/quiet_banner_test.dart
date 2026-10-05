// Quiet mode on home (docs/agent/ZAD_LIVING_BRAIN.md slice 29): while the
// customer's quiet period lasts, home says so and until when, and one tap
// takes the alerts back. A failure is said; the banner stays.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:zad/features/home/application/quiet_mode.dart';
import 'package:zad/features/home/presentation/quiet_banner.dart';
import 'package:zad/shared/brain/domain/life_circumstance.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';

void main() {
  setUpAll(tz_data.initializeTimeZones);

  group('the row', () {
    test('only a quiet kind with an end is a quiet period', () {
      expect(
        LifeCircumstance.fromJson(<String, dynamic>{
          'id': 'c1',
          'kind': 'exams',
          'ends_at': '2026-10-08T21:00:00Z',
        })?.kind,
        'exams',
      );
      expect(
        LifeCircumstance.fromJson(<String, dynamic>{
          'id': 'c2',
          'kind': 'shift_spending',
          'ends_at': '2026-11-08T21:00:00Z',
        }),
        isNull,
      );
      expect(
        LifeCircumstance.fromJson(<String, dynamic>{
          'id': 'c3',
          'kind': 'exams',
        }),
        isNull,
      );
    });
  });

  group('the banner', () {
    late List<String> ended;
    late bool serverAgrees;
    LifeCircumstance? current;

    Future<void> pump(WidgetTester tester) async {
      ended = <String>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountTimeZoneProvider.overrideWithValue('Africa/Cairo'),
            quietModeProvider.overrideWith((ref) async => current),
            endQuietModeProvider.overrideWithValue((id) async {
              ended.add(id);
              if (serverAgrees) current = null;
              return serverAgrees;
            }),
          ],
          child: const MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(body: QuietModeBanner()),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets(
      'says until when, in the account zone, and gives the alerts back',
      (tester) async {
        serverAgrees = true;
        // 21:00 UTC is past midnight in Cairo: the 9th, not the 8th.
        current = LifeCircumstance(
          id: 'c1',
          kind: 'exams',
          endsAt: DateTime.utc(2026, 10, 8, 21, 30),
        );
        await pump(tester);
        expect(
          find.text('فترة امتحانات — زاد مهدّي التنبيهات لحد 9/10'),
          findsOneWidget,
        );
        await tester.tap(find.text('رجّع التنبيهات'));
        await tester.pump();
        await tester.pump();
        expect(ended, <String>['c1']);
        expect(find.textContaining('مهدّي التنبيهات'), findsNothing);
      },
    );

    testWidgets('a refusal is said and the banner stays', (tester) async {
      serverAgrees = false;
      current = LifeCircumstance(
        id: 'c2',
        kind: 'exceptional',
        endsAt: DateTime.utc(2026, 10, 8, 10),
      );
      await pump(tester);
      expect(
        find.text('زاد مهدّي التنبيهات لحد 8/10 — الجرعات والمواعيد زي ما هي'),
        findsOneWidget,
      );
      await tester.tap(find.text('رجّع التنبيهات'));
      await tester.pump();
      await tester.pump();
      expect(find.text('مقدرتش أرجّع التنبيهات. جرّب تاني.'), findsOneWidget);
      expect(find.textContaining('مهدّي التنبيهات'), findsOneWidget);
    });

    testWidgets('no quiet period, no banner', (tester) async {
      current = null;
      serverAgrees = true;
      await pump(tester);
      expect(find.byType(TextButton), findsNothing);
    });
  });
}
