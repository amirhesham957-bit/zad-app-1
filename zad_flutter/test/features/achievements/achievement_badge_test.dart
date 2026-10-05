// The badges are Lottie files bundled with the app: one per catalogue entry,
// looping once earned, still and grey while locked, the emoji if a file
// cannot load.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:zad/features/achievements/domain/achievements.dart';
import 'package:zad/features/achievements/presentation/achievements_screen.dart';

AchievementDef _def(String asset) => (
  id: 'first_step',
  name: 'الخطوة الأولى',
  description: 'أضف سعرك الأول',
  icon: '🌟',
  lottieAsset: asset,
  points: 10,
  condition: AchievementCondition.contributionCount,
  threshold: 1,
);

Future<void> _pump(
  WidgetTester tester,
  AchievementDef def, {
  required bool unlocked,
  bool still = false,
}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: still),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: AchievementBadge(def: def, unlocked: unlocked),
        ),
      ),
    ),
  );
  // The asset loads off the frame clock.
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pump();
}

LottieBuilder _lottie(WidgetTester tester) =>
    tester.widget<LottieBuilder>(find.byType(LottieBuilder));

void main() {
  test('every catalogue entry has its own badge file, and it parses', () async {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final assets = <String>{};
    for (final d in kAchievementCatalog) {
      expect(d.lottieAsset, 'assets/lottie/badges/badge_${d.id}.json');
      final dir = d.lottieAsset.substring(
        0,
        d.lottieAsset.lastIndexOf('/') + 1,
      );
      // Flutter does not bundle sub-folders of a listed folder.
      expect(pubspec, contains('- $dir\n'), reason: d.id);
      final composition = await LottieComposition.fromBytes(
        File(d.lottieAsset).readAsBytesSync(),
      );
      expect(composition.duration, greaterThan(Duration.zero), reason: d.id);
      assets.add(d.lottieAsset);
    }
    expect(assets, hasLength(kAchievementCatalog.length));
  });

  testWidgets('an earned badge loops in colour', (tester) async {
    await _pump(tester, kAchievementCatalog.first, unlocked: true);
    expect(_lottie(tester).animate, isTrue);
    expect(find.byType(ColorFiltered), findsNothing);
    expect(find.text('🌟'), findsNothing);
  });

  testWidgets('a locked badge is still and grey', (tester) async {
    await _pump(tester, kAchievementCatalog.first, unlocked: false);
    expect(_lottie(tester).animate, isFalse);
    expect(
      find.ancestor(
        of: find.byType(LottieBuilder),
        matching: find.byType(ColorFiltered),
      ),
      findsOneWidget,
    );
  });

  testWidgets('reduced motion holds an earned badge still', (tester) async {
    await _pump(tester, kAchievementCatalog.first, unlocked: true, still: true);
    expect(_lottie(tester).animate, isFalse);
  });

  testWidgets('a missing file falls back to the emoji', (tester) async {
    await _pump(
      tester,
      _def('assets/lottie/badges/missing.json'),
      unlocked: true,
    );
    expect(find.text('🌟'), findsOneWidget);
  });
}
