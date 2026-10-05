// A block that enters with ZadAppearOnEntry keeps its height in a lazy list,
// so scrolling back up moves by the drag and never throws the list to the top
// (home, 2026-10-05: a 200px drag up from 2176 landed at 250).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/design/components/zad_appear.dart';

void main() {
  testWidgets('scrolling back up through a lazy list moves by the drag', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: <Widget>[
              for (var i = 0; i < 20; i++)
                ZadAppearOnEntry(
                  delayMs: 30,
                  child: SizedBox(height: 300, child: Text('$i')),
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position;

    for (var i = 0; i < 10; i++) {
      await tester.drag(find.byType(Scrollable), const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
    // Ten drags of 400 moved exactly 4000: no block below came in at zero.
    expect(position.pixels, closeTo(4000, 1));

    for (var i = 0; i < 6; i++) {
      final before = position.pixels;
      await tester.drag(find.byType(Scrollable), const Offset(0, 200));
      await tester.pump(const Duration(milliseconds: 16));
      expect(position.pixels, closeTo(before - 200, 1), reason: 'drag $i');
      await tester.pump(const Duration(seconds: 1));
      expect(position.pixels, closeTo(before - 200, 1), reason: 'settle $i');
    }
  });
}
