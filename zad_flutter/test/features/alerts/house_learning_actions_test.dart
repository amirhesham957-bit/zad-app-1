// «صح / مش صح» under a weekly learning on the notification (ZAD_PLAN 5.2):
// the push names the learning, the payload carries it, and a press is routed
// to the answer — a tap on the notification opens the home.

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/alerts/application/alerts_controller.dart';
import 'package:zad/shared/alerts/data/house_learning_answers.dart';
import 'package:zad/shared/alerts/data/push_platform.dart';
import 'package:zad/shared/alerts/domain/push_alert.dart';

void main() {
  test('the push names the learning; anything else is a plain alert', () {
    final alert = PushAlert.fromMessage(
      data: const <String, dynamic>{
        'title': '🧠',
        'body': 'البقالة يوم الأربع',
        'kind': 'house_learning',
        'learning_id': 'l-1',
        'route': 'home',
      },
    );
    expect(alert.houseLearningId, 'l-1');
    expect(alert.habitTrial, isNull);
    expect(alert.destination, AlertDestination.home);
    for (final data in <Map<String, dynamic>>[
      <String, dynamic>{'kind': 'house_learning', 'learning_id': '  '},
      <String, dynamic>{'kind': 'house_learning'},
      <String, dynamic>{'kind': 'habit_trial', 'learning_id': 'l-1'},
    ]) {
      expect(
        PushAlert.fromMessage(data: data).houseLearningId,
        isNull,
        reason: '$data',
      );
    }
  });

  test('the payload carries the learning, and nothing else', () {
    final p = houseLearningPayload('l-1');
    expect(houseLearningFromPayload(p), 'l-1');
    expect(destinationForPayload(p), AlertDestination.home);
    expect(houseLearningFromPayload('house_learning:'), isNull);
    expect(houseLearningFromPayload('habit_trial:t-1|proposed'), isNull);
    expect(houseLearningFromPayload('home'), isNull);
  });

  group('a press answers, a tap opens the home', () {
    ({String? answer, AlertDestination? opened}) route(String? action) {
      String? answer;
      AlertDestination? opened;
      routeNotificationResponse(
        actionId: action,
        payload: houseLearningPayload('l-1'),
        onOpened: (d) => opened = d,
        onHabit: (t, {required yes}) => answer = 'habit',
        onLearning: (id, {required yes}) => answer = '$id $yes',
      );
      return (answer: answer, opened: opened);
    }

    test('صح', () => expect(route(kLearningYesActionId).answer, 'l-1 true'));
    test('مش صح', () => expect(route(kLearningNoActionId).answer, 'l-1 false'));
    test('a trial button on a learning answers nothing', () {
      final r = route(kHabitYesActionId);
      expect(r.answer, isNull);
      expect(r.opened, AlertDestination.home);
    });
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
        houseLearningOutcomeFrom(<String, dynamic>{
          'ok': true,
          'answer': 'yes',
        }),
        HouseLearningOutcome.right,
      );
      expect(
        houseLearningOutcomeFrom(<String, dynamic>{'ok': true, 'answer': 'no'}),
        HouseLearningOutcome.wrong,
      );
      expect(
        houseLearningOutcomeFrom(<String, dynamic>{
          'ok': true,
          'already': true,
          'answer': 'yes',
        }),
        HouseLearningOutcome.already,
      );
      expect(
        houseLearningOutcomeFrom(<String, dynamic>{
          'ok': false,
          'reason': 'not_signed_in',
        }),
        HouseLearningOutcome.gone,
      );
      expect(houseLearningOutcomeFrom('nonsense'), HouseLearningOutcome.gone);
      final words = HouseLearningOutcome.values
          .map((o) => houseLearningReply(zadL10nArabic, o))
          .toSet();
      expect(words, hasLength(HouseLearningOutcome.values.length));
    },
  );
}
