/// «بلّغ عن الرد» (ZAD_PLAN 8.3): the customer reports one of Zad's replies.
///
/// Google Play asks apps that generate content to let people report
/// offensive output from inside the app. Online and direct, like any other
/// tap with an answer on screen: the customer sees whether it reached us.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/providers.dart';

/// Why a reply was reported — the server's `reason` values.
enum ReplyReportReason {
  /// Offensive or inappropriate.
  offensive,

  /// Wrong or misleading.
  wrong,

  /// Advice that could cause harm.
  harmful,

  /// Something else.
  other,
}

/// Sends one report through `zad_report_reply`. True when the server kept it.
typedef ReplyReporter = Future<bool> Function({
  required String messageId,
  required String text,
  required ReplyReportReason reason,
});

/// The reporter the chat uses; a test overrides it.
final replyReporterProvider = Provider<ReplyReporter>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return ({required messageId, required text, required reason}) async {
    try {
      final result = await client.rpc<Object?>(
        'zad_report_reply',
        params: <String, dynamic>{
          'p_message_id': messageId,
          'p_reply_text': text,
          'p_reason': reason.name,
        },
      );
      return result is Map && result['ok'] == true;
    } on Object {
      return false;
    }
  };
});
