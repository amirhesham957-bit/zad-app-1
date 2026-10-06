// The plans page's motion (owner, 2026-10-05): Plus and Ultra glow, a pick
// throws confetti, everything holds still under reduced motion — and no
// countdown or discount until the Play Console has a real offer.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:zad/features/paywall/presentation/paywall_screen.dart';

Future<void> _pump(
  WidgetTester tester, {
  bool still = false,
  double width = 412,
  double textScale = 1,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
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

  testWidgets('picking a plan throws confetti and names it on the button', (
    tester,
  ) async {
    await _pump(tester);
    expect(_confetti(), findsNothing);
    await tester.tap(find.text('الفائقة (Ultra)'));
    await tester.pump();
    expect(_confetti(), findsOneWidget);
    expect(
      find.text('اشترك في الفائقة (Ultra) عبر Google Play'),
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

  testWidgets('fits a small phone at large text', (tester) async {
    await _pump(tester, still: true, width: 320, textScale: 1.3);
    expect(tester.takeException(), isNull);
  });
}
