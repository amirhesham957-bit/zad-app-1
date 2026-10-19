// The plans page's motion (owner, 2026-10-05): Plus and Ultra glow, a pick
// throws confetti, everything holds still under reduced motion — and no
// countdown or discount until the Play Console has a real offer.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:zad/features/paywall/presentation/paywall_screen.dart';
import 'package:zad/shared/ads/application/ads_policy.dart';
import 'package:zad/shared/ads/data/ad_reward_preview.dart';
import 'package:zad/shared/ads/data/rewarded_ads.dart';
import 'package:zad/shared/auth/application/session_controller.dart';

class _SignedIn extends SessionController {
  @override
  String? build() => 'user-1';
}

class _Ads implements RewardedAds {
  @override
  Future<RewardedOutcome> watch({required String userId}) async =>
      RewardedOutcome.earned;
}

class _Preview implements AdRewardPreviewRemote {
  @override
  Future<AdRewardPreview?> preview() async => const AdRewardPreview(
    available: true,
    reward: 2,
    boxBonus: 2,
    adsToday: 1,
  );
}

/// Ads are off unless a test turns them on: paid plans and kids mode see
/// none, and the free plan's button needs the session and the server preview.
Future<void> _pump(
  WidgetTester tester, {
  bool still = false,
  double width = 412,
  double textScale = 1,
  bool ads = false,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adsAllowedProvider.overrideWithValue(ads),
        if (ads) ...[
          sessionControllerProvider.overrideWith(_SignedIn.new),
          rewardedAdsProvider.overrideWithValue(_Ads()),
          adRewardPreviewRemoteProvider.overrideWithValue(_Preview()),
        ],
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: still,
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: PaywallScreen(),
        ),
      ),
    ),
  );
  await tester.pump();
}

Finder _confetti() => find.byWidgetPredicate(
  (w) =>
      w is LottieBuilder &&
      w.lottie is AssetLottie &&
      (w.lottie as AssetLottie).assetName.contains('confetti'),
);

Future<void> _leave(WidgetTester tester) async {
  // Unmount first: the beat never settles on its own.
  await tester.pumpWidget(const SizedBox.shrink());
}

void main() {
  testWidgets('Plus and Ultra glow and shimmer; Basic does not', (
    tester,
  ) async {
    await _pump(tester);
    for (final plan in <String>['plus', 'ultra']) {
      expect(find.byKey(ValueKey<String>('glow-$plan')), findsOneWidget);
      expect(find.byKey(ValueKey<String>('shimmer-$plan')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey<String>('glow-basic')), findsNothing);
    expect(find.byKey(const ValueKey<String>('shimmer-basic')), findsNothing);
    expect(find.byKey(const ValueKey<String>('cta-glow')), findsOneWidget);
    await _leave(tester);
  });

  testWidgets('each plan is a pane of frosted glass over the backdrop', (
    tester,
  ) async {
    await _pump(tester);
    for (final plan in <String>['basic', 'plus', 'ultra']) {
      expect(find.byKey(ValueKey<String>('plan-glass-$plan')), findsOneWidget);
    }
    await _leave(tester);
  });

  testWidgets('picking a plan throws confetti and names it on the button', (
    tester,
  ) async {
    await _pump(tester);
    expect(_confetti(), findsNothing);
    await tester.tap(find.text('العيلة (Family)'));
    await tester.pump();
    expect(_confetti(), findsOneWidget);
    expect(
      find.text('اشترك في العيلة (Family) عبر Google Play'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    await _leave(tester);
  });

  testWidgets('tapping the plan already picked throws nothing', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('المتقدمة (Plus)'));
    await tester.pump();
    expect(_confetti(), findsNothing);
    await _leave(tester);
  });

  testWidgets('reduced motion: no confetti, and the page settles', (
    tester,
  ) async {
    await _pump(tester, still: true);
    await tester.tap(find.text('الأساسية (Basic)'));
    await tester.pump();
    expect(_confetti(), findsNothing);
    // Would time out if anything kept repeating.
    await tester.pumpAndSettle();
    expect(
      find.text('اشترك في الأساسية (Basic) عبر Google Play'),
      findsOneWidget,
    );
  });

  testWidgets('no countdown and no discount on the page', (tester) async {
    await _pump(tester, still: true);
    for (final word in <String>['خصم', 'متبقي', 'عرض لفترة', 'ينتهي']) {
      expect(find.textContaining(word), findsNothing, reason: word);
    }
  });

  testWidgets('no ad button where ads may not show (paid plan, kids)', (
    tester,
  ) async {
    await _pump(tester, still: true);
    expect(find.byKey(const ValueKey<String>('watch-ad')), findsNothing);
    expect(find.textContaining('شاهد'), findsNothing);
    expect(find.textContaining('5 محاولات بترجع كل 5 ساعات'), findsOneWidget);
  });

  testWidgets('the free plan offers «شاهد وخد» when ads may show', (
    tester,
  ) async {
    await _pump(tester, still: true, ads: true);
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('watch-ad')), findsOneWidget);
    expect(find.text('شاهد إعلان وخد محاولتين'), findsOneWidget);
  });

  testWidgets('fits a small phone at large text', (tester) async {
    await _pump(tester, still: true, width: 320, textScale: 1.3);
    expect(tester.takeException(), isNull);
  });
}
