// «شارك لزاد» (ZAD_PLAN ٣.٣): every share goes to one place — text to the
// chat as a draft, a PDF or CSV to the statement import, a picture to a
// question — and the channel hands over the share that opened the app as well
// as the ones that arrive while it runs.

import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/app/share/share_intake.dart';
import 'package:zad/app/share/share_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('routeFor', () {
    test('text is a chat draft', () {
      expect(
        routeFor(const SharedItem(text: 'تم خصم 250 جنيه')),
        ShareRoute.chat,
      );
    });

    test('statements by name, or by type when the name says nothing', () {
      expect(
        routeFor(const SharedItem(path: '/c/k.pdf', name: 'kashf.pdf')),
        ShareRoute.statement,
      );
      expect(
        routeFor(
          const SharedItem(
            path: '/c/document',
            name: 'document',
            mimeType: 'application/pdf',
          ),
        ),
        ShareRoute.statement,
      );
      expect(
        routeFor(
          const SharedItem(
            path: '/c/e',
            name: 'export',
            mimeType: 'text/comma-separated-values',
          ),
        ),
        ShareRoute.statement,
      );
    });

    test('a picture asks what it is', () {
      expect(
        routeFor(
          const SharedItem(
            path: '/c/x',
            name: 'Screenshot',
            mimeType: 'image/png',
          ),
        ),
        ShareRoute.askImage,
      );
      expect(
        routeFor(const SharedItem(path: '/c/a.jpg', name: 'a.jpg')),
        ShareRoute.askImage,
      );
    });

    test('anything else is turned away, and failures say so', () {
      expect(
        routeFor(
          const SharedItem(
            path: '/c/a.docx',
            name: 'a.docx',
            mimeType: 'application/msword',
          ),
        ),
        ShareRoute.unsupported,
      );
      expect(routeFor(const SharedItem()), ShareRoute.unsupported);
      expect(
        routeFor(const SharedItem(tooLarge: true, name: 'big.pdf')),
        ShareRoute.tooLarge,
      );
      expect(routeFor(const SharedItem(failed: true)), ShareRoute.failed);
    });
  });

  test('a file name gets the extension its type implies', () {
    expect(
      shareFileName(
        const SharedItem(name: 'document', mimeType: 'application/pdf'),
      ),
      'document.pdf',
    );
    expect(
      shareFileName(const SharedItem(name: 'shot', mimeType: 'image/heic')),
      'shot.jpg',
    );
    expect(shareFileName(const SharedItem(name: 'a.csv')), 'a.csv');
  });

  test('fromMap reads the channel and ignores blanks', () {
    final item = SharedItem.fromMap(<String, Object?>{
      'path': '/c/k.pdf',
      'name': 'k.pdf',
      'mime': 'application/pdf',
      'text': '  ',
    })!;
    expect(item.path, '/c/k.pdf');
    expect(item.mimeType, 'application/pdf');
    expect(item.text, isNull);
    expect(SharedItem.fromMap(null), isNull);
    expect(SharedItem.fromMap('x'), isNull);
  });

  test(
    'the opening share is taken once, and a later one on "shared"',
    () async {
      const channel = MethodChannel('zad/share.test');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final queue = <Object?>[
        <String, Object?>{'text': 'أول مشاركة'},
      ];
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'take');
        return queue.isEmpty ? null : queue.removeAt(0);
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      final got = <String?>[];
      final intake = ShareIntake(channel);
      await intake.listen((item) => got.add(item.text));
      expect(got, <String?>['أول مشاركة']);

      // MainActivity.onNewIntent: a share while the app runs.
      queue.add(<String, Object?>{'text': 'تانية'});
      await messenger.handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(const MethodCall('shared')),
        (_) {},
      );
      expect(got, <String?>['أول مشاركة', 'تانية']);
      intake.close();
    },
  );

  test('no platform channel: nothing shared, nothing thrown', () async {
    final got = <SharedItem>[];
    await ShareIntake(const MethodChannel('zad/share.absent')).listen(got.add);
    expect(got, isEmpty);
  });

  testWidgets('a shared receipt picture is sent at the camera path size', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawRect(
        const ui.Rect.fromLTWH(0, 0, 2048, 1000),
        ui.Paint()..color = const ui.Color(0xFF336699),
      );
      final big = await recorder.endRecording().toImage(2048, 1000);
      final png = (await big.toByteData(format: ui.ImageByteFormat.png))!.buffer
          .asUint8List();
      big.dispose();

      final small = await shrinkForReceipt(png);
      final codec = await ui.instantiateImageCodec(small);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 1024);
      expect(frame.image.height, 500);
      frame.image.dispose();
      codec.dispose();
    });
  });

  test('a file that is not a picture fails the shrink', () async {
    await expectLater(
      shrinkForReceipt(Uint8List.fromList(<int>[1, 2, 3])),
      throwsA(anything),
    );
  });
}
