// ZAD_PLAN ١٠.١٦: a Saudi account reads Saudi screens; nobody else changes.
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:zad/core/l10n/app_language.dart';
import 'package:zad/core/l10n/generated/zad_l10n.dart';
import 'package:zad/shared/market/application/arabic_variant.dart';

void main() {
  test("the market picks Saudi; the customer's own dialect outranks it", () {
    expect(arabicVariantFor(country: 'SA'), 'SA');
    expect(arabicVariantFor(country: 'sa'), 'SA');
    expect(arabicVariantFor(country: 'EG'), isNull);
    expect(arabicVariantFor(), isNull);
    // An Egyptian in Riyadh who chose «مصري».
    expect(arabicVariantFor(country: 'SA', dialect: 'EG'), isNull);
    expect(arabicVariantFor(country: 'EG', dialect: 'SA'), 'SA');
    // Gulf is not Saudi yet: it keeps the default until it has its own file.
    expect(arabicVariantFor(country: 'AE'), isNull);
  });

  test('a Saudi account draws in ar_SA; English stays English', () {
    const phone = Locale('ar');
    expect(
      resolveAppLocale(AppLanguage.system, phone, arabicVariant: 'SA'),
      kSaudiArabic,
    );
    expect(
      resolveAppLocale(AppLanguage.arabic, phone, arabicVariant: 'SA'),
      kSaudiArabic,
    );
    expect(
      resolveAppLocale(AppLanguage.english, phone, arabicVariant: 'SA'),
      const Locale('en'),
    );
    expect(resolveAppLocale(AppLanguage.system, phone), const Locale('ar'));
    expect(kZadLocales, contains(kSaudiArabic));
  });

  test('ar_SA overrides the Egyptian strings and falls back for the rest', () {
    final ar = lookupZadL10n(const Locale('ar'));
    final sa = lookupZadL10n(kSaudiArabic);
    expect(ar.briefTitle, contains('النهارده'));
    expect(sa.briefTitle, isNot(contains('النهارده')));
    expect(sa.briefTitle, contains('اليوم'));
    // Not in app_ar_SA.arb: the same string as Arabic.
    expect(sa.appTitle, ar.appTitle);
    expect(sa.amazonOut, ar.amazonOut);
  });

  test('dates format the same under ar_SA as under ar', () async {
    await initializeDateFormatting();
    final day = DateTime.utc(2026, 11, 12);
    final sa = lookupZadL10n(kSaudiArabic).localeName;
    expect(
      DateFormat('d MMMM', sa).format(day),
      DateFormat('d MMMM', 'ar').format(day),
    );
  });
}
