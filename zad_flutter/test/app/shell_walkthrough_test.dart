// Every tab, section, sheet and route the shell opens — opened and closed with
// Android's back, in one running app, with the framework's debug checks on.
//
// Written after the owner's phone showed a red screen (2026-09-29):
// `'_elements.contains(element)': is not true` — Flutter's own bookkeeping
// failing after an earlier error left an element half torn down. Screen
// tests open one screen in isolation; this walks them the way a customer
// does, one after another, and reports every error the framework raised,
// not just the first.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:zad/app/shell/zad_bottom_nav_bar.dart';
import 'package:zad/app/zad_shell.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/features/home/presentation/home_screen.dart';
import 'package:zad/features/home/presentation/sections_grid.dart';
import 'package:zad/features/inventory/application/pantry_controller.dart';
import 'package:zad/features/inventory/domain/inventory_item.dart';
import 'package:zad/features/pharmacy/application/pharmacy_controller.dart';
import 'package:zad/features/pharmacy/domain/medicine.dart';

import '../support/fonts.dart';
import '../support/quiet_household.dart';
import '../support/shell_harness.dart';

void main() {
  final harness = ShellHarness();

  setUpAll(() async {
    tz_data.initializeTimeZones();
    await initializeDateFormatting('ar');
    // Real glyph widths: the test font's square glyphs overflow rows that fit
    // on a phone.
    await loadZadFonts();
  });
  setUp(harness.open);

  // The owner's phone, then the two that found real overflows on 2026-09-30:
  // a small 320dp phone (the pantry row and the bottom bar ran off it), and
  // a common one with the font size raised to 1.3× (the bar's labels, the
  // knowledge map's legend and title, the pantry's shortage strip).
  const phones = <(String, Size, double)>[
    ('412dp', Size(412, 915), 1),
    ('320dp', Size(320, 568), 1),
    ('360dp at 1.3× text', Size(360, 740), 1.3),
  ];
  for (final (phone, size, textScale) in phones) {
    for (final full in <bool>[false, true]) {
      testWidgets('every section opens and closes without a framework error — '
          '${full ? 'a full account' : 'an empty account'}, $phone', (
        tester,
      ) async {
        if (full) await _seedTransactions(harness);
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        // Back on الرئيسية asks Android to hide the app.
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('zad/app'),
          (_) async => true,
        );

        final errors = <String>[];
        final visited = <String>[];
        var step = 'start';

        final routes = _Depth();
        final container = harness.container(
          'user-1',
          household: full ? _fullHousehold() : null,
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              navigatorObservers: <NavigatorObserver>[routes],
              theme: ZadTheme.light(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!,
              ),
              locale: const Locale('ar'),
              home: const Directionality(
                textDirection: TextDirection.rtl,
                child: ZadShell(),
              ),
            ),
          ),
        );

        Future<void> frames([int n = 6]) async {
          for (var i = 0; i < n; i++) {
            await tester.pump(const Duration(milliseconds: 120));
            final e = tester.takeException();
            if (e != null) {
              final text = '$e';
              final cut = text.length > 1500 ? text.substring(0, 1500) : text;
              errors.add('[$step] $cut');
            }
          }
        }

        await frames();

        /// Taps every visible control on the top screen, one at a time, and
        /// closes whatever each one opened with Android's back.
        Future<void> crawl(String name) async {
          final base = routes.depth;
          final done = <String>{};
          // Four screenfuls: lists put their rows below the fold.
          for (var page = 0; page < 4; page++) {
            for (var i = 0; i < 40; i++) {
              final tappables = find
                  .byWidgetPredicate(_isTappable)
                  .hitTestable();
              final all = tappables.evaluate().toList();
              if (i >= all.length) break;
              final label = _labelOf(all[i]);
              if (_unsafe.any(label.contains) || !done.add(label)) continue;
              step = '$name › page $page tap $i «$label»';
              visited.add(step);
              debugPrint('STEP $step');
              await tester.tap(tappables.at(i), warnIfMissed: false);
              await frames(4);
              for (var guard = 0; routes.depth > base && guard < 4; guard++) {
                step = '$name › back from «$label»';
                debugPrint('STEP $step');
                await tester.binding.handlePopRoute();
                await frames(4);
              }
              if (routes.depth < base) return; // the screen closed itself
            }
            final scrollables = find
                .byWidgetPredicate(
                  (w) =>
                      w is Scrollable && w.axisDirection == AxisDirection.down,
                )
                .hitTestable();
            if (scrollables.evaluate().isEmpty) return;
            step = '$name › scroll to page ${page + 1}';
            debugPrint('STEP $step');
            await tester.drag(
              scrollables.first,
              const Offset(0, -600),
              warnIfMissed: false,
            );
            await frames(4);
          }
        }

        ZadBottomNavBar bar() =>
            tester.widget<ZadBottomNavBar>(find.byType(ZadBottomNavBar));
        for (final tab in <ZadNavDestination>[
          ZadNavDestination.assistant,
          ZadNavDestination.inventory,
          ZadNavDestination.home,
        ]) {
          step = 'tab ${tab.name}';
          bar().onNavigate(tab);
          await frames();
          await crawl('tab ${tab.name}');
          bar().onNavigate(tab);
          await frames(2);
        }

        for (final section in zadSections) {
          step = 'section ${section.id}';
          final context = tester.element(find.byType(HomeScreen));
          unawaited(
            section.open(context).catchError((Object e) {
              errors.add('[$step] open threw: $e');
            }),
          );
          await frames();
          await crawl(section.id);
          // Android's back, as the phone sends it.
          step = 'back from ${section.id}';
          await tester.binding.handlePopRoute();
          await frames();
          // A tab section leaves the shell on another tab; go home for the
          // next.
          bar().onNavigate(ZadNavDestination.home);
          await frames(2);
        }

        step = 'more sheet';
        bar().onOpenMore();
        await frames();
        await tester.binding.handlePopRoute();
        await frames();

        step = 'voice sheet';
        bar().onOpenVoice();
        await frames();
        await tester.binding.handlePopRoute();
        await frames();

        step = 'camera';
        bar().onOpenCamera();
        await frames();
        await tester.binding.handlePopRoute();
        await frames();

        step = 'drawer';
        await tester.dragFrom(
          Offset(size.width - 1, 400),
          const Offset(-300, 0),
        );
        await frames();
        await tester.binding.handlePopRoute();
        await frames();

        step = 'back on home';
        await tester.binding.handlePopRoute();
        await frames();

        // Offline stand-ins refuse every network call, and plugins (camera,
        // microphone, url_launcher) are absent under a test; the screens handle
        // both. Anything else the framework raised is a bug.
        // Unmount, and let the screens' own timers run out.
        await tester.pumpWidget(const SizedBox());
        // The deals search waits up to two minutes for its answer.
        await tester.pump(const Duration(minutes: 3));
        debugPrint('walked ${visited.length} taps:\n${visited.join('\n')}');
        final real = errors
            .where((e) => !_harnessNoise.any(e.contains))
            .toList();
        expect(real, isEmpty, reason: real.join('\n\n———\n\n'));
      });
    }
  }
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

