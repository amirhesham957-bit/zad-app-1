// The offers world: the live count in the state line, a real empty state, a
// code that copies to the clipboard, a link that opens, expired ones hidden.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/offers/domain/offers.dart';
import 'package:zad/features/offers/presentation/offers_screen.dart';

import '../../support/fonts.dart';
import '../../support/quiet_household.dart';

final DateTime _now = DateTime.utc(2026, 11, 20, 9);

final List<Offer> _partner = <Offer>[
  Offer(
    id: 'a',
    source: OfferSource.partner,
    store: 'بنده',
    title: 'خصم 15٪ على الألبان',
    code: 'BANDA15',
    link: 'https://example.com/banda',
    expiresAt: _now.add(const Duration(days: 3)),
  ),
  const Offer(
    id: 'b',
    source: OfferSource.partner,
    store: 'نون',
    title: '50 ريال على أول طلب',
    code: 'ZAD50',
    link: 'https://example.com/noon',
  ),
  Offer(
    id: 'c',
    source: OfferSource.partner,
    store: 'النهدي',
    title: 'شحن مجاني فوق 100 ريال',
    link: 'https://example.com/nahdi',
    expiresAt: _now.add(const Duration(hours: 5)),
  ),
  Offer(
    id: 'old',
    source: OfferSource.partner,
    store: 'قديم',
    link: 'https://example.com/old',
    expiresAt: _now.subtract(const Duration(days: 1)),
  ),
];

final List<Offer> _mine = <Offer>[
  Offer(
    id: 'm1',
    source: OfferSource.notification,
    store: 'هنقرستيشن',
    percent: 25,
    code: 'HUNGER25',
    expiresAt: _now.add(const Duration(days: 1, hours: 4)),
  ),
];

Widget _app({
  List<Offer> partner = const <Offer>[],
  List<Offer> mine = const <Offer>[],
  void Function(String)? onOpenLink,
  VoidCallback? onOpenNearby,
}) => ProviderScope(
  overrides: quietOrbOverrides,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ZadTheme.light(),
    locale: const Locale('ar'),
    supportedLocales: ZadL10n.supportedLocales,
    localizationsDelegates: ZadL10n.localizationsDelegates,
    home: Scaffold(
      body: OffersWorld(
        partner: partner,
        mine: mine,
        loading: false,
        now: _now,
        onRefresh: () async {},
        onOpenNearby: onOpenNearby ?? () {},
        onOpenLink: onOpenLink ?? (_) {},
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
  testWidgets('state line counts live offers; a code copies; a row opens', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    String? opened;
    var nearby = 0;
    await _open(
      tester,
      _app(
        partner: _partner,
        mine: _mine,
        onOpenLink: (u) => opened = u,
        onOpenNearby: () => nearby++,
      ),
    );
    expect(find.text('عروضي'), findsOneWidget);
    expect(find.text('4 عروض شغالة'), findsOneWidget);
    expect(find.textContaining('بينتهي النهارده'), findsOneWidget);
    expect(find.text('قديم'), findsNothing);
    expect(find.text('من غير كود'), findsOneWidget);
    await tester.tap(find.text('ZAD50'));
    await tester.pump();
    expect(copied, 'ZAD50');
    expect(find.text('اتنسخ الكود ZAD50'), findsOneWidget);
    await tester.tap(find.text('بنده'));
    expect(opened, 'https://example.com/banda');
    await tester.tap(find.text('عروض المحلات القريبة'));
    expect(nearby, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('nothing live shows a real empty state', (tester) async {
    await _open(tester, _app());
    expect(find.text('مفيش عروض شغالة دلوقتي'), findsOneWidget);
    expect(find.text('مفيش عروض شغالة'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  test('country rows win; GLOBAL fills in when the country has none', () {
    final rows = <Map<String, dynamic>>[
      <String, dynamic>{
        'source': 'dcm_offer',
        'external_id': '1',
        'country_code': 'SA',
        'store': 'A',
        'click_url': 'https://x.com/a',
      },
      <String, dynamic>{
        'source': 'dcm_offer',
        'external_id': '2',
        'country_code': 'GLOBAL',
        'store': 'B',
        'click_url': 'https://x.com/b',
      },
    ];
    expect(partnerOffersFrom(rows, country: 'SA').map((o) => o.store), ['A']);
    expect(partnerOffersFrom(rows, country: 'EG').map((o) => o.store), ['B']);
  });

  testWidgets('screenshot: the offers world', (tester) async {
    await loadZadFonts();
    await _open(tester, _app(partner: _partner, mine: _mine), h: 1864);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../../build/screens/world_offers.png'),
    );
    await tester.pumpWidget(const SizedBox());
  }, skip: Platform.environment['ZAD_SCREENS'] != '1');
}
