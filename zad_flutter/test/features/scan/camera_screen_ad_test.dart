// One ad with every photo scan (owner, 15/11): while the AI reads the
// photograph on the camera screen there is one inline ad under the status;
// before the photo and once the reading is back there is none.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/features/scan/presentation/camera_screen.dart';
import 'package:zad/shared/ads/application/ads_policy.dart';
import 'package:zad/shared/ads/presentation/ai_wait_ad.dart';
import 'package:zad/shared/navigation/destinations.dart';
import 'package:zad/shared/scan/data/receipt_scanner.dart';
import 'package:zad/shared/scan/data/vision_scanner.dart';

/// A real 1x1 picture: the screen shows the photo it took.
final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
  '60e6kgAAAABJRU5ErkJggg==',
);

class _Camera implements ReceiptCamera {
  @override
  Future<Uint8List?> capture(ReceiptImageSource source) async => _png;
}

class _Slow implements VisionScanner {
  final gate = Completer<void>();

  @override
  Future<List<ScannedPantryItem>> pantry({
    required String userId,
    required Uint8List image,
  }) async {
    await gate.future;
    return const <ScannedPantryItem>[];
  }

  @override
  Future<ScannedMedicine?> medicine({
    required String userId,
    required Uint8List image,
  }) async {
    await gate.future;
    return null;
  }
}

void main() {
  const permissions = MethodChannel('flutter.baseflow.com/permissions/methods');

  setUp(() {
    // The camera permission is granted: 1 is the permission, 1 is «granted».
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissions, (call) async {
          if (call.method == 'requestPermissions') {
            return <int, int>{1: 1};
          }
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissions, null);
  });

  Future<_Slow> open(WidgetTester tester, CameraMode mode) async {
    final scanner = _Slow();
    await tester.binding.setSurfaceSize(const Size(420, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          signedInUserIdProvider.overrideWithValue(() => 'u'),
          receiptCameraProvider.overrideWithValue(_Camera()),
          visionScannerProvider.overrideWithValue(scanner),
          adsAllowedProvider.overrideWithValue(false),
        ],
        child: MaterialApp(
          theme: ZadTheme.light(),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: CameraScreen(initialMode: mode)),
          ),
        ),
      ),
    );
    await tester.pump();
    return scanner;
  }

  testWidgets('a pantry photo being read carries one ad, none after', (
    tester,
  ) async {
    final scanner = await open(tester, CameraMode.inventory);
    expect(find.byType(ZadAiWaitAd), findsNothing);

    await tester.tap(find.text('   مسح المخزون'));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('جاري تحليل الصورة'), findsOneWidget);
    expect(find.byType(ZadAiWaitAd), findsOneWidget);

    scanner.gate.complete();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('لم يتعرف AI'), findsOneWidget);
    expect(find.byType(ZadAiWaitAd), findsNothing);
  });

  testWidgets('a medicine photo being read carries one ad', (tester) async {
    final scanner = await open(tester, CameraMode.pharmacy);
    expect(find.byType(ZadAiWaitAd), findsNothing);

    await tester.tap(find.text('   مسح علبة دواء'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(ZadAiWaitAd), findsOneWidget);

    scanner.gate.complete();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(ZadAiWaitAd), findsNothing);
  });
}
