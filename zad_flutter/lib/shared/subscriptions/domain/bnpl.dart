/// Buy now, pay later: the instalment companies each market actually has.
///
/// The subscriptions screen offered Tabby and Tamara to everybody and filed
/// them with a car loan under «أقساط». An Egyptian customer pays valU,
/// Sympl or Souhoola, and a four-payment Tabby plan is not a loan — it ends
/// in weeks, and it is the one obligation people forget they took (owner,
/// 2026-09-30). So each market gets its own companies, and a row is known
/// as BNPL by its title or provider.
///
/// The spellings are matched against what the customer or the bank wrote —
/// data, not UI text: never translate them.
library;

import 'package:zad/shared/subscriptions/domain/subscription.dart';

/// One BNPL company.
typedef BnplProvider = ({
  /// What the screen calls it.
  String name,

  /// The stored `provider` value.
  String provider,

  /// Spellings matched against a row's title and provider, lower case.
  List<String> spellings,

  /// ISO country codes where it operates.
  Set<String> markets,
});

/// Every company Zad knows, most widely used first.
const List<BnplProvider> kBnplProviders = <BnplProvider>[
  (
    name: 'تابي',
    provider: 'Tabby',
    spellings: <String>['tabby', 'تابي'],
    markets: <String>{'SA', 'AE', 'KW', 'BH', 'QA', 'OM', 'EG'},
  ),
  (
    name: 'تمارا',
    provider: 'Tamara',
    spellings: <String>['tamara', 'تمارا', 'تماره'],
    markets: <String>{'SA', 'AE', 'KW', 'BH', 'QA', 'OM'},
  ),
  (
    name: 'فاليو',
    provider: 'valU',
    spellings: <String>['valu', 'فاليو', 'ڤاليو'],
    markets: <String>{'EG'},
  ),
  (
    name: 'سيمبل',
    provider: 'Sympl',
    spellings: <String>['sympl', 'سيمبل'],
    markets: <String>{'EG'},
  ),
  (
    name: 'سهولة',
    provider: 'Souhoola',
    spellings: <String>['souhoola', 'سهولة', 'سهوله'],
    markets: <String>{'EG'},
  ),
  (
    name: 'كونتكت',
    provider: 'Contact',
    spellings: <String>['contact now', 'contact credit', 'كونتكت'],
    markets: <String>{'EG'},
  ),
  (
    name: 'أمان',
    provider: 'aman',
    spellings: <String>['aman', 'أمان'],
    markets: <String>{'EG'},
  ),
  (
    name: 'حالاً',
    provider: 'Halan',
    spellings: <String>['halan', 'حالا', 'حالاً'],
    markets: <String>{'EG'},
  ),
  (
    name: 'مدفوع',
    provider: 'Madfu',
    spellings: <String>['madfu', 'مدفوع'],
    markets: <String>{'SA'},
  ),
  (
    name: 'MISpay',
    provider: 'MISpay',
    spellings: <String>['mispay', 'مس باي'],
    markets: <String>{'SA'},
  ),
  (
    name: 'Postpay',
    provider: 'Postpay',
    spellings: <String>['postpay', 'بوست باي'],
    markets: <String>{'AE'},
  ),
  (
    name: 'Cashew',
    provider: 'Cashew',
    spellings: <String>['cashew', 'كاشو'],
    markets: <String>{'AE'},
  ),
  (
    name: 'Taly',
    provider: 'Taly',
    spellings: <String>['taly', 'تالي'],
    markets: <String>{'KW'},
  ),
];

/// The companies offered for [country]; Tabby and Tamara when it is not
/// known, since they cover most of the Gulf.
List<BnplProvider> bnplProvidersFor(String? country) {
  final code = country?.trim().toUpperCase();
  final here = <BnplProvider>[
    for (final p in kBnplProviders)
      if (code != null && p.markets.contains(code)) p,
  ];
  return here.isNotEmpty ? here : kBnplProviders.take(2).toList();
}

/// The BNPL company a row with [title] and [provider] is owed to, or null.
///
/// Whole words only: «أمان» must not match «أمانة جدة», a municipality bill,
/// nor "aman" a name that merely contains it.
BnplProvider? bnplProviderOf(String title, [String? provider]) {
  final words = '$title ${provider ?? ''}'.toLowerCase().replaceAll(
    RegExp(r'[^\p{L}\p{N}]+', unicode: true),
    ' ',
  );
  final haystack = ' $words ';
  for (final p in kBnplProviders) {
    if (p.spellings.any((w) => haystack.contains(' $w '))) return p;
  }
  return null;
}

/// Whether [s] is a buy-now-pay-later instalment.
bool isBnpl(Subscription s) => bnplProviderOf(s.title, s.provider) != null;
