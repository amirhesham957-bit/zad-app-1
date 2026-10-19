// The home's money steps back with the scroll (ZAD_PLAN ٢.٣) and holds once
// it has; at rest and outside a scrollable it is untouched.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/design/components/zad_scroll_shrink.dart';

void main() {
  test('the step back grows over the distance, then holds', () {
    expect(scrollShrinkAt(0, 240), 0);
    expect(scrollShrinkAt(-40, 240), 0);
    expect(scrollShrinkAt(120, 240), 0.5);
    expect(scrollShrinkAt(240, 240), 1);
    expect(scrollShrinkAt(900, 240), 1);
    expect(scrollShrinkAt(50, 0), 0);
  });

  testWidgets('untouched at rest, scaled and faded once scrolled', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ListView(
          controller: controller,
          children: const <Widget>[
            ZadScrollShrink(child: SizedBox(height: 200, child: Text('money'))),
            SizedBox(height: 2000),
          ],
        ),
      ),
    );
    final fade = find.ancestor(
      of: find.text('money'),
      matching: find.byType(Opacity),
    );
    expect(fade, findsNothing);

    controller.jumpTo(120);
    await tester.pump();
    expect(tester.widget<Opacity>(fade).opacity, closeTo(0.8, 1e-9));
  });

  testWidgets('outside a scrollable it is its child', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.rtl,
        child: ZadScrollShrink(child: Text('money')),
      ),
    );
    expect(find.byType(Opacity), findsNothing);
    expect(find.text('money'), findsOneWidget);
  });
}
