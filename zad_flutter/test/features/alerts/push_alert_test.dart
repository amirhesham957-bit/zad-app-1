// How an arriving push is read: where its words come from, where a tap goes,
// and when the app has to show it itself.

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/features/alerts/domain/push_alert.dart';

void main() {
  test('the notification block wins; data is the fallback', () {
    final both = PushAlert.fromMessage(
      data: const <String, dynamic>{'title': 'data t', 'body': 'data b'},
      notificationTitle: 'زاد محتاج رأيك',
      notificationBody: 'في معاملة مستنية',
    );
    expect(both.title, 'زاد محتاج رأيك');
    expect(both.body, 'في معاملة مستنية');

    final dataOnly = PushAlert.fromMessage(
      data: const <String, dynamic>{'title': ' لحظة ', 'body': 'اشرب مية'},
    );
    expect(dataOnly.title, 'لحظة');
    expect(dataOnly.isShowable, isTrue);
    expect(PushAlert.fromMessage(data: const {}).isShowable, isFalse);
  });

  test('routes the server sends, and ones this build does not know', () {
    expect(
      PushAlert.fromMessage(
        data: const <String, dynamic>{'route': 'transaction_proposals'},
      ).destination,
      AlertDestination.proposals,
    );
    // A newer server's route must not crash an older phone.
    expect(destinationFor('some_future_screen'), isNull);
    expect(destinationFor(null), isNull);
    expect(
      destinationFor(payloadFor(AlertDestination.proposals)),
      AlertDestination.proposals,
    );
  });

  test('in front the app shows everything; behind, only data-only', () {
    expect(
      shouldShowLocally(hasNotificationBlock: true, inForeground: true),
      isTrue,
    );
    expect(
      shouldShowLocally(hasNotificationBlock: false, inForeground: true),
      isTrue,
    );
    // FCM already showed it; showing it again would be a double alert.
    expect(
      shouldShowLocally(hasNotificationBlock: true, inForeground: false),
      isFalse,
    );
    expect(
      shouldShowLocally(hasNotificationBlock: false, inForeground: false),
      isTrue,
    );
  });
}
