import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/shared/affiliate/data/amazon_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('zad/amazon_app');
  late List<MethodCall> calls;
  late bool installed;

  setUp(() {
    calls = <MethodCall>[];
    installed = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return installed;
        });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  const eg = 'https://www.amazon.eg/dp/B0ABCDEF12?tag=zad04-21';

  test('Android: the tagged link goes to the Amazon app', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(await openInAmazonApp(eg), isTrue);
    expect(calls.single.method, 'open');
    expect(calls.single.arguments, <String, String>{'url': eg});
  });

  test('the app is not installed: false, so the browser tab opens', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    installed = false;
    expect(await openInAmazonApp(eg), isFalse);
  });

  test(
    'not an Amazon store link, or not Android: the channel is not asked',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(await openInAmazonApp('https://evil.example/amazon.eg'), isFalse);
      expect(
        await openInAmazonApp('https://www.amazon.eg.evil.example/'),
        isFalse,
      );
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(await openInAmazonApp(eg), isFalse);
      expect(calls, isEmpty);
    },
  );
}
