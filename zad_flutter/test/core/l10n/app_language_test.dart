// ZAD_PLAN 6.1: Arabic and English, the first language from the phone, a
// switch in settings, and the screen turns its direction with the language.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/l10n/app_language.dart';
import 'package:zad/core/l10n/l10n.dart';

void main() {
  group('which locale', () {
    test('Arabic and English by hand, whatever the phone says', () {
      expect(
        resolveAppLocale(AppLanguage.english, const Locale('ar')),
        const Locale('en'),
      );
      expect(
        resolveAppLocale(AppLanguage.arabic, const Locale('en')),
        const Locale('ar'),
      );
    });

    test('the phone decides once English is ready to follow it', () {
      expect(
        resolveAppLocale(
          AppLanguage.system,
          const Locale('en', 'US'),
          englishFollowsPhone: true,
        ),
        const Locale('en'),
      );
      expect(
        resolveAppLocale(
          AppLanguage.system,
          const Locale('ar', 'EG'),
          englishFollowsPhone: true,
        ),
        const Locale('ar'),
      );
    });

    test('until then an English phone still opens in Arabic', () {
      expect(
        resolveAppLocale(
          AppLanguage.system,
          const Locale('en', 'US'),
        ),
        const Locale('ar'),
      );
    });
  });

  testWidgets('switching to English turns the screen left to right', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [phoneLocaleProvider.overrideWithValue(const Locale('ar'))],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
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
            home: Builder(
              builder: (context) => Text(
                '${Directionality.of(context).name} '
                '${context.l10n.settingsLanguageSection}',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('rtl اللغة'), findsOneWidget);

    container.read(appLanguageProvider.notifier).choose(AppLanguage.english);
    await tester.pumpAndSettle();
    expect(find.text('ltr Language'), findsOneWidget);
  });

  testWidgets('a widget drawn without the delegate gets Arabic, not a crash', (
    tester,
  ) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(builder: (context) => Text(context.l10n.appTitle)),
      ),
    );
    expect(find.text('زاد'), findsOneWidget);
  });

  test('every Arabic string has its English line, and nothing extra', () {
    Set<String> keys(String path) =>
        (jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>).keys
            .where((k) => !k.startsWith('@'))
            .toSet();
    final ar = keys('lib/core/l10n/app_ar.arb');
    final en = keys('lib/core/l10n/app_en.arb');
    expect(ar.difference(en), isEmpty, reason: 'missing in English');
    expect(en.difference(ar), isEmpty, reason: 'English has keys Arabic lacks');
  });
}
