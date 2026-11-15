// The owner's bug: on a 360×640 phone the intro's buttons were pushed off the
// screen. The stage must give way, so title, body, both buttons stay inside.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/l10n/app_language.dart';
import 'package:zad/core/l10n/generated/zad_l10n.dart';
import 'package:zad/core/l10n/generated/zad_l10n_ar.dart';
import 'package:zad/features/onboarding/presentation/intro_screen.dart';

Widget _app({bool disableAnimations = false}) => ProviderScope(
  overrides: [phoneLocaleProvider.overrideWithValue(const Locale('ar'))],
  child: Consumer(
    builder: (context, ref, _) => MaterialApp(
      locale: ref.watch(appLocaleProvider),
      supportedLocales: kZadLocales,
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        ZadL10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(disableAnimations: disableAnimations),
        child: child!,
      ),
      home: const IntroScreen(),
    ),
  ),
);

void main() {
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  testWidgets(
    'title, body and both buttons fit a 360x640 phone on every page',
    (tester) async {
      phone(tester);
      await tester.pumpWidget(_app());
      await tester.pump(const Duration(milliseconds: 100));
      final screen = Offset.zero & const Size(360, 640);
      final l = ZadL10nAr();
      final pages = introPages(l);
      for (var i = 0; i < kIntroPageCount; i++) {
        final primary = find.text(
          i == kIntroPageCount - 1 ? l.introStart : l.introNext,
        );
        for (final f in <Finder>[
          find.text(pages[i].title),
          find.text(pages[i].body),
          primary,
          find.text(l.introSignUp),
        ]) {
          expect(f, findsOneWidget, reason: 'page $i');
          final r = tester.getRect(f);
          expect(
            screen.contains(r.topLeft) && screen.contains(r.bottomRight),
            isTrue,
            reason: 'page $i: $r outside $screen',
          );
        }
        final signUp = tester.getRect(find.text(l.introSignUp));
        expect(signUp.bottom, lessThanOrEqualTo(640));
        if (i < kIntroPageCount - 1) {
          await tester.tap(primary);
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pump(const Duration(milliseconds: 100));
        }
      }
    },
  );

  testWidgets("page 0's bubble pops in after about 500ms", (tester) async {
    phone(tester);
    await tester.pumpWidget(_app());
    final say = ZadL10nAr().introSayPantry;
    expect(find.text(say), findsNothing);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(say), findsOneWidget);
  });

  testWidgets('with reduced motion the screen settles', (tester) async {
    phone(tester);
    await tester.pumpWidget(_app(disableAnimations: true));
    await tester.pumpAndSettle();
    expect(find.text(ZadL10nAr().introSayPantry), findsOneWidget);
  });
}
