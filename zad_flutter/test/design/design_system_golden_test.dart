@Tags(<String>['golden'])
library;

// Renders the design system to PNGs so it can be looked at.
//
// There is no emulator in this environment, so this is the only way to see what
// the tokens actually add up to — and "the code looks right" is not a review of
// a visual design. Run with:
//
//   flutter test --update-goldens test/design/design_system_golden_test.dart
//
// and open test/design/goldens/. The real fonts are loaded first, because
// without them flutter_test substitutes a blank face and every string renders
// as
// boxes, which makes the output useless for judging type.
//
// Tagged `golden` and excluded from CI. These images were rendered by this
// machine's Skia; another Flutter version or another platform will produce
// pixels that differ without anything being wrong, and a design review tool
// that fails the build on a font-hinting change is a design review tool nobody
// keeps. Run it deliberately, look at the output, commit the update.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:zad/core/period/budget_period.dart';
import 'package:zad/core/period/payday.dart';
import 'package:zad/design/components/zad_balance_card.dart';
import 'package:zad/design/components/zad_card.dart';
import 'package:zad/design/components/zad_empty_state.dart';
import 'package:zad/design/foundation/glass_surface.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/design/zad_theme.dart';

Future<void> _loadFonts() async {
  Future<void> load(String family, String asset) async {
    final loader = FontLoader(family)..addFont(rootBundle.load(asset));
    await loader.load();
  }

  await load('Cairo', 'assets/fonts/cairo_variable.ttf');
  await load('Inter', 'assets/fonts/inter_variable.ttf');
  // The family name has the package prefix. An IconData carrying
  // `fontPackage: 'lucide_icons_flutter'` resolves to
  // `packages/lucide_icons_flutter/Lucide`, so registering it as plain 'Lucide'
  // loads a font nothing asks for and every icon renders as a tofu box.
  await load(
    'packages/lucide_icons_flutter/Lucide',
    'packages/lucide_icons_flutter/assets/lucide.ttf',
  );
}

void main() {
  setUpAll(() async {
    tz_data.initializeTimeZones();
    await _loadFonts();
  });

  /// Wraps [child] the way the app does: RTL, Arabic, the real theme, on the
  /// canvas gradient.
  Widget harness(Widget child, {double width = 390}) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ZadTheme.light(),
    locale: const Locale('ar'),
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    supportedLocales: const <Locale>[Locale('ar')],
    // Inside a Scaffold, like the real app. Outside a Material ancestor,
    // Flutter's DefaultTextStyle is its debug warning style and every Text
    // inherits a double yellow underline.
    home: Scaffold(
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: DecoratedBox(
          decoration: const BoxDecoration(gradient: ZadColors.canvas),
          child: Center(
            child: SizedBox(
              width: width,
              child: Padding(
                padding: const EdgeInsets.all(ZadSpacing.gutter),
                child: child,
              ),
            ),
          ),
        ),
      ),
    ),
  );

  final now = DateTime.parse('2026-09-19T12:00:00Z');

  BudgetPeriod periodFor({int? cycleStartDay}) => BudgetPeriod.at(
    at: now,
    country: 'EG',
    cycleStartDay: cycleStartDay,
    anchor: CycleAnchor.dayOfMonth,
  );

  testWidgets('the green card, comfortably within budget', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 320));
    await tester.pumpWidget(
      harness(
        ZadBalanceCard(
          spendable: 4820.5,
          spent: 3179.5,
          openingBalance: 8000,
          committed: 1200,
          currency: 'ج.م',
          period: periodFor(cycleStartDay: 25),
          now: now,
          onTap: () {},
        ),
      ),
    );
    // Past the count-up, so the figure is settled rather than mid-tween.
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await expectLater(
      find.byType(ZadBalanceCard),
      matchesGoldenFile('goldens/balance_card_on_pace.png'),
    );
  });

  testWidgets('the green card, spending ahead of the period', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 320));
    await tester.pumpWidget(
      harness(
        ZadBalanceCard(
          // Day 19 of a cycle that started on the 25th, with 89% gone.
          spendable: 880,
          spent: 7120,
          openingBalance: 8000,
          currency: 'ج.م',
          period: periodFor(cycleStartDay: 25),
          now: now,
          isStale: true,
          onTap: () {},
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await expectLater(
      find.byType(ZadBalanceCard),
      matchesGoldenFile('goldens/balance_card_ahead_of_pace.png'),
    );
  });

  testWidgets('cards, glass and icons on the canvas', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 560));
    await tester.pumpWidget(
      harness(
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ZadCard(
              onTap: () {},
              child: Row(
                children: <Widget>[
                  const Icon(ZadIcons.expense, color: ZadColors.green700),
                  const SizedBox(width: ZadSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text('قهوة', style: ZadType.titleSmall),
                        Text(
                          'مأكولات · كاش',
                          style: ZadType.bodySmall.copyWith(
                            color: ZadColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text('50', style: ZadType.figure(18)),
                  const SizedBox(width: ZadSpacing.xs),
                  const Icon(ZadIcons.forward, size: 18),
                ],
              ),
            ),
            const SizedBox(height: ZadSpacing.lg),
            // Glass needs something behind it to blur, so it sits over the
            // hero gradient rather than over the flat canvas.
            DecoratedBox(
              decoration: const BoxDecoration(gradient: ZadColors.hero),
              child: Padding(
                padding: const EdgeInsets.all(ZadSpacing.xl),
                child: ZadGlass.onDark(
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        ZadIcons.pending,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: ZadSpacing.md),
                      Expanded(
                        child: Text(
                          'عمليتان لسه محفوظتين على الجهاز',
                          style: ZadType.bodyMedium.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: ZadSpacing.lg),
            const ZadEmptyState(
              icon: ZadIcons.inventory,
              title: 'المخزن فاضي',
              message: 'صوّر فاتورة أو أضف أول حاجة، وزاد يتابعها معاك.',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(Column).first,
      matchesGoldenFile('goldens/surfaces_and_icons.png'),
    );
  });
}
