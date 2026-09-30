/// The usage-help assistant behind the support screen: one `ai_text` call on
/// `zad-core-intelligence`, with Kotlin's `HelpSupportScreen` prompt word for
/// word. It sees no account data — the prompt says so and sends anyone asking
/// about their own money to the real agent chat.
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

  static const String _systemPrompt = '''
أنت مساعد أسئلة استخدام تطبيق "زاد ZAD" لإدارة المصاريف العائلية والمخزون.
مهمتك الرد على أسئلة عامة عن استخدام التطبيق وميزاته وحل مشاكل تقنية شائعة فقط.
- التطبيق يحتوي على: إدارة ميزانية، شات عائلي، كاميرا ذكية لقراءة الفواتير، مخزون المنزل، إحصائيات، عقل زاد (المساعد الذكي الشخصي).
- قاعدة إلزامية: معندكش أي وصول لبيانات المستخدم الفعلية (مصاريفه، رصيده، اشتراكاته، مخزونه). لو سأل عن أي حاجة من دي، وضّح إنك مش شايف حسابه، ووجّهه لشات "عقل زاد" اللي شايف بياناته الحقيقية.
- كن مهذباً، محترفاً، ومتعاطفاً.
- أجب باللغة العربية بوضوح وإيجاز.''';

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
            'zad-core-intelligence',
            body: <String, dynamic>{
              'action': 'ai_text',
              'user_id': _client.auth.currentUser?.id,
              'payload': <String, dynamic>{
                'system_prompt': _systemPrompt,
                'user_prompt': question,
                'response_mime_type': 'text/plain',
                // A how-do-I question needs no reasoning trace; unbounded
                // thinking only made the customer wait.
                'thinking_budget': 0,
              },
            },
          )
          .timeout(timeout);
      final data = response.data;
      final text = data is Map ? data['text'] : null;
      return text is String && text.trim().isNotEmpty ? text.trim() : null;
    } on Object {
      return null;
    }
  }
}

/// The support screen's usage-help assistant.
final supportAssistantProvider = Provider<SupportAssistant>(
  (ref) => SupportAssistant(ref.watch(supabaseClientProvider)),
);
