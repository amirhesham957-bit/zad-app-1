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
    // A family chat message or an SOS opens the family chat.
    expect(destinationFor('family'), AlertDestination.family);
    expect(
      destinationFor(payloadFor(AlertDestination.family)),
      AlertDestination.family,
    );
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

  test('a voice moment carries what Zad says; a plain alert says nothing', () {
    final spoken = PushAlert.fromMessage(
      data: const <String, dynamic>{
        'title': 'صباح الخير',
        'body': 'عندك دوا ماما الساعة ٤',
        'voice': '1',
        'speech': ' صباح الخير يا أمير، دوا ماما الساعة أربعة ',
        'moment': 'morning_greeting',
      },
    );
    expect(spoken.speech, 'صباح الخير يا أمير، دوا ماما الساعة أربعة');
    expect(
      PushAlert.fromMessage(
        data: const <String, dynamic>{'title': 'x', 'body': 'y', 'speech': 'z'},
      ).speech,
      isNull,
      reason: 'speech without voice=1 is not a voice moment',
    );
    expect(
      PushAlert.fromMessage(
        data: const <String, dynamic>{
          'title': 'x',
          'voice': '1',
          'speech': '  ',
        },
      ).speech,
      isNull,
    );
  });

  group('shouldAskMorningGreeting', () {
    test('04:00–11:59, once a date', () {
      expect(
        shouldAskMorningGreeting(
          local: DateTime(2026, 9, 29, 3, 59),
          lastAskedDate: null,
        ),
        isFalse,
      );
      expect(
        shouldAskMorningGreeting(
          local: DateTime(2026, 9, 29, 4),
          lastAskedDate: null,
        ),
        isTrue,
      );
      expect(
        shouldAskMorningGreeting(
          local: DateTime(2026, 9, 29, 9),
          lastAskedDate: '2026-09-29',
        ),
        isFalse,
      );
      expect(
        shouldAskMorningGreeting(
          local: DateTime(2026, 9, 30, 9),
          lastAskedDate: '2026-09-29',
        ),
        isTrue,
      );
      expect(
        shouldAskMorningGreeting(
          local: DateTime(2026, 9, 30, 12),
          lastAskedDate: null,
        ),
        isFalse,
      );
    });
  });
}
