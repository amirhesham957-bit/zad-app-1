// «عربي | English» on the first screen (owner, 2026-10-27): the choice redraws
// the intro at once in the language picked, and it is the same choice as
// settings.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/l10n/app_language.dart';
import 'package:zad/core/l10n/generated/zad_l10n.dart';
import 'package:zad/features/onboarding/presentation/intro_screen.dart';

class _App extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
    locale: ref.watch(appLocaleProvider),
    supportedLocales: kZadLocales,
    localizationsDelegates: const <LocalizationsDelegate<Object>>[
      ZadL10n.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: const IntroScreen(),
  );
}

void main() {
  testWidgets('the intro opens in Arabic and switches to English and back', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [phoneLocaleProvider.overrideWithValue(const Locale('ar'))],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const _App()),
    );
    await tester.pump();
    expect(find.text('التالي'), findsOneWidget);
    expect(find.text('إدارة المخزون'), findsOneWidget);

    await tester.tap(find.text('English'));
    await tester.pump();
    expect(container.read(appLanguageProvider), AppLanguage.english);
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Your pantry'), findsOneWidget);
    expect(find.text('التالي'), findsNothing);

    await tester.tap(find.text('العربية'));
    await tester.pump();
    expect(container.read(appLanguageProvider), AppLanguage.arabic);
    expect(find.text('التالي'), findsOneWidget);
  });
}
