// One brain (تشخيص زاد ١.١): nothing in the app talks to a language model
// with instructions written on the phone.
//
// Before 2026-10-01 the «اشرحلي» cards, the support chat and the loans tab
// each sent their own system prompt through `ai_text` — a second, third and
// fourth Zad, without the customer's memory or the brain's tools. They now
// ask zad-brain, and `ai_text` is gone from the server. This test keeps it
// that way: a screen that needs the model asks the brain (`agent_turn`,
// `explain`) or a named server action, never a prompt of its own.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// What a prompt written on the phone looks like on the wire.
final Map<String, RegExp> _forbidden = <String, RegExp>{
  'the removed free-prompt actions': RegExp(
    """['"](ai_text|brain_evaluate)['"]""",
  ),
  'a prompt field in a request body': RegExp(
    r"""['"](system_prompt|systemPrompt|user_prompt|system_instruction|systemInstruction)['"]\s*:""",
  ),
  'a model provider called directly': RegExp(
    r'generativelanguage\.googleapis\.com|api\.groq\.com|openrouter\.ai|api\.openai\.com|api\.anthropic\.com',
  ),
};

void main() {
  test('no screen talks to a model with a prompt of its own', () {
    final offenders = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final file in files) {
      final source = file.readAsStringSync();
      for (final MapEntry(key: what, value: pattern) in _forbidden.entries) {
        if (pattern.hasMatch(source)) offenders.add('${file.path}: $what');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Ask zad-brain (agent_turn / explain) or a named server action '
          'instead — one Zad, with the memory and the tools.',
    );
  });
}
