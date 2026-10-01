/// The support screen's assistant: زاد herself (zad-brain's `agent_turn` with
/// `surface: support`), who sees the account, solves what she can and opens a
/// ticket for the team when a person is needed (`open_support_ticket`).
///
/// It used to be a separate model with its own prompt that saw no account
/// data and could not reach a person: zero tickets were ever opened from it
/// (the «تشخيص زاد» report, 2026-10-01).
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/features/support/domain/support_faq.dart';

/// Answers one usage question.
class SupportAssistant {
  /// Creates the assistant over a Supabase client.
  const new(this._client);

  final SupabaseClient _client;

  /// What is left when neither the model nor a built-in answer helps: what
  /// to do next, instead of Kotlin's bare apology.
  static const String fallback =
      'مش قادر أرد دلوقتي. جرّب تاني كمان شوية، ولو المشكلة مستمرة افتح '
      '«سجل الأعطال» من الشاشة دي وابعته لنا — فيه اللي نحتاجه عشان نصلحها.';

  /// Long enough for the server to walk its model chain; after that the
  /// customer gets [fallback] instead of a typing dot that never ends.
  static const Duration timeout = Duration(seconds: 40);

  /// The model's answer; when it cannot be had, the built-in answer to the
  /// question if one fits ([faqAnswer]), and only then [fallback].
  Future<String> ask(String question) async =>
      await _askModel(question) ?? faqAnswer(question) ?? fallback;

  Future<String?> _askModel(String question) async {
    try {
      final response = await _client.functions
          .invoke(
            'zad-brain',
            body: <String, dynamic>{
              'action': 'agent_turn',
              'message': question,
              'surface': 'support',
            },
          )
          .timeout(timeout);
      final data = response.data;
      if (data is! Map || data['ok'] != true) return null;
      final reply = (data['reply'] as String?)?.trim() ?? '';
      final receipts = <String>[
        for (final e
            in (data['executed'] as List<Object?>?) ?? const <Object?>[])
          if (e is Map && e['summary'] is String) '✅ ${e['summary']}',
      ];
      final answer = <String>[
        if (reply.isNotEmpty) reply,
        ...receipts,
      ].join('\n');
      return answer.isEmpty ? null : answer;
    } on Object {
      return null;
    }
  }
}

/// The support screen's usage-help assistant.
final supportAssistantProvider = Provider<SupportAssistant>(
  (ref) => SupportAssistant(ref.watch(supabaseClientProvider)),
);
