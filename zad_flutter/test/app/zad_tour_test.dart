// The tour lights each stop in turn and closes on the last, or on skip.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/app/shell/zad_tour.dart';
import 'package:zad/core/l10n/generated/zad_l10n.dart';

void main() {
  final target = GlobalKey();

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: ZadL10n.localizationsDelegates,
        supportedLocales: ZadL10n.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: TextButton(
                key: target,
                onPressed: () => Navigator.of(context).push<void>(
                  PageRouteBuilder<void>(
                    opaque: false,
                    pageBuilder: (_, _, _) => ZadTourOverlay(
                      steps: <ZadTourStep>[
                        const ZadTourStep(title: 'أهلاً', body: 'مقدمة'),
                        ZadTourStep(
                          title: 'الزرار',
                          body: 'شرح',
                          target: target,
                        ),
                      ],
                    ),
                  ),
                ),
                child: const Text('افتح'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('افتح'));
    await tester.pumpAndSettle();
  }

  testWidgets('walks the stops, then closes', (tester) async {
    await open(tester);
    expect(find.text('أهلاً'), findsOneWidget);
    expect(find.text('1 من 2'), findsOneWidget);

    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();
    expect(find.text('الزرار'), findsOneWidget);
    expect(find.text('تخطي'), findsNothing, reason: 'nothing left to skip');

    await tester.tap(find.text('يلا نبدأ'));
    await tester.pumpAndSettle();
    expect(find.byType(ZadTourOverlay), findsNothing);
  });

  testWidgets('skip closes from the first stop', (tester) async {
    await open(tester);
    await tester.tap(find.text('تخطي'));
    await tester.pumpAndSettle();
    expect(find.byType(ZadTourOverlay), findsNothing);
  });
}
