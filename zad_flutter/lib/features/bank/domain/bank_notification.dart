/// The gate that decides whether a bank notification reaches zad-brain.
///
/// Ported from `app/src/main/java/com/example/data/SaBankParser.kt`. What is
/// here is the **decision** layer, not the whole parser: noise rejection,
/// amount and currency extraction, the classification, and the gate. The deep
/// merchant/category work (`detectAndParse`, `classify`, `extractMerchant` —
/// the bulk of the Kotlin file's matching data) is not ported and is not
/// needed here, because the server is the writer of record: the Kotlin
/// listener stopped writing transactions locally, and every notification now
/// reaches `zad-brain` with the local parse as a *hint* whose confidence the
/// server compares against 0.9.
///
/// The practical consequence, stated plainly rather than hidden: this client
/// never produces [BankNotificationClass.completedTransaction], so every
/// notification carrying an amount is sent as `ambiguous` with an empty
/// `parsed` object. The server reads a missing confidence as zero, which means
/// "ask the customer" — the safe direction, and the one the Kotlin comments
/// say is already the normal response.
///
/// Why send the ambiguous ones at all: sending only what the local parser
/// solved meant the server — the side with the AI and a real confirmation
/// path — never saw the messages that actually needed intelligence. Those sat
/// in a local outbox and stayed there.
library;

import 'package:zad/core/money/money.dart';
import 'package:zad/features/bank/domain/bank_keywords.dart';

/// What the message is.
enum BankNotificationClass {
  /// Parsed with enough confidence to be a real, settled transaction. This
  /// client never returns it — see the library doc.
  completedTransaction,

  /// An attempt that did not go through, or a debit still conditional on a
  /// balance arriving.
  failedOrPendingTransaction,

  /// Not about a transaction at all — an OTP, an advert, an expiry notice.
  informationalOnly,

  /// Looks financial and carries an amount, but nothing here can say what it
  /// was. The case that most needs the server.
  ambiguous,
}

/// Why a message was set aside, for `zad_rejected_bank_messages`.
enum BankRejectReason {
  /// A one-time code.
  otp,

  /// The transaction failed or was refused.
  declined,

  /// A debit conditional on funds that have not arrived.
  pending,

  /// A card or service has expired.
  expired,

  /// Marketing.
  promo,

  /// It looked financial and nothing could read it. Set by the caller, never
  /// by [bankRejectionReason].
  unparsed,
}

/// The verdict on one notification.
class BankNotificationVerdict {
  /// Creates a verdict.
  const new({
    required this.classification,
    this.amount,
    this.currency,
    this.reason,
  });

  /// What the message is.
  final BankNotificationClass classification;

  /// The transaction amount, when one could be read.
  final double? amount;

  /// The currency named in the text, when it was unambiguous.
  final String? currency;

  /// Why it was set aside, when it was.
  final BankRejectReason? reason;
}

// ─── 1) noise ───────────────────────────────────────────────────────────────

/// Why [text] should be set aside, or null if nothing disqualifies it.
///
/// Order matters and is the Kotlin order: OTP first, then declined, then
/// pending. The conditional-future pair is checked as a **pair** — "سيتم" on
/// its own appears in legitimate deposit confirmations.
BankRejectReason? bankRejectionReason(String text) {
  final t = text.toLowerCase();
  bool has(List<String> keys) => keys.any(t.contains);

  if (has(kOtpKeywords)) return BankRejectReason.otp;
  if (has(kDeclinedKeywords)) return BankRejectReason.declined;
  if (has(kPendingKeywords)) return BankRejectReason.pending;
  if (has(kConditionalFutureMarkers) && has(kConditionOnBalanceMarkers)) {
    return BankRejectReason.pending;
  }
  if (has(kExpiredKeywords)) return BankRejectReason.expired;
  if (has(kPromoKeywords)) return BankRejectReason.promo;
  return null;
}

/// Whether [text] is noise.
bool isBankNoise(String text) => bankRejectionReason(text) != null;

// ─── 2) does it talk about money at all ─────────────────────────────────────

String _escape(String s) =>
    s.replaceAllMapped(RegExp(r'[.*+?^${}()|[\]\\]'), (m) => '\\${m[0]}');

