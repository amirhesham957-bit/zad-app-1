/// «صح / مش صح» on a weekly learning from the notification (ZAD_PLAN 5.2):
/// `zad_house_learning_answer`, which reads whose learning it is from the
/// session.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/providers.dart';

/// What the server did with the answer.
enum HouseLearningOutcome {
  /// «صح»: it became a memory.
  right,

  /// «مش صح»: it is never said again.
  wrong,

  /// It was answered before, from here or from Telegram.
  already,

  /// No such learning for this account.
  gone,
}

/// Reads the RPC's reply. Unknown shapes are [HouseLearningOutcome.gone]
/// rather than a guess.
HouseLearningOutcome houseLearningOutcomeFrom(Object? reply) {
  if (reply is! Map) return HouseLearningOutcome.gone;
  if (reply['ok'] != true) return HouseLearningOutcome.gone;
  if (reply['already'] == true) return HouseLearningOutcome.already;
  return switch (reply['answer']) {
    'yes' => HouseLearningOutcome.right,
    'no' => HouseLearningOutcome.wrong,
    _ => HouseLearningOutcome.gone,
  };
}

/// Sends the answer.
abstract interface class HouseLearningAnswers {
  /// Answers [learningId]; throws when the call failed.
  Future<HouseLearningOutcome> answer(String learningId, {required bool yes});
}

/// Through the Supabase client.
class SupabaseHouseLearningAnswers implements HouseLearningAnswers {
  /// Creates it on the client the app's providers hold.
  const new(this._ref);

  final Ref _ref;

  @override
  Future<HouseLearningOutcome> answer(
    String learningId, {
    required bool yes,
  }) async {
    final reply = await _ref
        .read(supabaseClientProvider)
        .rpc<Object?>(
          'zad_house_learning_answer',
          params: <String, dynamic>{'p_learning': learningId, 'p_yes': yes},
        );
    return houseLearningOutcomeFrom(reply);
  }
}

/// The answers; tests put a fake here.
final houseLearningAnswersProvider = Provider<HouseLearningAnswers>(
  SupabaseHouseLearningAnswers.new,
);
