// «التطبيق يركّز» (ZAD_PLAN 6.5): the drawer shows the basics and what this
// customer has opened; nothing disappears, the rest waits under «كل المزايا».

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/app/shell/zad_chrome.dart';
import 'package:zad/core/data/local/boxes.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/core/l10n/generated/zad_l10n.dart';

void main() {
  List<String> ids(List<ZadDrawerEntry> entries) => <String>[
    for (final e in entries) e.id,
  ];

  group('focusDrawer', () {
    test('a new customer sees the basics, and nothing is lost', () {
      final split = focusDrawer(zadDrawerEntries, const <String>{}, 'home');
      expect(
        ids(split.shown),
        containsAll(<String>['home', 'budget', 'inventory', 'family']),
      );
      expect(ids(split.shown), isNot(contains('pharmacy')));
      expect(ids(split.more), contains('pharmacy'));
      expect(
        <String>{...ids(split.shown), ...ids(split.more)},
        <String>{...ids(zadDrawerEntries)},
      );
      expect(split.shown.length + split.more.length, zadDrawerEntries.length);
    });

    test('a section that was opened moves up, in its usual place', () {
      final split = focusDrawer(zadDrawerEntries, const <String>{
        'pharmacy',
      }, 'home');
      expect(ids(split.shown), contains('pharmacy'));
      expect(ids(split.more), isNot(contains('pharmacy')));
      final all = ids(zadDrawerEntries);
      expect(
        ids(split.shown),
        orderedEquals(all.where(ids(split.shown).contains)),
      );
    });

    test('the section on screen is never tucked away', () {
      final split = focusDrawer(
        zadDrawerEntries,
        const <String>{},
        'maintenance',
      );
      expect(ids(split.shown), contains('maintenance'));
    });

    test('an entry the list does not know about changes nothing', () {
      final split = focusDrawer(zadDrawerEntries, const <String>{
        'knowledge_map',
      }, 'home');
      expect(split.shown.length + split.more.length, zadDrawerEntries.length);
    });
  });

  testWidgets('«كل المزايا» opens the rest, and each row still navigates', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final split = focusDrawer(zadDrawerEntries, const <String>{}, 'home');
    final went = <String>[];
    final key = GlobalKey<ScaffoldState>();
    Hive.init('unused');
    final box = await tester.runAsync(
      () => Hive.openBox<String>('drawer_device', bytes: Uint8List(0)),
    );
    addTearDown(() => tester.runAsync(box!.close));
    Future<void> frames() async {
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStoreProvider.overrideWithValue(
            ZadLocalStore(
              outbox: box!,
              transactions: box,
              documents: box,
              chat: box,
              inventory: box,
              shopping: box,
              pharmacy: box,
              subscriptions: box,
              device: box,
            ),
          ),
        ],
        child: MaterialApp(
          theme: ZadTheme.light(),
          locale: const Locale('ar'),
          localizationsDelegates: ZadL10n.localizationsDelegates,
          supportedLocales: ZadL10n.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            key: key,
            drawer: ZadDrawer(
              current: 'home',
              entries: split.shown,
              more: split.more,
              onNavigate: went.add,
              onProfile: () {},
            ),
            body: const SizedBox.expand(),
          ),
        ),
      ),
    );
    key.currentState!.openDrawer();
    await frames();

    final l = ZadL10n.of(tester.element(find.byType(ZadDrawer)));
    expect(find.text(l.drawerPharmacy), findsNothing);

    await tester.ensureVisible(find.text(l.drawerAllFeatures));
    await frames();
    await tester.tap(find.text(l.drawerAllFeatures));
    await frames();
    await tester.scrollUntilVisible(
      find.text(l.drawerPharmacy),
      120,
      scrollable: find.descendant(
        of: find.byType(ZadDrawer),
        matching: find.byType(Scrollable),
      ),
    );
    await frames();
    await tester.tap(find.text(l.drawerPharmacy));
    await frames();
    expect(went, <String>['pharmacy']);
  });
}
