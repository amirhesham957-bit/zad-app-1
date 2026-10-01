/// «اشرحلي ده» from a screen, answered by زاد herself: zad-brain's `explain`.
///
/// Screens used to call the model with their own personas («أنت محلل مالي
/// شخصي…», «أنت مستشار ديون…»), a different speaker on every card who knew
/// neither the customer's name nor their dialect. The brain answers with the
/// chat's identity and a small context.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

/// What a screen can ask to be explained; the server holds the instructions.
enum ZadExplainTopic {
  /// «اختبار الصمود»: how long the money lasts if income stops.
  resilience('resilience'),

  /// Where the money went, as behaviour.
  spendingBehavior('spending_behavior'),

  /// The loan payoff plan.
  debtPlan('debt_plan');

  new(this.wire);

  /// The topic as the server names it.
  final String wire;
}

/// The explanation of [data] (what the screen shows), or null when زاد
/// could not answer.
Future<String?> explainWithZad(
  SupabaseClient client,
  ZadExplainTopic topic,
  String data,
) async {
  try {
    final response = await client.functions.invoke(
      'zad-brain',
      body: <String, dynamic>{
        'action': 'explain',
        'topic': topic.wire,
        'data': data,
      },
    );
    final body = response.data;
    final text = body is Map ? body['text'] : null;
    return text is String && text.trim().isNotEmpty ? text.trim() : null;
  } on Object {
    return null;
  }
}
