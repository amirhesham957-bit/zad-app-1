// ZAD_PLAN 6.2 — the sort of every Arabic string in lib/, made a gate.
//
// An Arabic literal in the code is one of two things (CLAUDE.md's i18n rule):
//  * data — matched against a bank message, stored in a column, sent to the
//    model — which must stay Arabic: translating it breaks a feature silently,
//    with a green build;
//  * text on the screen, which belongs in lib/core/l10n/*.arb.
//
// Data is declared, never guessed:
//  * a whole file in [_dataFiles] (every literal in it was read and is data);
//  * one line, by a trailing `// l10n: data` comment.
// Everything else is screen text not yet moved to the ARB files, counted per
// file in tool/l10n/arabic_ui_baseline.json. A file may only go down: a new
// Arabic string on a screen fails here until it is in the ARB or declared
// data. When a translation slice moves strings out, lower the baseline with
//   ZAD_L10N_REBASELINE=1 flutter test test/architecture/arabic_literals_test.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Files whose every Arabic literal is data. Each was read string by string.
const Set<String> _dataFiles = <String>{
  // Matched against the bank notification's own text.
  'shared/bank/domain/bank_keywords.dart',
  // Matched against the item name the customer typed.
  'shared/inventory/domain/food_emoji.dart',
  'shared/inventory/domain/product_family.dart',
  // Alternative spellings matched against a subscription's title.
  'features/subscriptions/presentation/subscription_brands.dart',
  // Category keys stored in zad_inventory.category / zad_transactions.category,
  // and the words that file a row under one. Their English labels, when they
  // come, are a lookup over these keys — the keys themselves never change.
  'features/inventory/domain/pantry_categories.dart',
  'shared/transactions/domain/expense_categories.dart',
  // Text for the Arabic voice (TTS): punctuation the speech is split on, and
  // the openers spoken while the brain thinks. The voice follows the
  // customer's language in 6.4, on the server.
  'shared/voice/domain/speech_text.dart',
  'shared/voice/data/voice_openers.dart',
};

const String _baselinePath = 'tool/l10n/arabic_ui_baseline.json';

final RegExp _arabic = RegExp('[\u0600-\u06FF]');
final RegExp _literal = RegExp(
  r"'(?:[^'\\\n]|\\.)*'"
  '|'
  r'"(?:[^"\\\n]|\\.)*"',
);

/// Arabic literals in [source] that are not declared data, line by line.
int arabicUiLiterals(String source) {
  var n = 0;
  for (final line in const LineSplitter().convert(source)) {
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('//')) continue;
    if (line.contains('// l10n: data')) continue;
    n += _literal
        .allMatches(line)
        .where((m) => _arabic.hasMatch(m.group(0)!))
        .length;
  }
  return n;
}

Map<String, int> _measure() {
  final counts = <String, int>{};
  final lib = Directory('lib');
  for (final entity in lib.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final rel = entity.path.substring('lib/'.length);
    if (rel.startsWith('core/l10n/generated/')) continue;
    if (_dataFiles.contains(rel)) continue;
    final n = arabicUiLiterals(entity.readAsStringSync());
    if (n > 0) counts[rel] = n;
  }
  return Map<String, int>.fromEntries(
    counts.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );
}

void main() {
  test('counts literals, skips comments and declared data', () {
    expect(arabicUiLiterals("Text('أهلاً')"), 1);
    expect(arabicUiLiterals("Text('hello')"), 0);
    expect(arabicUiLiterals("/// 'كلام'"), 0);
    expect(arabicUiLiterals("unit: 'كجم', // l10n: data"), 0);
    expect(arabicUiLiterals("a('x', 'ب', \"ج\")"), 2);
  });

  test('every data file still exists', () {
    for (final f in _dataFiles) {
      expect(File('lib/$f').existsSync(), isTrue, reason: f);
    }
  });

  test('no screen gains an Arabic string outside the ARB files', () {
    final now = _measure();
    final file = File(_baselinePath);
    if (Platform.environment['ZAD_L10N_REBASELINE'] == '1') {
      file
        ..createSync(recursive: true)
        ..writeAsStringSync(
          '${const JsonEncoder.withIndent('  ').convert(now)}\n',
        );
      return;
    }
    final baseline = (jsonDecode(file.readAsStringSync()) as Map)
        .cast<String, int>();
    final grew = <String>[
      for (final e in now.entries)
        if (e.value > (baseline[e.key] ?? 0))
          '${e.key}: ${baseline[e.key] ?? 0} → ${e.value}',
    ];
    expect(
      grew,
      isEmpty,
      reason:
          'New Arabic text on a screen. Put it in lib/core/l10n/app_ar.arb '
          '(and app_en.arb) and read it with context.l10n — or, if it is '
          'matched, stored or sent to the model, end the line with '
          '`// l10n: data`.',
    );
  });
}
