// Telegram's «افتح زاد» buttons: only the listed places open, and the channel
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

  test('only the listed places are targets', () {
    expect(appLinkTargetFrom('pet'), AppLinkTarget.pet);
    expect(appLinkTargetFrom('deals'), AppLinkTarget.deals);
    expect(appLinkTargetFrom('profile'), isNull);
    expect(appLinkTargetFrom(''), isNull);
    expect(appLinkTargetFrom(null), isNull);
    expect(appLinkTargetFrom(7), isNull);
  });

  test('takes the link that opened the app, then each one after', () async {
    final waiting = <String?>['pet', 'deals'];
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => waiting.removeAt(0),
    );
    final opened = <AppLinkTarget>[];
    final intake = AppLinkIntake();
    await intake.listen(opened.add);
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
    messenger.setMockMethodCallHandler(channel, (call) async => 'wallet');
    final opened = <AppLinkTarget>[];
    final intake = AppLinkIntake();
    await intake.listen(opened.add);
    expect(opened, isEmpty);
    intake.close();
  });

  test('no channel: no link and no throw', () async {
    final opened = <AppLinkTarget>[];
    await AppLinkIntake().listen(opened.add);
    expect(opened, isEmpty);
  });
}
