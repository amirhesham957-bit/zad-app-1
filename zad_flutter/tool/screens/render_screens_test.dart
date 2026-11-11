// Renders the app's screens to PNG on a full account — the screens the owner
// and Claude discuss page by page (ZAD_PLAN 10.8). It exists because the
// Android emulator crashes on this codespace's CPU the moment Zad draws
// (2026-11-11, every GPU mode). Not part of `flutter test`'s default run:
//
//   flutter test tool/screens/render_screens_test.dart
//
// Pictures land in build/screens/ (gitignored), one per screenful.

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:zad/app/zad_shell.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/shared/inventory/application/pantry_controller.dart';
import 'package:zad/shared/inventory/domain/inventory_item.dart';
import 'package:zad/shared/pharmacy/application/pharmacy_controller.dart';
import 'package:zad/shared/pharmacy/domain/medicine.dart';

import '../../test/support/fonts.dart';
import '../../test/support/quiet_household.dart';
import '../../test/support/shell_harness.dart';

void main() {
  final harness = ShellHarness();
  final out = Directory('build/screens')..createSync(recursive: true);

  setUpAll(() async {
    tz_data.initializeTimeZones();
    await initializeDateFormatting('ar');
    await loadZadFonts();
  });
  setUp(harness.open);

  testWidgets('renders every tab, screenful by screenful', (tester) async {
    await _seedTransactions(harness);
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('zad/app'),
      (_) async => true,
    );
    // The chat's voice button builds a recorder; no plugin runs here.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.llfbandit.record/messages'),
      (_) async => null,
    );
    final container = harness.container('user-1', household: _fullHousehold());
    addTearDown(container.dispose);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ZadTheme.light(),
            locale: const Locale('ar'),
            home: const Directionality(
              textDirection: TextDirection.rtl,
              child: ZadShell(),
            ),
          ),
        ),
      ),
    );

    Future<void> frames([int n = 10]) async {
      for (var i = 0; i < n; i++) {
        await tester.pump(const Duration(milliseconds: 150));
        tester.takeException();
      }
    }

    Future<void> shot(String name) async {
      await frames();
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${out.path}/$name.png')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }

    Future<void> screenfuls(String name, [int pages = 4]) async {
      for (var p = 0; p < pages; p++) {
        await shot('${name}_$p');
        final scrollables = find.byType(Scrollable).hitTestable();
        if (scrollables.evaluate().isEmpty) return;
        await tester.drag(scrollables.first, const Offset(0, -700));
      }
    }

    await frames(20);
    await screenfuls('home', 6);
    for (final tab in <String>['فلوسي', 'بيتي']) {
      final target = find.text(tab).hitTestable();
      if (target.evaluate().isEmpty) continue;
      await tester.tap(target.first, warnIfMissed: false);
      await screenfuls(tab == 'فلوسي' ? 'money' : 'home_stock');
    }
  });
}

/// A month of the owner's kind of spending: groceries, cafés, transport,
/// a bill, an income — enough for every list and chart to have rows.
Future<void> _seedTransactions(ShellHarness h) async {
  const titles = <(String, String, double, bool)>[
    ('كارفور', 'بقالة', 640, true),
    ('قهوة', 'مطاعم', 55, true),
    ('أوبر', 'مواصلات', 120, true),
    ('فاتورة الكهرباء', 'فواتير', 480, true),
    ('صيدلية العزبي', 'صحة', 210, true),
    ('مرتب', 'دخل', 12000, false),
    ('طلبات', 'مطاعم', 230, true),
    ('بنزين', 'مواصلات', 400, true),
  ];
  for (var i = 0; i < 24; i++) {
    final (title, category, amount, expense) = titles[i % titles.length];
    final at = h.now.subtract(Duration(days: i, hours: i % 5));
    await h.transactions.put(
      'seed-$i',
      jsonEncode(<String, dynamic>{
        'id': 'seed-$i',
        'user_id': 'user-1',
        'amount': amount + i,
        'title': title,
        'category': category,
        'created_at': at.toIso8601String(),
        'wallet': i.isEven ? 'card' : 'cash',
        'txn_kind': expense ? 'expense' : 'income',
        'is_expense': expense,
        'merchant_name': title,
      }),
    );
  }
}

/// A pantry with things running low and a medicine cabinet for the family.
List<Override> _fullHousehold() {
  final items = <InventoryItem>[
    for (final (i, (name, qty)) in <(String, int)>[
      ('لبن', 0),
      ('كرتونة ماية', 1),
      ('رز', 4),
      ('سكر', 2),
      ('زيت', 1),
      ('بيض', 12),
      ('عيش', 0),
      ('جبنة', 3),
    ].indexed)
      InventoryItem.fromJson(<String, dynamic>{
        'id': 'inv-$i',
        'user_id': 'user-1',
        'item_name': name,
        'quantity': qty,
        'unit': 'قطعة',
        'category': 'بقالة',
        'low_stock_threshold': 2,
        'created_at': '2026-09-01T10:00:00Z',
      }),
  ];
  final medicines = <Medicine>[
    for (final (i, (name, who)) in <(String, String?)>[
      ('كونكور', 'ماما'),
      ('جلوكوفاج', 'بابا'),
      ('بانادول', null),
    ].indexed)
      Medicine.fromJson(<String, dynamic>{
        'id': 'med-$i',
        'user_id': 'user-1',
        'name': name,
        'dose_times': '08:00,20:00',
        'daily_dose_count': 2,
        'remaining_quantity': 6 + i * 10,
        'for_person': who,
      }),
  ];
  return <Override>[
    pantryControllerProvider.overrideWith(
      () => QuietPantry(PantryView(items: items)),
    ),
    pharmacyControllerProvider.overrideWith(
      () => QuietPharmacy(PharmacyView(medicines: medicines)),
    ),
    // The rest of the quiet household: shopping, modes, family, server,
    // reminders.
    ...quietHouseholdOverrides.skip(2),
  ];
}
