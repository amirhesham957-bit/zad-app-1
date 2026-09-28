import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/app/splash_screen.dart';

void main() {
  testWidgets('the splash fills the screen and centres «زاد» and the slogan', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: SplashScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.text('زاد'), findsOneWidget);
    expect(find.text('تدبير ذكي لبيت هادئ'), findsOneWidget);

    // The owner's screenshot had it all squeezed in the top corner.
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    final name = tester.getCenter(find.text('زاد'));
    expect(name.dx, closeTo(screen.width / 2, 2));
    expect(name.dy, greaterThan(screen.height / 3));
    expect(name.dy, lessThan(screen.height * 2 / 3));
  });
}
