// A two-week trial's buttons on the notification (ZAD_PLAN 5.4): the push
// names the trial and its stage, the payload carries both, and a press is
// routed to the answer — a tap on the notification opens the home.

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/alerts/application/alerts_controller.dart';
import 'package:zad/shared/alerts/data/habit_trial_answers.dart';
import 'package:zad/shared/alerts/data/push_platform.dart';
import 'package:zad/shared/alerts/domain/push_alert.dart';

void main() {
  test(
    'the push names the trial and its stage; anything else is a plain alert',
    () {
      final alert = PushAlert.fromMessage(
        data: const <String, dynamic>{
          'title': '🧪',
          'body': 'نجرب؟',
          'kind': 'habit_trial',
          'trial_id': 't-1',
          'stage': 'measured',
          'route': 'home',
        },
      );
      expect(alert.habitTrial, (id: 't-1', stage: HabitTrialStage.measured));
      expect(alert.destination, AlertDestination.home);
      for (final data in <Map<String, dynamic>>[
        <String, dynamic>{
          'kind': 'habit_trial',
          'trial_id': 't-1',
          'stage': 'active',
        },
        <String, dynamic>{'kind': 'habit_trial', 'stage': 'proposed'},
        <String, dynamic>{
          'kind': 'other',
          'trial_id': 't-1',
          'stage': 'proposed',
        },
      ]) {
        expect(
          PushAlert.fromMessage(data: data).habitTrial,
          isNull,
          reason: '$data',
        );
      }
    },
  );

  test('the payload carries the trial and the stage, and nothing else', () {
    final p = habitTrialPayload((id: 't-1', stage: HabitTrialStage.proposed));
    expect(habitTrialFromPayload(p), (
      id: 't-1',
      stage: HabitTrialStage.proposed,
    ));
    expect(destinationForPayload(p), AlertDestination.home);
    expect(habitTrialFromPayload('habit_trial:t-1|active'), isNull);
    expect(habitTrialFromPayload('habit_trial:|proposed'), isNull);
    expect(habitTrialFromPayload('home'), isNull);
  });

  group('a press answers, a tap opens the home', () {
    ({String? answer, AlertDestination? opened}) route(String? action) {
      String? answer;
      AlertDestination? opened;
      routeNotificationResponse(
        actionId: action,
        payload: habitTrialPayload((
          id: 't-1',
          stage: HabitTrialStage.measured,
        )),
        onOpened: (d) => opened = d,
        onHabit: (t, {required yes}) => answer = '${t.id} ${t.stage.name} $yes',
      );
      return (answer: answer, opened: opened);
    }

    test(
      'yes',
      () => expect(route(kHabitYesActionId).answer, 't-1 measured true'),
    );
    test(
      'no',
      () => expect(route(kHabitNoActionId).answer, 't-1 measured false'),
    );
    test('the notification itself', () {
      final r = route(null);
      expect(r.answer, isNull);
      expect(r.opened, AlertDestination.home);
    });
  });

  test(
    'the server reply is read strictly, and every outcome has its own words',
    () {
      expect(
        habitTrialOutcomeFrom(<String, dynamic>{'ok': true, 'answer': 'start'}),
        HabitTrialOutcome.started,
      );
      expect(
        habitTrialOutcomeFrom(<String, dynamic>{'ok': true, 'answer': 'drop'}),
        HabitTrialOutcome.dropped,
      );
      expect(
        habitTrialOutcomeFrom(<String, dynamic>{'ok': true, 'already': true}),
        HabitTrialOutcome.already,
      );
      expect(
        habitTrialOutcomeFrom(<String, dynamic>{
          'ok': false,
          'reason': 'not_found',
        }),
        HabitTrialOutcome.gone,
      );
      expect(habitTrialOutcomeFrom('nonsense'), HabitTrialOutcome.gone);
      final words = HabitTrialOutcome.values
          .map((o) => habitTrialReply(zadL10nArabic, o))
          .toSet();
      expect(words, hasLength(HabitTrialOutcome.values.length));
    },
  );
}