/// Currency tokens with the asymmetric word boundaries the Kotlin uses:
/// Latin bounded both sides, Arabic bounded on the right only (Arabic glues
/// prefixes on — "بالريال", "للجنيه"), symbols unbounded because they are not
/// letters.
final RegExp _currencyTokenRegex = RegExp(
  kCurrencyTokens
      .map((t) {
        final q = _escape(t);
        final arabic = t.runes.any((r) => r >= 0x0600 && r <= 0x06FF);
        final lettered = t.runes.any(
          (r) =>
              RegExp(r'\p{L}', unicode: true).hasMatch(String.fromCharCode(r)),
        );
        if (!lettered) return q;
        if (arabic) return '$q(?!\\p{L})';
        return '(?<!\\p{L})$q(?!\\p{L})';
      })
      .join('|'),
  caseSensitive: false,
  unicode: true,
);

/// Whether the notification is talking about money — the first gate. The
/// second is whether an actual amount can be read.
bool mentionsMoney(String text) {
  final lower = text.toLowerCase();
  return kMoneyPhrases.any(lower.contains) ||
      _currencyTokenRegex.hasMatch(text);
}

// ─── 3) the amount ──────────────────────────────────────────────────────────

/// Arabic-Indic digits to Latin, and the Arabic decimal separator to a dot.
String normalizeDigits(String text) {
  final buffer = StringBuffer();
  for (final ch in text.split('')) {
    buffer.write(kArabicIndicDigits[ch] ?? ch);
  }
  return buffer.toString();
}

/// Resolves the comma/dot ambiguity between Western (1,234.56 — comma groups
/// thousands) and Turkish/European (1.234,56 — comma is the decimal point).
///
/// With both present, whichever is rightmost is the decimal mark. With one
/// comma followed by exactly two digits, it is far more likely decimal.
double? normalizeNumber(String raw) {
  final hasComma = raw.contains(',');
  final hasDot = raw.contains('.');
  String normalized;
  if (hasComma && hasDot) {
    normalized = raw.lastIndexOf(',') > raw.lastIndexOf('.')
        ? raw.replaceAll('.', '').replaceAll(',', '.')
        : raw.replaceAll(',', '');
  } else if (hasComma) {
    normalized = raw.split(',').last.length == 2
        ? raw.replaceAll(',', '.')
        : raw.replaceAll(',', '');
  } else {
    normalized = raw;
  }
  final parsed = double.tryParse(normalized);
  return parsed?.asMoney;
}

const String _num =
    r'(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?|\d{1,3}(?:\.\d{3})*(?:,\d{1,2})?|\d+(?:[.,]\d{1,2})?)';

const String _curLatin =
    'SAR|SR|TRY|TL|EGP|AED|KWD|QAR|BHD|OMR|JOD|LBP|IQD|SYP|YER|ILS|NIS|'
    'LYD|SDG|MAD|TND|DZD|USD|EUR|GBP';
const String _curAr =
    r'ر\.س|رس|ريال|ج\.?م|جنيه|د\.إ|د\.ك|ر\.ق|د\.ب|ر\.ع|د\.أ|ل\.ل|د\.ع|ل\.س|'
    r'ر\.ي|د\.ل|ج\.س|د\.م|د\.ت|د\.ج|دينار|درهم|دولار|يورو';
const String _curSym = r'₺|₪|€|£|\$';
const String _cur =
    r'(?:(?<!\p{L})(?:'
    '$_curLatin'
    r')(?!\p{L})|(?:'
    '$_curAr'
    r')(?!\p{L})|(?:'
    '$_curSym'
    '))';

RegExp _re(String pattern) =>
    RegExp(pattern, caseSensitive: false, unicode: true);

/// An amount named outright — highest priority.
final RegExp _labeledAmount = _re(
  '(?:بمبلغ|مبلغ|بقيمة|قيمة|القيمة|amount)\\s*:?\\s*$_cur?\\s*$_num\\s*$_cur?',
);
final RegExp _amountThenCur = _re('$_num\\s*$_cur');
final RegExp _curThenAmount = _re('$_cur\\s*$_num');

/// Any number tied to the balance — excluded from the amount.
final RegExp _balanceContext = _re(
  '(?:الرصيد|رصيدك|رصيد|المتاح|المتبقي|balance|available)'
  '\\s*(?:المتاح|الحالي)?\\s*:?\\s*$_cur?\\s*$_num',
);

/// The card's last digits — not an amount.
final RegExp _cardMaskContext = _re(
  r'(?:\*{1,4}|[xX*]{2,6}|بطاقة\s*(?:رقم\s*)?(?:تنتهي|منتهية)\s*ب\S*|'
  r'card\s*(?:no\.?|number)?\s*ending(?:\s*(?:in|with))?)\s*'
  '$_num',
);

