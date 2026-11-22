// The maintenance world: the next due task in the state line, every task a
// row with its bar, mark-done and delete, the trusted technicians one tap
// away, and an empty state with the docked add still reachable.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/maintenance/presentation/maintenance_screen.dart';

import '../../support/fonts.dart';
import '../../support/quiet_household.dart';

final DateTime _today = DateTime(2026, 11, 20);

final List<Map<String, dynamic>> _rows = <Map<String, dynamic>>[
  <String, dynamic>{
    'id': 'a',
    'name': 'فلتر المية',
    'category': 'فلتر مياه',
    'last_service_date': '2026-08-16',
    'service_interval_days': 90,
  },
  <String, dynamic>{
    'id': 'b',
    'name': 'صيانة التكييف',
    'category': 'تكييف',
    'last_service_date': '2026-10-10',
    'service_interval_days': 90,
    'warranty_expiry_date': '2026-12-05',
  },
  <String, dynamic>{
    'id': 'c',
    'name': 'زيت العربية',
    'category': 'سيارة',
    'last_service_date': '2026-11-01',
    'service_interval_days': 180,
  },
];

Widget _app(
  List<Map<String, dynamic>> rows, {
  VoidCallback? onAdd,
  VoidCallback? onTechnicians,
  void Function(String)? onServiced,
  void Function(String)? onDelete,
}) => ProviderScope(
  overrides: quietOrbOverrides,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ZadTheme.light(),
    locale: const Locale('ar'),
    supportedLocales: ZadL10n.supportedLocales,
    localizationsDelegates: ZadL10n.localizationsDelegates,
    home: Scaffold(
      body: MaintenanceWorld(
        rows: rows,
        loading: false,
        today: _today,
        onRefresh: () async {},
        onAdd: onAdd ?? () {},
        onTechnicians: onTechnicians ?? () {},
        onServiced: onServiced ?? (_) {},
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
  testWidgets('the overdue task leads the state line; rows act', (
    tester,
  ) async {
    String? serviced;
    String? deleted;
    var techs = 0;
    var added = 0;
    await _open(
      tester,
      _app(
        _rows,
        onAdd: () => added++,
        onTechnicians: () => techs++,
        onServiced: (id) => serviced = id,
        onDelete: (id) => deleted = id,
      ),
    );
    expect(find.text('الصيانة'), findsOneWidget);
    expect(find.text('فلتر المية متأخر 6 يوم'), findsOneWidget);
    expect(find.text('3 أجهزة'), findsOneWidget);
    expect(find.text('1 جهاز متأخر عن موعد الصيانة'), findsOneWidget);
    await tester.tap(find.text('تمت الصيانة اليوم').first);
    expect(serviced, 'a');
    await tester.tap(find.byTooltip('حذف').first);
    expect(deleted, 'a');
    await tester.tap(find.text('فنيين بثق فيهم'));
    expect(techs, 1);
    await tester.tap(find.byTooltip('إضافة جهاز'));
    expect(added, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an empty list has a real empty state and the add button', (
    tester,
  ) async {
    var added = 0;
    await _open(
      tester,
      _app(const <Map<String, dynamic>>[], onAdd: () => added++),
    );
    expect(find.text('مفيش جهاز متسجل لسه'), findsOneWidget);
    expect(find.text('لا توجد أجهزة مسجلة بعد'), findsOneWidget);
    await tester.tap(find.byTooltip('إضافة جهاز'));
    expect(added, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('screenshot: the maintenance world', (tester) async {
    await loadZadFonts();
    await _open(tester, _app(_rows), h: 1864);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../../build/screens/world_maint.png'),
    );
    await tester.pumpWidget(const SizedBox());
  }, skip: Platform.environment['ZAD_SCREENS'] != '1');
}
