// «بريميوم» as a world: the state line follows the real plan, the invite line
// otherwise, the prices still come from the store, and the subscribe button
// is docked below the scroll with the renewal terms and the free plan kept.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/paywall/presentation/paywall_screen.dart';
import 'package:zad/shared/ads/application/ads_policy.dart';
import 'package:zad/shared/billing/data/play_billing.dart';
import 'package:zad/shared/quota/application/attempts_balance_provider.dart';
import 'package:zad/shared/quota/domain/attempts_balance.dart';

import '../../support/fonts.dart';
import '../../support/quiet_household.dart';

/// Play with three products at fixed prices.
class _Store implements PlayStore {
  @override
  Stream<List<PurchaseDetails>> get purchases =>
      const Stream<List<PurchaseDetails>>.empty();

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<List<ProductDetails>> products(Set<String> ids) async =>
      <ProductDetails>[
        for (final (id, price) in <(String, String)>[
          (ZadPlayProducts.basic, 'EGP 99.99'),
          (ZadPlayProducts.plus, 'EGP 249.99'),
          (ZadPlayProducts.ultra, 'EGP 449.99'),
        ])
          if (ids.contains(id))
            ProductDetails(
              id: id,
              title: id,
              description: id,
              price: price,
              rawPrice: 0,
              currencyCode: 'EGP',
            ),
      ];

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

PlayBilling _billing() => PlayBilling(
  store: _Store(),
  verify: (_) async => null,
  currentUser: () => 'user-1',
);

AttemptsBalance _balance(String tier) => AttemptsBalance(
  tier: tier,
  left: 700,
  perCycle: 1000,
  nextRefillAt: null,
  adsEnabled: false,
);

void main() {
  Future<void> pump(
    WidgetTester tester, {
    String? tier,
    double height = 1864,
  }) async {
    tester.view
      ..physicalSize = Size(860, height)
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...quietOrbOverrides,
          adsAllowedProvider.overrideWithValue(false),
          playBillingProvider.overrideWithValue(_billing()),
          attemptsBalanceProvider.overrideWith(
            (ref) async => tier == null ? null : _balance(tier),
          ),
        ],
        child: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            theme: ZadTheme.light(),
            locale: const Locale('ar'),
            supportedLocales: ZadL10n.supportedLocales,
            localizationsDelegates: ZadL10n.localizationsDelegates,
            home: const PaywallScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('free plan: the invite line, store prices, terms, free plan', (
    tester,
  ) async {
    await pump(tester, tier: 'free', height: 4000);
    expect(find.text('بريميوم'), findsWidgets);
    expect(find.text('اختار الباقة اللي تناسب بيتك'), findsOneWidget);
    expect(find.text('EGP 99.99 في الشهر'), findsOneWidget);
    expect(find.text('EGP 249.99 في الشهر'), findsOneWidget);
    expect(find.text('EGP 449.99 في الشهر'), findsOneWidget);
    expect(find.text('اشتراك شهري تجديد تلقائي'), findsNWidgets(3));
    expect(find.textContaining('مع إمكانية الإلغاء في أي وقت'), findsOneWidget);
    expect(find.text('أو كمّل على المجاني'), findsOneWidget);
    expect(
      find.text('اشترك في المتقدمة (Plus) عبر Google Play'),
      findsOneWidget,
    );
  });

  testWidgets('a paid plan: the state line names it', (tester) async {
    await pump(tester, tier: 'plus');
    expect(find.text('خطتك دلوقتي: بلس'), findsOneWidget);
    expect(find.text('اختار الباقة اللي تناسب بيتك'), findsNothing);
  });

  testWidgets('no balance (offline): the invite line, never a guessed plan', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('اختار الباقة اللي تناسب بيتك'), findsOneWidget);
    expect(find.textContaining('خطتك دلوقتي'), findsNothing);
  });

  testWidgets('the subscribe button sits at the bottom, below the scroll', (
    tester,
  ) async {
    await pump(tester, tier: 'free');
    final button = tester.getRect(
      find.byKey(const ValueKey<String>('cta-glow')),
    );
    final view = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(button.bottom, greaterThan(view.height - 100));
    expect(button.height, greaterThanOrEqualTo(44));
  });

  testWidgets('screenshot: the premium world', (tester) async {
    await loadZadFonts();
    await pump(tester, tier: 'free');
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../../build/screens/world_premium.png'),
    );
  }, skip: Platform.environment['ZAD_SCREENS'] != '1');
}
