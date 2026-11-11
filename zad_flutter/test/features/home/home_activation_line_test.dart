import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/core/l10n/generated/zad_l10n.dart';
import 'package:zad/features/home/presentation/home_activation_card.dart';

import '../../support/fonts.dart';

void main() {
  setUpAll(loadZadFonts);

  // ZAD_PLAN ١٠.٨: the four-step card became one line on Home.
  testWidgets('one line: how many are done, and the next step a tap away', (
    tester,
  ) async {
    var did = 0;
    var toggled = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: ZadTheme.light(),
        locale: const Locale('ar'),
        localizationsDelegates: ZadL10n.localizationsDelegates,
        supportedLocales: ZadL10n.supportedLocales,
        home: Scaffold(
          body: Column(
            children: <Widget>[
              SizedBox(
                width: 360,
                child: HomeActivationLine(
                  done: 3,
                  total: 4,
                  next: 'فعّل قراءة إشعارات البنك',
                  open: false,
                  onNext: () => did++,
                  onToggle: () => toggled++,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('3 من 4'), findsOneWidget);
    expect(
      tester.getSize(find.byType(HomeActivationLine)).height,
      lessThan(80),
    );

    await tester.tap(find.text('فعّل قراءة إشعارات البنك'));
    expect((did, toggled), (1, 0));
    await tester.tap(find.text('جهّز زاد لبيتك'));
    expect((did, toggled), (1, 1));
  });
}
