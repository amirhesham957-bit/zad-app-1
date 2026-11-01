// A tall sheet stops under the status bar, not behind it.
//
// `isScrollControlled: true` lets a sheet grow to the full screen, and without
// `useSafeArea: true` its top edge and drag handle draw behind the clock and
// battery — seen on the emulator on the quick-expense and Telegram sheets,
// 2026-11-01. Every scroll-controlled `showModalBottomSheet` in lib/ has to
// pass both.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every scroll-controlled sheet passes useSafeArea: true', () {
    final offenders = <String>[];
    final call = RegExp(
      r'showModalBottomSheet\s*<[^>]*>\s*\(|showModalBottomSheet\s*\(',
    );
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      for (final match in call.allMatches(source)) {
        final args = _arguments(source, match.end);
        if (args.contains('isScrollControlled: true') &&
            !args.contains('useSafeArea: true')) {
          final line =
              '\n'.allMatches(source.substring(0, match.start)).length + 1;
          offenders.add('${entity.path}:$line');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'add `useSafeArea: true` beside `isScrollControlled: true`',
    );
  });
}

/// The argument list that opens just before [start], up to its closing paren.
String _arguments(String source, int start) {
  var depth = 1;
  for (var i = start; i < source.length; i++) {
    final c = source[i];
    if (c == '(') depth++;
    if (c == ')' && --depth == 0) return source.substring(start, i);
  }
  return source.substring(start);
}
