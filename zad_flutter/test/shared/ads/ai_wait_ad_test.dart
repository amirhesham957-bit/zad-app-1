// Owner 15/11: every AI request carries a video ad while the AI works. The
// wait ad reports one aiWait break per wait, never on a rebuild, and nothing
// at all when ads are not allowed (kids mode, paid plan).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/shared/ads/application/ads_policy.dart';
import 'package:zad/shared/ads/application/interstitials.dart';
import 'package:zad/shared/ads/data/interstitial_ads.dart';
import 'package:zad/shared/ads/presentation/ai_wait_ad.dart';

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

  testWidgets('building it once reports exactly one aiWait break', (
    tester,
  ) async {
    await mount(tester, allowed: true);
    await tester.pump();
    expect(breaks.kinds, <InterstitialBreak>[InterstitialBreak.aiWait]);
  });

  testWidgets('rebuilds do not report again', (tester) async {
    await mount(tester, allowed: true);
    await mount(tester, allowed: true);
    await tester.pump();
    await tester.pump();
    expect(breaks.kinds, hasLength(1));
  });

  testWidgets('nothing is reported or drawn when ads are not allowed', (
    tester,
  ) async {
    await mount(tester, allowed: false);
    await tester.pump();
    expect(breaks.kinds, isEmpty);
    expect(tester.getSize(find.byType(ZadAiWaitAd)), Size.zero);
  });
}
