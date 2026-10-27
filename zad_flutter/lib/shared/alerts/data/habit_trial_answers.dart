/// The answer to a two-week trial from the notification (ZAD_PLAN 5.4):
/// `zad_habit_trial_answer`, which reads whose trial it is from the session.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/providers.dart';

/// What the server did with the answer.
enum HabitTrialOutcome {
  /// The trial started.
  started,

  /// The proposal was turned down.
  declined,

  /// The habit is kept.
  kept,

  /// The habit is dropped.
  dropped,

  /// It was answered before, from here or from Telegram.
  already,

  /// No such trial for this account.
  gone,
}

/// Reads the RPC's reply. Unknown shapes are [HabitTrialOutcome.gone]
/// rather than a guess.
HabitTrialOutcome habitTrialOutcomeFrom(Object? reply) {
  if (reply is! Map) return HabitTrialOutcome.gone;
  if (reply['ok'] != true) return HabitTrialOutcome.gone;
  if (reply['already'] == true) return HabitTrialOutcome.already;
  return switch (reply['answer']) {
    'start' => HabitTrialOutcome.started,
    'decline' => HabitTrialOutcome.declined,
    'keep' => HabitTrialOutcome.kept,
    'drop' => HabitTrialOutcome.dropped,
    _ => HabitTrialOutcome.gone,
  };
}

/// Sends the answer.
abstract interface class HabitTrialAnswers {
  /// Answers [trialId]; throws when the call failed.
  Future<HabitTrialOutcome> answer(String trialId, {required bool yes});
}

/// Through the Supabase client.
class SupabaseHabitTrialAnswers implements HabitTrialAnswers {
  /// Creates it on the client the app's providers hold.
  const new(this._ref);

  final Ref _ref;

  @override
  Future<HabitTrialOutcome> answer(String trialId, {required bool yes}) async {
    final reply = await _ref
        .read(supabaseClientProvider)
        .rpc<Object?>(
          'zad_habit_trial_answer',
          params: <String, dynamic>{'p_trial': trialId, 'p_yes': yes},
        );
    return habitTrialOutcomeFrom(reply);
  }
}

/// The answers; tests put a fake here.
final habitTrialAnswersProvider = Provider<HabitTrialAnswers>(
  SupabaseHabitTrialAnswers.new,
);