/// How many routes are on the navigator.
class _Depth extends NavigatorObserver {
  int depth = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => depth++;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => depth--;

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      depth--;
}

bool _isTappable(Widget w) => switch (w) {
  InkWell(:final onTap) => onTap != null,
  ListTile(:final onTap) => onTap != null,
  ButtonStyleButton(:final onPressed) => onPressed != null,
  IconButton(:final onPressed) => onPressed != null,
  Switch(:final onChanged) => onChanged != null,
  Chip() || ChoiceChip() || FilterChip() => true,
  _ => false,
};

String _labelOf(Element e) {
  final texts = <String>[];
  void visit(Element el) {
    final w = el.widget;
    if (w is Text && w.data != null) texts.add(w.data!);
    if (w is Tooltip && w.message != null) texts.add(w.message!);
    if (texts.length < 3) el.visitChildren(visit);
  }

  visit(e);
  return texts.isEmpty ? e.widget.runtimeType.toString() : texts.join(' ');
}

/// Controls that would end the walk rather than test a screen.
const List<String> _unsafe = <String>['الخروج', 'حذف الحساب', 'امسح كل'];

// (Native pickers are absent under a test; the screens catch their errors.)

/// What a test without a server or plugins raises by design.
const List<String> _harnessNoise = <String>[
  'MissingPluginException',
  'SocketException',
  'Connection refused',
  'ClientException',
  'has not been implemented',
];
