// Links from outside the app: only the listed places open, and the channel
// hands over the link that opened the app as well as the ones after it.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/app/link/app_link.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('zad/link');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  Map<String, String?> to(String place, [String? code]) => <String, String?>{
    'to': place,
    'code': code,
  };

  test('only the listed places are targets', () {
    expect(appLinkFrom(to('pet'))?.target, AppLinkTarget.pet);
    expect(appLinkFrom(to('deals'))?.target, AppLinkTarget.deals);
    expect(appLinkFrom(to('rewards'))?.target, AppLinkTarget.rewards);
    expect(appLinkFrom(to('profile')), isNull);
    expect(appLinkFrom(null), isNull);
    expect(appLinkFrom('pet'), isNull);
  });

  test('an invite needs a code that looks like one', () {
    final invite = appLinkFrom(to('invite', 'ZAD-AB12'));
    expect(invite?.target, AppLinkTarget.invite);
    expect(invite?.code, 'ZAD-AB12');
    expect(appLinkFrom(to('invite')), isNull);
    expect(appLinkFrom(to('invite', 'a b;c')), isNull);
  });

  test('takes the link that opened the app, then each one after', () async {
    final waiting = <Map<String, String?>>[to('pet'), to('deals')];
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => waiting.removeAt(0),
    );
    final opened = <AppLinkTarget>[];
    final intake = AppLinkIntake();
    await intake.listen((link) => opened.add(link.target));
    expect(opened, [AppLinkTarget.pet]);

    await messenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(const MethodCall('link')),
      (_) {},
    );
    expect(opened, [AppLinkTarget.pet, AppLinkTarget.deals]);
    intake.close();
  });

  test('an unknown place opens nothing', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => to('wallet'));
    final opened = <AppLink>[];
    final intake = AppLinkIntake();
    await intake.listen(opened.add);
    expect(opened, isEmpty);
    intake.close();
  });

  test('no channel: no link and no throw', () async {
    final opened = <AppLink>[];
    await AppLinkIntake().listen(opened.add);
    expect(opened, isEmpty);
  });
}
