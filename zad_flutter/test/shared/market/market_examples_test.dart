// ZAD_PLAN 3.13: a Saudi customer never sees Egypt's examples, and back.
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/l10n/generated/zad_l10n_ar.dart';
import 'package:zad/core/l10n/generated/zad_l10n_en.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/shared/bank/domain/bank_notification.dart';
import 'package:zad/shared/market/domain/market_examples.dart';

final RegExp _egypt = RegExp(
  'جنيه|EGP|إنستاباي|انستاباي|InstaPay|فودافون|كارفور|سبينيز|القاهرة|الجيزة|'
  'مصر|CIB|Cairo|Giza|Carrefour|Spinneys',
);
final RegExp _saudi = RegExp(
  'ريال|SAR|STC|الراجحي|بنده|العثيم|الرياض|جدة|السعودية|'
  'Riyadh|Jeddah|Panda|Othaim',
);

List<String> _shown(String? country) {
  final sample = bankSample(country);
  return <String>[
    for (final ZadL10n l in <ZadL10n>[ZadL10nAr(), ZadL10nEn()]) ...<String>[
      cityExample(l, country),
      storeExample(l, country),
      bankWalletLabel(l, country),
    ],
    testNotificationBody(country),
    if (country == 'SA' || country == 'EG') ...<String>[
      sample.title,
      sample.text,
    ],
  ];
}

void main() {
  test('a Saudi account sees no Egyptian place, shop, wallet or currency', () {
    for (final s in _shown('SA')) {
      expect(_egypt.hasMatch(s), isFalse, reason: s);
    }
  });

  test('an Egyptian account sees nothing Saudi', () {
    for (final s in _shown('EG')) {
      expect(_saudi.hasMatch(s), isFalse, reason: s);
    }
  });

  test('another or unknown market sees neither', () {
    for (final country in <String?>['AE', 'KW', '', null]) {
      for (final s in _shown(country)) {
        expect(_egypt.hasMatch(s), isFalse, reason: '$country: $s');
        expect(_saudi.hasMatch(s), isFalse, reason: '$country: $s');
      }
    }
  });

  test('the country code is read loosely', () {
    expect(ExampleMarket.of(' sa '), ExampleMarket.sa);
    expect(ExampleMarket.of('eg'), ExampleMarket.eg);
    expect(ExampleMarket.of('TR'), ExampleMarket.other);
  });

  test("each market's bank sample is one the listener reads", () {
    // «ريال» and «جنيه» name more than one country, so the parser leaves the
    // currency to the account's own (kAmbiguousCurrencyFamilies) — read, not
    // guessed.
    for (final country in <String>['SA', 'EG']) {
      final sample = bankSample(country);
      final verdict = classifyBankNotification(
        title: sample.title,
        text: sample.text,
      );
      expect(verdict.reason, isNull, reason: country);
      expect(verdict.amount, 250, reason: country);
    }
  });
}
