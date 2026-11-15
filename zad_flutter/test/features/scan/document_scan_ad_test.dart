// One ad with every document reading (owner, 15/11): while the AI reads the
// prescription or timetable there is one inline ad under «بقرا الورقة»; before
// the photo and on a failure there is none.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/features/scan/application/document_scan_controller.dart';
import 'package:zad/features/scan/application/scan_controller.dart';
import 'package:zad/features/scan/presentation/document_scan_sheet.dart';
import 'package:zad/shared/ads/application/ads_policy.dart';
import 'package:zad/shared/ads/presentation/inline_ad.dart';
import 'package:zad/shared/scan/domain/scanned_document.dart';

class _Doc extends DocumentScanController {
  new(this.initial);

  final DocumentScanView initial;

  @override
  DocumentScanView build() => initial;
}

void main() {
  Future<void> open(WidgetTester tester, ScanStage stage) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          documentScanControllerProvider.overrideWith(
            () => _Doc(DocumentScanView(stage: stage)),
          ),
          adsAllowedProvider.overrideWithValue(false),
        ],
        child: MaterialApp(
          theme: ZadTheme.light(),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: DocumentScanSheet(kind: DocumentKind.prescription),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('the reading wait carries one inline ad', (tester) async {
    await open(tester, ScanStage.working);
    expect(find.text('بقرا الورقة…'), findsOneWidget);
    expect(find.byType(ZadInlineAd), findsOneWidget);
  });

  testWidgets('before the photo and after a failure there is no ad', (
    tester,
  ) async {
    await open(tester, ScanStage.idle);
    expect(find.byType(ZadInlineAd), findsNothing);
    await open(tester, ScanStage.failed);
    expect(find.byType(ZadInlineAd), findsNothing);
  });
}
