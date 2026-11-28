// The bar fits a 320dp phone, also with the system font at 1.3x.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/app/shell/zad_bottom_nav_bar.dart';
import 'package:zad/core/design/zad_theme.dart';

void main() {
  for (final kids in <bool>[false, true]) {
    for (final scale in <double>[1, 1.3]) {
      testWidgets('kids=$kids fits 320dp at text scale $scale', (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: ZadTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                bottomNavigationBar: ZadBottomNavBar(
                  current: ZadNavDestination.home,
                  kidsMode: kids,
                  onNavigate: (_) {},
                  onOpenCamera: () {},
                  onOpenVoice: () {},
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(ZadBottomNavBar), findsOneWidget);
      });
    }
  }
}
