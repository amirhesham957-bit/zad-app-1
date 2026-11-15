// Owner 15/11 (approved plan): a quick answer shows no ad, a slow one shows
// the native ad, a long one also reports one aiWait break (the pacer decides
// the full-screen ad) — never on a rebuild, and nothing at all when ads are
// not allowed (kids mode, paid plan).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/shared/ads/application/ads_policy.dart';
import 'package:zad/shared/ads/application/interstitials.dart';
import 'package:zad/shared/ads/data/interstitial_ads.dart';
import 'package:zad/shared/ads/presentation/ai_wait_ad.dart';
import 'package:zad/shared/ads/presentation/inline_ad.dart';
import 'package:zad/shared/ads/presentation/native_ad.dart';

class _FakeAds implements InterstitialAds {
  int shown = 0;

  @override
  bool get configured => true;

  @override
  Future<void> preload() async {}

  @override
  Future<bool> showReady() async {
    shown++;
    return true;
  }
}

class _Breaks implements Interstitials {
  final List<InterstitialBreak> kinds = <InterstitialBreak>[];

  @override
  Future<bool> atBreak(InterstitialBreak kind) async {
    kinds.add(kind);
    return false;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  late _Breaks breaks;

  Future<void> mount(
    WidgetTester tester, {
    required bool allowed,
    Widget child = const ZadAiWaitAd(),
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adsAllowedProvider.overrideWithValue(allowed),
          interstitialsProvider.overrideWithValue(breaks),
          interstitialAdsProvider.overrideWithValue(_FakeAds()),
        ],
        child: MaterialApp(home: Scaffold(body: child)),
      ),
    );
    await tester.pump();
  }

  setUp(() => breaks = _Breaks());

  testWidgets('a quick answer shows no ad and reports no break', (
    tester,
  ) async {
    await mount(tester, allowed: true);
    await tester.pump(const Duration(milliseconds: 1400));
    expect(find.byType(ZadInlineAd), findsNothing);
    expect(find.byType(ZadNativeAd), findsNothing);
    // The answer arrived: the wait widget leaves.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
    expect(breaks.kinds, isEmpty);
  });

  testWidgets('a slow wait draws the ad but reports no break yet', (
    tester,
  ) async {
    await mount(tester, allowed: true);
    final ad = find.byWidgetPredicate(
      (w) => w is ZadNativeAd || w is ZadInlineAd,
    );
    expect(ad, findsNothing);
    await tester.pump(ZadAiWaitAd.nativeAfter);
    // Google's test native unit in debug; the inline banner if it fails.
    expect(ad, findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(breaks.kinds, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
    expect(breaks.kinds, isEmpty);
  });

  testWidgets('a long wait reports exactly one aiWait break', (tester) async {
    await mount(tester, allowed: true);
    await tester.pump(ZadAiWaitAd.fullScreenAfter);
    expect(breaks.kinds, <InterstitialBreak>[InterstitialBreak.aiWait]);
  });

  testWidgets('rebuilds do not report again', (tester) async {
    await mount(tester, allowed: true);
    await mount(tester, allowed: true);
    await tester.pump(ZadAiWaitAd.fullScreenAfter);
    await tester.pump(const Duration(seconds: 20));
    expect(breaks.kinds, hasLength(1));
  });

  testWidgets('nothing is reported or drawn when ads are not allowed', (
    tester,
  ) async {
    await mount(tester, allowed: false);
    await tester.pump(ZadAiWaitAd.fullScreenAfter);
    expect(breaks.kinds, isEmpty);
    expect(tester.getSize(find.byType(ZadAiWaitAd)), Size.zero);
  });
}
