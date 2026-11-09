import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/design/components/zad_scroll_away.dart';

Widget _screen({bool accessible = false, Object? reset}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(400, 800),
      accessibleNavigation: accessible,
    ),
    child: ZadScrollAwayScope(
      resetWhenChanged: reset,
      child: Stack(
        children: <Widget>[
          ListView(
            children: <Widget>[
              for (var i = 0; i < 12; i++) const SizedBox(height: 200),
            ],
          ),
          // At the foot: a drag from the middle must start on the list.
          const Align(
            alignment: Alignment.bottomCenter,
            child: ZadStepsAside(child: Text('float')),
          ),
        ],
      ),
    ),
  ),
);

double _opacity(WidgetTester t) =>
    t.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;

Future<void> _drag(WidgetTester t, double dy) async {
  await t.drag(find.byType(ListView), Offset(0, dy));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('steps aside going down and comes back going up', (t) async {
    await t.pumpWidget(_screen());
    expect(_opacity(t), 1);
    await _drag(t, -600);
    expect(_opacity(t), 0);
    await _drag(t, 200);
    expect(_opacity(t), 1);
  });

  testWidgets('comes back at the very end of the list', (t) async {
    await t.pumpWidget(_screen());
    await _drag(t, -600);
    expect(_opacity(t), 0);
    await _drag(t, -5000);
    expect(_opacity(t), 1);
  });

  testWidgets('taps pass through while it is away', (t) async {
    await t.pumpWidget(_screen());
    await _drag(t, -600);
    final ignore = find.ancestor(
      of: find.byType(AnimatedSlide),
      matching: find.byType(IgnorePointer),
    );
    expect(t.widget<IgnorePointer>(ignore.first).ignoring, isTrue);
  });

  testWidgets('never moves for TalkBack', (t) async {
    await t.pumpWidget(_screen(accessible: true));
    await _drag(t, -600);
    expect(_opacity(t), 1);
  });

  testWidgets('a new tab brings it back', (t) async {
    await t.pumpWidget(_screen(reset: 'home'));
    await _drag(t, -600);
    expect(_opacity(t), 0);
    await t.pumpWidget(_screen(reset: 'money'));
    await t.pumpAndSettle();
    expect(_opacity(t), 1);
  });
}
