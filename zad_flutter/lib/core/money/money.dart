/// Money is a `double` rounded to two decimals at every boundary, mirroring the
/// Kotlin app's `Double.asMoney()` in `data/Money.kt`. There is no minor-units
/// migration and there is not going to be one.
library;

/// Two-decimal rounding for money.
extension Money on double {
  /// Rounds to two decimals exactly the way the Kotlin app does.
  ///
  /// Kotlin uses `Math.round(this * 100) / 100.0`, and Java's `Math.round`
  /// is `floor(x + 0.5)` — half rounds **up**, toward positive infinity.
  /// Dart's own `round()` rounds half **away from zero**, so the two
  /// disagree on negative halves: `-0.005` is `0.00` here and in Kotlin,
  /// and `-0.01` under `round()`.
  ///
  /// That matters even though amounts are normally positive, because a
  /// transaction's direction lives in `is_expense` rather than in the
  /// number. A negative amount is a correction, not an impossibility, and
  /// the two clients must not disagree about one.
  double get asMoney => (this * 100 + 0.5).floorToDouble() / 100;
}

/// Reads an amount the user typed.
///
/// Accepts Arabic-Indic digits and the Arabic decimal separator, because an
/// Arabic keyboard produces them and a form that silently rejects "١٢٥٫٥" is a
/// form that does not work in the language the app is written in. Also accepts
/// a comma as the decimal point, which is what most of the region's keyboards
/// put next to the space bar.
///
/// Returns null for anything that is not a positive amount. Zero is null too:
/// a transaction of nothing is not a transaction, and the caller should keep
/// the save button disabled rather than write one.
///
/// Note the bank parser carries its own digit normalisation rather than using
/// this. That one has to match `SaBankParser.kt` character for character and
/// is pinned by parity tests; this one is free to be friendlier to a keyboard.
double? parseMoneyInput(String raw) {
  final buffer = StringBuffer();
  for (final ch in raw.trim().split('')) {
    final mapped = _inputDigits[ch] ?? ch;
    if (mapped == ',') {
      buffer.write('.');
    } else if (RegExp('[0-9.]').hasMatch(mapped)) {
      buffer.write(mapped);
    }
    // Everything else — spaces, currency symbols someone pasted in, stray
    // letters — is dropped rather than failing the parse.
  }

  final value = double.tryParse(buffer.toString());
  if (value == null || value <= 0 || !value.isFinite) return null;
  return value.asMoney;
}

const Map<String, String> _inputDigits = <String, String>{
  '٠': '0',
  '١': '1',
  '٢': '2',
  '٣': '3',
  '٤': '4',
  '٥': '5',
  '٦': '6',
  '٧': '7',
  '٨': '8',
  '٩': '9',
  '۰': '0',
  '۱': '1',
  '۲': '2',
  '۳': '3',
  '۴': '4',
  '۵': '5',
  '۶': '6',
  '۷': '7',
  '۸': '8',
  '۹': '9',
  '٫': '.',
  '،': '.',
};
