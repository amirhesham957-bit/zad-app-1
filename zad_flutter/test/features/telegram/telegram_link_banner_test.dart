// The home's Telegram card: what linking brings, one button that opens the
// bot, and «مش دلوقتي».

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/features/telegram/presentation/telegram_binding.dart';

Future<void> _pump(
  WidgetTester tester, {
  VoidCallback? onLink,
  VoidCallback? onSnooze,
  double textScale = 1,
  double width = 360,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 640));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 640),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Directionality(
          textDirection: TextDirection.rtl,
          // Home scrolls, so the card grows down, never past the screen.
          child: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                TelegramLinkBanner(
                  onLink: onLink ?? () {},
                  onSnooze: onSnooze ?? () {},
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('says why the bot matters and opens it', (tester) async {
    var linked = 0;
    var snoozed = 0;
    await _pump(tester, onLink: () => linked++, onSnooze: () => snoozed++);
    expect(
      find.text('ربط بوت تليجرام (مهم لاكتمال التجربة) ⚠️'),
      findsOneWidget,
    );
    expect(find.textContaining('لتفعيل التنبيهات اللحظية'), findsOneWidget);
    await tester.tap(find.text('تشغيل البوت الآن 🚀'));
    await tester.tap(find.text('مش دلوقتي'));
    expect((linked, snoozed), (1, 1));
  });

  testWidgets('fits a small phone at large text', (tester) async {
    await _pump(tester, textScale: 1.5, width: 320);
    expect(tester.takeException(), isNull);
    final button = tester.getSize(find.byType(FilledButton));
    expect(button.height, greaterThanOrEqualTo(44));
  });
}
