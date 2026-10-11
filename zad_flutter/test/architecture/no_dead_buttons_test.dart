// No control in lib/ answers a tap with nothing.
//
// The pre-launch audit (2026-10-11) found the smart scanner's gear —
// `onPressed: () {}` under an English tooltip — and the shell walkthrough
// passed over it, because a tap that changes nothing is not a crash. This is
// the cheap half of that guard: an empty tap handler fails the build. A
// control that should do nothing yet takes `null` (Flutter draws it
// disabled).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final RegExp _emptyHandler = RegExp(
  r'\bon(Pressed|Tap|LongPress|DoubleTap)\s*:\s*'
  r'\(\s*_?\s*\)\s*(async\s*)?\{\s*\}',
);

void main() {
  test('no empty tap handler in lib/', () {
    final found = <String>[];
    for (final file
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      final text = file.readAsStringSync();
      for (final m in _emptyHandler.allMatches(text)) {
        final line = '\n'.allMatches(text.substring(0, m.start)).length + 1;
        found.add('${file.path}:$line  ${m.group(0)}');
      }
    }
    expect(found, isEmpty, reason: 'a control that does nothing when tapped');
  });

  test('the guard sees what it guards against', () {
    expect(_emptyHandler.hasMatch('onPressed: () {},'), isTrue);
    expect(_emptyHandler.hasMatch('onTap: () async {}'), isTrue);
    // A display-only radio under IgnorePointer has to pass something; it is
    // not a button (life_goal_picker_sheet.dart).
    expect(_emptyHandler.hasMatch('onChanged: (_) {}'), isFalse);
    expect(_emptyHandler.hasMatch('onPressed: () {\n  save();\n}'), isFalse);
    expect(_emptyHandler.hasMatch('onPressed: null'), isFalse);
  });
}
