/// The markets an account can belong to.
///
/// Mirror of the Kotlin `Market` enum (`data/MarketProfile.kt`) — the same
/// nineteen countries, the same codes. The codes are data, not display: the
/// country goes into `zad_users.country` as the ISO alpha-2 code
/// `zad_market_timezone()` switches on, and the currency into
/// `zad_users.currency` as the ISO 4217 code the brain and the Telegram bot
/// read. The live table holds `EG`/`EGP` in exactly that shape (read
/// 2026-09-21). Change a code here and the server stops recognising the
/// account's market without anything failing.
///
/// Every country here must also be in `market_calendar.dart`'s zone table, or
/// the account's zone silently falls back to UTC — `market_test.dart` pins
/// that.
library;

import 'package:flutter/foundation.dart';

/// One market.
@immutable
class Market {
  /// Creates a market.
  const new({
    required this.country,
    required this.nameAr,
    required this.currency,
    required this.currencySymbol,
    required this.flag,
  });

  /// ISO 3166 alpha-2, upper case — what `zad_users.country` stores.
  final String country;

  /// The name the picker shows.
  final String nameAr;

  /// ISO 4217 — what `zad_users.currency` stores.
  final String currency;

  /// How the currency is written next to an amount.
  final String currencySymbol;

  /// The flag, as an emoji.
  final String flag;

  @override
  bool operator ==(Object other) => other is Market && other.country == country;

  @override
  int get hashCode => country.hashCode;

  @override
  String toString() => 'Market($country)';
}

/// Every market, in the order the Kotlin picker shows them.
const List<Market> kMarkets = <Market>[
  Market(
    country: 'SA',
    nameAr: 'السعودية',
    currency: 'SAR',
    currencySymbol: 'ر.س',
    flag: '🇸🇦',
  ),
  Market(
    country: 'EG',
    nameAr: 'مصر',
    currency: 'EGP',
    currencySymbol: 'ج.م',
    flag: '🇪🇬',
  ),
  Market(
    country: 'AE',
    nameAr: 'الإمارات',
    currency: 'AED',
    currencySymbol: 'د.إ',
    flag: '🇦🇪',
  ),
  Market(
    country: 'KW',
    nameAr: 'الكويت',
    currency: 'KWD',
    currencySymbol: 'د.ك',
    flag: '🇰🇼',
  ),
  Market(
    country: 'QA',
    nameAr: 'قطر',
    currency: 'QAR',
    currencySymbol: 'ر.ق',
    flag: '🇶🇦',
  ),
  Market(
    country: 'BH',
    nameAr: 'البحرين',
    currency: 'BHD',
    currencySymbol: 'د.ب',
    flag: '🇧🇭',
  ),
  Market(
    country: 'OM',
    nameAr: 'عُمان',
    currency: 'OMR',
    currencySymbol: 'ر.ع',
    flag: '🇴🇲',
  ),
  Market(
    country: 'JO',
    nameAr: 'الأردن',
    currency: 'JOD',
    currencySymbol: 'د.أ',
    flag: '🇯🇴',
  ),
  Market(
    country: 'LB',
    nameAr: 'لبنان',
    currency: 'LBP',
    currencySymbol: 'ل.ل',
    flag: '🇱🇧',
  ),
  Market(
    country: 'IQ',
    nameAr: 'العراق',
    currency: 'IQD',
    currencySymbol: 'د.ع',
    flag: '🇮🇶',
  ),
  Market(
    country: 'SY',
    nameAr: 'سوريا',
    currency: 'SYP',
    currencySymbol: 'ل.س',
    flag: '🇸🇾',
  ),
  Market(
    country: 'YE',
    nameAr: 'اليمن',
    currency: 'YER',
    currencySymbol: 'ر.ي',
    flag: '🇾🇪',
  ),
  Market(
    country: 'PS',
    nameAr: 'فلسطين',
    currency: 'ILS',
    currencySymbol: '₪',
    flag: '🇵🇸',
  ),
  Market(
    country: 'LY',
    nameAr: 'ليبيا',
    currency: 'LYD',
    currencySymbol: 'د.ل',
    flag: '🇱🇾',
  ),
  Market(
    country: 'SD',
    nameAr: 'السودان',
    currency: 'SDG',
    currencySymbol: 'ج.س',
    flag: '🇸🇩',
  ),
  Market(
    country: 'MA',
    nameAr: 'المغرب',
    currency: 'MAD',
    currencySymbol: 'د.م',
    flag: '🇲🇦',
  ),
  Market(
    country: 'TN',
    nameAr: 'تونس',
    currency: 'TND',
    currencySymbol: 'د.ت',
    flag: '🇹🇳',
  ),
  Market(
    country: 'DZ',
    nameAr: 'الجزائر',
    currency: 'DZD',
    currencySymbol: 'د.ج',
    flag: '🇩🇿',
  ),
  Market(
    country: 'TR',
    nameAr: 'تركيا',
    currency: 'TRY',
    currencySymbol: '₺',
    flag: '🇹🇷',
  ),
];

/// The market for a stored country code, or null for an unknown or empty one.
Market? marketFor(String? country) {
  final code = (country ?? '').trim().toUpperCase();
  if (code.isEmpty) return null;
  for (final market in kMarkets) {
    if (market.country == code) return market;
  }
  return null;
}

/// Whether [country] names a market this app knows.
///
/// A non-empty code nobody recognises is treated as *no* market: the server's
/// zone lookup would put it on UTC, which is exactly the state the picker
/// exists to get an account out of.
bool isKnownMarket(String? country) => marketFor(country) != null;

/// The markets whose name, currency code or symbol contains [query].
///
/// Nineteen tiles are too many to scan by eye, which is why the Kotlin picker
/// searches, and it searches the same three fields.
List<Market> searchMarkets(String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return kMarkets;
  return kMarkets
      .where(
        (m) =>
            m.nameAr.contains(q) ||
            m.currency.toLowerCase().contains(q) ||
            m.currencySymbol.contains(q),
      )
      .toList();
}
