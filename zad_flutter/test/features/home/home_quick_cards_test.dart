// Home's two quick cards open their screens through ZadScreens.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/core/l10n/generated/zad_l10n.dart';
import 'package:zad/features/home/presentation/home_quick_cards.dart';
import 'package:zad/shared/navigation/destinations.dart';
import 'package:zad/shared/navigation/zad_screens.dart';

void main() {
  testWidgets('render and open recipes and offers', (tester) async {
    HouseholdSection? opened;
    var offers = 0;
    ZadScreens.showHouseholdSection = (c, s) async => opened = s;
    ZadScreens.showOffersScreen = (c) async => offers++;
    await tester.pumpWidget(
      MaterialApp(
        theme: ZadTheme.light(),
        locale: const Locale('ar'),
        localizationsDelegates: ZadL10n.localizationsDelegates,
        supportedLocales: ZadL10n.supportedLocales,
        home: const Scaffold(body: HomeQuickCards()),
      ),
    );
    expect(find.text('نطبخ إيه؟'), findsOneWidget);
    expect(find.text('عروض اليوم'), findsOneWidget);

    await tester.tap(find.text('نطبخ إيه؟'));
    await tester.pump();
    expect(opened, HouseholdSection.recipes);

    await tester.tap(find.text('عروض اليوم'));
    await tester.pump();
    expect(offers, 1);
  });
}
