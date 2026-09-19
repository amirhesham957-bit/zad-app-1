/// Mirror of `public.zad_market_timezone(text)` and
/// `public.zad_weekend_dows(text)`, both added by the shared project's
/// migration `20260809120000`.
///
/// These two tables decide when a salary cycle starts. If they drift from the
/// SQL the client and the server will disagree about which period a
/// transaction belongs to, and nothing in the build will say so — change both
/// sides in one commit.
library;

/// The IANA zone each market keeps its books in.
///
/// An unknown or null country falls back to `UTC`, exactly as the SQL `else`
/// branch does. It deliberately does not fall back to the device's own zone: a
/// user's salary cycle should not shift because they are travelling.
const Map<String, String> _marketTimeZones = <String, String>{
  'SA': 'Asia/Riyadh',
  'EG': 'Africa/Cairo',
  'AE': 'Asia/Dubai',
  'KW': 'Asia/Kuwait',
  'QA': 'Asia/Qatar',
  'BH': 'Asia/Bahrain',
  'OM': 'Asia/Muscat',
  'JO': 'Asia/Amman',
  'LB': 'Asia/Beirut',
  'IQ': 'Asia/Baghdad',
  'SY': 'Asia/Damascus',
  'YE': 'Asia/Aden',
  'PS': 'Asia/Gaza',
  'LY': 'Africa/Tripoli',
  'SD': 'Africa/Khartoum',
  'MA': 'Africa/Casablanca',
  'TN': 'Africa/Tunis',
  'DZ': 'Africa/Algiers',
  'TR': 'Europe/Istanbul',
};

/// Markets whose weekend is Saturday and Sunday rather than Friday and
/// Saturday.
const Set<String> _sundayWeekendMarkets = <String>{
  'TR',
  'MA',
  'TN',
  'DZ',
  'LB',
};

/// The IANA zone for [country] (an ISO-3166 alpha-2 code), or `UTC`.
String marketTimeZone(String? country) =>
    _marketTimeZones[(country ?? '').toUpperCase()] ?? 'UTC';

/// The weekend days in [country], in Postgres `extract(dow)` numbering:
/// 0 = Sunday … 6 = Saturday.
Set<int> weekendDows(String? country) =>
    _sundayWeekendMarkets.contains((country ?? '').toUpperCase())
    ? const <int>{6, 0}
    : const <int>{5, 6};

/// [date]'s day of week in Postgres numbering.
///
/// Dart counts 1 = Monday … 7 = Sunday; Postgres counts 0 = Sunday … 6 =
/// Saturday. `% 7` is the whole conversion — it maps Dart's Sunday (7) to 0 and
/// leaves every other day alone.
int pgDayOfWeek(DateTime date) => date.weekday % 7;
