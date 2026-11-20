// The documents world: the nearest expiry in the state line, every document
// a row that edits on tap and deletes from its button, and an empty drawer
// with the docked add still reachable.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/documents/presentation/documents_screen.dart';
import 'package:zad/shared/documents/domain/important_document.dart';

import '../../support/fonts.dart';
import '../../support/quiet_household.dart';

final DateTime _today = DateTime(2026, 11, 20);

final List<ImportantDocument> _docs = <ImportantDocument>[
  ImportantDocument(
    id: '1',
    kind: DocumentKind.passport,
    expiresOn: DateTime.utc(2027, 1, 4),
    holder: 'يوسف',
  ),
  ImportantDocument(
    id: '2',
    kind: DocumentKind.nationalId,
    expiresOn: DateTime.utc(2028, 5),
  ),
  ImportantDocument(
    id: '3',
    kind: DocumentKind.drivingLicense,
    expiresOn: DateTime.utc(2026, 12),
  ),
  ImportantDocument(
    id: '4',
    kind: DocumentKind.other,
    label: 'كارنيه النادي',
    expiresOn: DateTime.utc(2027, 3, 15),
  ),
];

Widget _app(
  List<ImportantDocument> docs, {
  VoidCallback? onAdd,
  void Function(ImportantDocument)? onEdit,
  void Function(ImportantDocument)? onDelete,
}) => ProviderScope(
  overrides: quietOrbOverrides,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ZadTheme.light(),
    locale: const Locale('ar'),
    supportedLocales: ZadL10n.supportedLocales,
    localizationsDelegates: ZadL10n.localizationsDelegates,
    home: Scaffold(
      body: DocumentsWorld(
        docs: docs,
        loading: false,
        today: _today,
        onRefresh: () async {},
        onAdd: onAdd ?? () {},
        onEdit: onEdit ?? (_) {},
        onDelete: onDelete ?? (_) {},
      ),
    ),
  ),
);

Future<void> _open(WidgetTester tester, Widget app, {double h = 2400}) async {
  tester.view
    ..physicalSize = Size(860, h)
    ..devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  await tester.pumpWidget(app);
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('the state line names the nearest expiry, rows act', (
    tester,
  ) async {
    ImportantDocument? edited;
    ImportantDocument? deleted;
    var added = 0;
    await _open(
      tester,
      _app(
        _docs,
        onAdd: () => added++,
        onEdit: (d) => edited = d,
        onDelete: (d) => deleted = d,
      ),
    );
    expect(find.text('المستندات'), findsOneWidget);
    expect(find.text('الأقرب: رخصة القيادة — خلال 11 يوم'), findsOneWidget);
    expect(find.text('4 مستندات'), findsOneWidget);
    final first = tester.getTopLeft(find.text('رخصة القيادة'));
    final last = tester.getTopLeft(find.text('البطاقة الشخصية'));
    expect(first.dy, lessThan(last.dy));
    await tester.tap(find.text('رخصة القيادة'));
    expect(edited?.id, '3');
    await tester.tap(find.byTooltip('حذف').first);
    expect(deleted?.id, '3');
    await tester.tap(find.byTooltip('إضافة مستند'));
    expect(added, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an empty drawer has a real empty state and the add button', (
    tester,
  ) async {
    var added = 0;
    await _open(
      tester,
      _app(const <ImportantDocument>[], onAdd: () => added++),
    );
    expect(find.text('الدرج فاضي — ضيف أول مستند'), findsOneWidget);
    expect(find.text('مفيش مستندات متسجلة'), findsOneWidget);
    await tester.tap(find.byTooltip('إضافة مستند'));
    expect(added, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('screenshot: the documents world', (tester) async {
    await loadZadFonts();
    await _open(tester, _app(_docs), h: 1864);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../../build/screens/world_docs.png'),
    );
    await tester.pumpWidget(const SizedBox());
  }, skip: Platform.environment['ZAD_SCREENS'] != '1');
}
