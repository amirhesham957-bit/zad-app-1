/// Examples a screen shows, from the account's market (ZAD_PLAN 3.13).
///
/// A Saudi customer saw «مثل: القاهرة، الجيزة» under the price report and
/// «محفظة / إنستاباي» on the receipt scanner. Every hint that names a place,
/// a shop, a wallet or a currency comes from here, keyed by the account's
/// country (`accountCountryProvider`): Egypt's, Saudi Arabia's, and for any
/// other or unknown market an example that names no country at all. The
/// words are in the ARB files; the bank messages below are data the listener
/// parses. `test/shared/market/market_examples_test.dart` fails if one
/// market's words reach the other.
library;

import 'package:zad/core/l10n/l10n.dart';

/// The account's market as these examples know it.
enum ExampleMarket {
  /// Egypt.
  eg,

  /// Saudi Arabia.
  sa,

  /// Anywhere else, or not known yet.
  other;

  /// From an ISO country code; anything but EG or SA is [other].
  static ExampleMarket of(String? country) =>
      switch ((country ?? '').trim().toUpperCase()) {
        'EG' => eg,
        'SA' => sa,
        _ => other,
      };
}

/// «مثل: …» under the city field of a price report.
String cityExample(ZadL10n l, String? country) =>
    switch (ExampleMarket.of(country)) {
      ExampleMarket.eg => l.exampleCityEg,
      ExampleMarket.sa => l.exampleCitySa,
      ExampleMarket.other => l.exampleCityOther,
    };

/// «مثل: …» under the store field of a price report.
String storeExample(ZadL10n l, String? country) =>
    switch (ExampleMarket.of(country)) {
      ExampleMarket.eg => l.exampleStoreEg,
      ExampleMarket.sa => l.exampleStoreSa,
      ExampleMarket.other => l.exampleStoreOther,
    };

/// The receipt scanner's «paid from the bank account» choice.
String bankWalletLabel(ZadL10n l, String? country) =>
    switch (ExampleMarket.of(country)) {
      ExampleMarket.eg => l.walletBankEg,
      ExampleMarket.sa => l.walletBankSa,
      ExampleMarket.other => l.walletBankOther,
    };

// l10n: data-begin — bank messages the listener's own parser reads.

/// A bank message the listener test can read, in the market's own wording.
({String title, String text}) bankSample(String? country) =>
    switch (ExampleMarket.of(country)) {
      ExampleMarket.sa => (
        title: 'الراجحي',
        text:
            'شراء عبر نقاط البيع مبلغ 250.00 ريال من بنده العليا. '
            'مرجع: TX48213',
      ),
      _ => (
        title: 'CIB',
        text:
            'CIB: تم خصم مبلغ 250.00 جنيه من حسابك لدى كارفور مصر الجديدة. '
            'مرجع: TX48213',
      ),
    };

/// The body of the test notification the listener screen sends itself.
String testNotificationBody(String? country) =>
    switch (ExampleMarket.of(country)) {
      ExampleMarket.sa => 'تم خصم 123.45 ريال من حسابك — اختبار رصد',
      ExampleMarket.eg => 'تم خصم 123.45 جنيه من حسابك — اختبار رصد',
      ExampleMarket.other => 'تم خصم 123.45 من حسابك — اختبار رصد',
    };

// l10n: data-end