double? _firstNumberIn(RegExpMatch m) {
  for (var i = 1; i <= m.groupCount; i++) {
    final g = m.group(i);
    if (g != null && g.trim().isNotEmpty) return normalizeNumber(g);
  }
  return null;
}

/// The transaction's amount — not the balance.
///
/// 1. "بمبلغ X" wins outright.
/// 2. Otherwise the smallest amount that sits next to a currency and is not
///    inside a balance or a card-mask phrase. Smallest, because when a message
///    carries two figures the larger is almost always the remaining balance.
double? extractAmount(String rawText) {
  final text = normalizeDigits(rawText);

  final labeled = _labeledAmount.firstMatch(text);
  if (labeled != null) {
    final value = _firstNumberIn(labeled);
    if (value != null && value > 0) return value;
  }

  bool insideAny(Iterable<RegExpMatch> ranges, int at) =>
      ranges.any((r) => r.start <= at && at <= r.end - 1);

  final balances = _balanceContext.allMatches(text).toList();
  final cardMasks = _cardMaskContext.allMatches(text).toList();

  final candidates = <double>[
    for (final m in <RegExpMatch>[
      ..._amountThenCur.allMatches(text),
      ..._curThenAmount.allMatches(text),
    ])
      if (!insideAny(balances, m.start) && !insideAny(cardMasks, m.start))
        ?_firstNumberIn(m),
  ].where((v) => v > 0).toList();

  if (candidates.isEmpty) return null;
  return candidates.reduce((a, b) => a < b ? a : b);
}

/// The currency actually named in the text, or null.
///
/// Null when no symbol appears, or when the only one is an ambiguous word
/// ("دينار") that does not match [marketCurrency]. The caller falls back to
/// the account's own currency in both cases — a message from an Egyptian bank
/// read while travelling must not be recorded in riyals just because that is
/// the market the app is set to.
String? extractCurrency(String rawText, {String? marketCurrency}) {
  final text = normalizeDigits(rawText).toLowerCase();

  for (final entry in kUnambiguousCurrencyTokens.entries) {
    if (_tokenAppears(text, entry.key)) return entry.value;
  }

  for (final family in kAmbiguousCurrencyFamilies.entries) {
    if (!_tokenAppears(text, family.key)) continue;
    if (marketCurrency != null && family.value.contains(marketCurrency)) {
      return marketCurrency;
    }
    return null;
  }

  return null;
}

bool _tokenAppears(String lowerText, String token) {
  final q = _escape(token);
  final arabic = token.runes.any((r) => r >= 0x0600 && r <= 0x06FF);
  final lettered = token.runes.any(
    (r) => RegExp(r'\p{L}', unicode: true).hasMatch(String.fromCharCode(r)),
  );
  final pattern = !lettered
      ? q
      : arabic
      ? '$q(?!\\p{L})'
      : '(?<!\\p{L})$q(?!\\p{L})';
  return _re(pattern).hasMatch(lowerText);
}

// ─── 4) the classification, and the gate ────────────────────────────────────

/// Classifies one notification.
BankNotificationVerdict classifyBankNotification({
  required String title,
  required String text,
  String? marketCurrency,
}) {
  final full = '$title $text'.trim();

  final reason = bankRejectionReason(full);
  if (reason != null) {
    return BankNotificationVerdict(
      classification:
          reason == BankRejectReason.pending ||
              reason == BankRejectReason.declined
          ? BankNotificationClass.failedOrPendingTransaction
          : BankNotificationClass.informationalOnly,
      reason: reason,
    );
  }

  final amount = extractAmount(full);
  return BankNotificationVerdict(
    classification: amount == null
        ? BankNotificationClass.informationalOnly
        : BankNotificationClass.ambiguous,
    amount: amount,
    currency: amount == null
        ? null
        : extractCurrency(full, marketCurrency: marketCurrency),
  );
}

/// Whether this verdict should be sent to zad-brain.
///
/// [isTrackedFinancialApp] is what lets a message with no amount through: a
/// named banking app saying something unrecognised is worth the server's
/// attention, an unknown app saying the same is not.
///
/// Note that `completedTransaction` returns false here in the Kotlin too — it
/// has its own call afterwards. This client never produces it.
bool shouldSendToBrain({
  required BankNotificationClass classification,
  required BankRejectReason? reason,
  required bool isTrackedFinancialApp,
}) => switch (classification) {
  BankNotificationClass.completedTransaction => false,
  BankNotificationClass.ambiguous => true,
  BankNotificationClass.failedOrPendingTransaction => true,
  BankNotificationClass.informationalOnly =>
    reason == null && isTrackedFinancialApp,
};
