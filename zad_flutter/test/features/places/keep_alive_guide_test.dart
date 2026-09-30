// The battery guide: says what to do when it cannot tell the state, and
// lists the steps per brand on a tap.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/features/places/presentation/keep_alive_guide.dart';

void main() {
  testWidgets('shows the fix and the per-brand steps', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ZadTheme.light(),
        home: const Scaffold(
          body: SingleChildScrollView(child: KeepAliveGuide()),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('عشان زاد يفضل صاحي في الخلفية'), findsOneWidget);
    expect(find.text('شاومي / ريدمي / بوكو'), findsNothing);
    await tester.tap(find.text('الخطوات لموبايلي'));
    await tester.pump();
    for (final (brand, _) in kKeepAliveSteps) {
      expect(find.text(brand), findsOneWidget);
    }
    await tester.tap(find.text('افتح إعدادات زاد'));
    await tester.pump();
  });
}
