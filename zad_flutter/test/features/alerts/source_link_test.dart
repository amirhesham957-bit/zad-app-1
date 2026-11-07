// An offer alert carries the offer's own post or video (ZAD_PLAN ٤.٢٢): a tap
// on the notification opens it, its button too, and the other buttons still
// answer what they ask.
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/shared/alerts/data/push_platform.dart';
import 'package:zad/shared/alerts/domain/push_alert.dart';

void main() {
  const video = 'https://www.youtube.com/watch?v=abc123';

  test('the push reads the link, https only', () {
    expect(
      PushAlert.fromMessage(data: const {'source_url': video}).sourceUrl,
      video,
    );
    for (final bad in const [
      'http://x.com/a',
      'javascript:alert(1)',
      'https://a b',
      '',
    ]) {
      expect(
        PushAlert.fromMessage(data: {'source_url': bad}).sourceUrl,
        isNull,
      );
    }
    expect(PushAlert.fromMessage(data: const {}).sourceUrl, isNull);
  });

  test('the payload carries the link in front and gives the rest back', () {
    final p = withSourceLink(speakPayload('صباح الخير'), video);
    expect(sourceUrlFromPayload(p), video);
    expect(withoutSourceLink(p), speakPayload('صباح الخير'));
    expect(withSourceLink('home', null), 'home');
    expect(withSourceLink('home', 'http://x.com'), 'home');
    expect(withoutSourceLink(withSourceLink(null, video)), isNull);
  });

  group('a tap opens the offer, a button still answers', () {
    ({String? link, String? spoke, AlertDestination? opened}) route(
      String? action,
    ) {
      String? link;
      String? spoke;
      AlertDestination? opened;
      routeNotificationResponse(
        actionId: action,
        payload: withSourceLink(speakPayload('فيه عرض على الزيت'), video),
        onOpened: (d) => opened = d,
        onSpeak: (s) => spoke = s,
        onLink: (u) => link = u,
      );
      return (link: link, spoke: spoke, opened: opened);
    }

    test('the notification itself', () {
      final r = route(null);
      expect(r.link, video);
      expect(r.opened, isNull);
    });
    test('«افتح العرض»', () => expect(route(kOpenSourceActionId).link, video));
    test('«اسمع زاد» speaks, and opens no link', () {
      final r = route(kListenActionId);
      expect(r.link, isNull);
      expect(r.spoke, 'فيه عرض على الزيت');
      expect(r.opened, AlertDestination.home);
    });
  });

  test('a payload with no link routes as before', () {
    AlertDestination? opened;
    routeNotificationResponse(
      actionId: null,
      payload: 'pharmacy',
      onOpened: (d) => opened = d,
      onLink: (_) => fail('no link to open'),
    );
    expect(opened, AlertDestination.pharmacy);
  });
}
