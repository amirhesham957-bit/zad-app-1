/// Which language the app speaks (ZAD_PLAN ٦.١).
///
/// The owner's decision (2026-10-18): English beside Arabic, the customer
/// switches in settings, and the first language comes from the phone. Not an
/// English launch — a choice for whoever is used to it.
///
/// A phone preference, kept in the `device` box like the UI sounds: the
/// account is shared by a household, the language is per person and phone.
library;

import 'dart:async';
import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/providers.dart';

/// Whether the English translation covers enough to follow the phone.
///
/// Until it does (ZAD_PLAN ٦.٣), «زي الموبايل» stays Arabic even on an
/// English phone: an English layout over Arabic text helps nobody. Choosing
/// English by hand works already, with a note that it is incomplete.
const bool kEnglishFollowsPhone = false;

/// The choice in settings.
enum AppLanguage {
  /// The phone's language.
  system,

  /// Arabic.
  arabic,

  /// English.
  english,
}

/// The two languages the app has.
const List<Locale> kZadLocales = <Locale>[Locale('ar'), Locale('en')];

/// The locale a choice comes to on a phone set to [phone].
Locale resolveAppLocale(
  AppLanguage choice,
  Locale phone, {
  bool englishFollowsPhone = kEnglishFollowsPhone,
}) => switch (choice) {
  AppLanguage.arabic => const Locale('ar'),
  AppLanguage.english => const Locale('en'),
  AppLanguage.system =>
    englishFollowsPhone && phone.languageCode != 'ar'
        ? const Locale('en')
        : const Locale('ar'),
};

/// The choice, remembered on this phone.
class AppLanguageController extends Notifier<AppLanguage> {
  static const String _key = 'app_language';

  @override
  AppLanguage build() {
    try {
      final stored = ref.read(localStoreProvider).device.get(_key);
      return AppLanguage.values.firstWhere(
        (l) => l.name == stored,
        orElse: () => AppLanguage.system,
      );
    } on Object {
      // No store (a test): the phone decides.
      return AppLanguage.system;
    }
  }

  /// Switches to [language]. The app redraws at once; the write follows.
  void choose(AppLanguage language) {
    if (state == language) return;
    state = language;
    try {
      unawaited(ref.read(localStoreProvider).device.put(_key, language.name));
    } on Object {
      // No store (a test): the choice lives for this run only.
    }
  }
}

/// The choice.
final appLanguageProvider =
    NotifierProvider<AppLanguageController, AppLanguage>(
      AppLanguageController.new,
    );

/// The phone's own language; a test replaces it.
final phoneLocaleProvider = Provider<Locale>(
  (ref) => PlatformDispatcher.instance.locale,
);

/// The locale the app is drawn in.
final appLocaleProvider = Provider<Locale>(
  (ref) => resolveAppLocale(
    ref.watch(appLanguageProvider),
    ref.watch(phoneLocaleProvider),
  ),
);
