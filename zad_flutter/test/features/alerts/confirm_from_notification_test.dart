// A bank question on the phone carries «أيوه، أنا» / «مش أنا». Reading the push,
// the payload round trip, and where each kind of tap goes.

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/shared/alerts/data/push_platform.dart';
import 'package:zad/shared/alerts/domain/push_alert.dart';

void main() {
  test('a confirm_transaction push carries its proposal; others do not', () {
    final ask = PushAlert.fromMessage(
      data: const <String, dynamic>{
        'title': 'اتخصم 250 جنيه — إنت؟',
        'body': 'كارفور',
        'route': 'transaction_proposals',
        'kind': kConfirmTransactionKind,
        'proposal_id': 'p-9',
      },
    );
    expect(ask.proposalId, 'p-9');
    expect(ask.destination, AlertDestination.proposals);

    // The same route without the kind is the old generic reminder: no buttons.
    expect(
      PushAlert.fromMessage(
        data: const <String, dynamic>{
          'route': 'transaction_proposals',
          'proposal_id': 'p-9',
        },
      ).proposalId,
      isNull,
    );
    expect(
      PushAlert.fromMessage(
        data: const <String, dynamic>{
          'kind': kConfirmTransactionKind,
          'proposal_id': '  ',
        },
      ).proposalId,
      isNull,
    );
  });

  test('the payload round-trips and still routes a plain tap', () {
    final payload = proposalPayload('p-9');
    expect(proposalIdFromPayload(payload), 'p-9');
    expect(destinationForPayload(payload), AlertDestination.proposals);
    // The older payloads keep their meaning.
    expect(proposalIdFromPayload('pharmacy'), isNull);
    expect(destinationForPayload('pharmacy'), AlertDestination.pharmacy);
    expect(destinationForPayload(null), isNull);
  });

  group('routeNotificationResponse', () {
    late List<(String, bool)> answers;
    late List<AlertDestination?> opened;

    void route(String? actionId, String? payload) => routeNotificationResponse(
      actionId: actionId,
      payload: payload,
      onOpened: opened.add,
      onAnswer: (id, {required confirmed}) => answers.add((id, confirmed)),
    );

    setUp(() {
      answers = <(String, bool)>[];
      opened = <AlertDestination?>[];
    });

    test('the two buttons answer, and open nothing by themselves', () {
      route(kConfirmActionId, proposalPayload('p-1'));
      route(kRejectActionId, proposalPayload('p-2'));
      expect(answers, <(String, bool)>[('p-1', true), ('p-2', false)]);
      expect(opened, isEmpty);
    });

    test('a tap on the notification itself opens the confirmations tab', () {
      route(null, proposalPayload('p-1'));
      expect(answers, isEmpty);
      expect(opened, <AlertDestination?>[AlertDestination.proposals]);
    });

    test('a button with no proposal behind it only opens', () {
      route(kConfirmActionId, 'transaction_proposals');
      expect(answers, isEmpty);
      expect(opened, <AlertDestination?>[AlertDestination.proposals]);
    });
  });
}
