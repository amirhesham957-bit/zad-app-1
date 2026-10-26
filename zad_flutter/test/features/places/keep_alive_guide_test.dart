// The battery guide: says what to do when it cannot tell the state, and
// lists the steps per brand on a tap.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/core/l10n/generated/zad_l10n.dart';
import 'package:zad/features/places/presentation/keep_alive_guide.dart';

void main() {
  testWidgets('shows the fix and the per-brand steps', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ZadTheme.light(),
        locale: const Locale('ar'),
        localizationsDelegates: ZadL10n.localizationsDelegates,
        supportedLocales: ZadL10n.supportedLocales,
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
    // Battery optimisation still on (or unknown): the button asks for the
    // exemption rather than only pointing at settings (ZAD_PLAN 2.1).
    expect(find.text('افتح إعدادات زاد'), findsNothing);
    await tester.tap(find.text('خلّي زاد شغال دايماً'));
    await tester.pump();
  });
}
