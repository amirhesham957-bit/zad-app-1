/// The usage-help assistant behind the support screen: one `ai_text` call on
/// `zad-core-intelligence`, with Kotlin's `HelpSupportScreen` prompt word for
/// word. It sees no account data — the prompt says so and sends anyone asking
/// about their own money to the real agent chat.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

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

  /// What Kotlin shows when the model gives nothing back.
  static const String fallback =
      'عذراً، لم أتمكن من معالجة طلبك حالياً، يرجى المحاولة لاحقاً.';

  /// The answer, or [fallback] on any failure.
  Future<String> ask(String question) async {
    try {
      final response = await _client.functions.invoke(
        'zad-core-intelligence',
        body: <String, dynamic>{
          'action': 'ai_text',
          'user_id': _client.auth.currentUser?.id,
          'payload': <String, dynamic>{
            'system_prompt': _systemPrompt,
            'user_prompt': question,
            'response_mime_type': 'text/plain',
          },
        },
      );
      final data = response.data;
      final text = data is Map ? data['text'] : null;
      return text is String && text.trim().isNotEmpty ? text.trim() : fallback;
    } on Object {
      return fallback;
    }
  }
}
