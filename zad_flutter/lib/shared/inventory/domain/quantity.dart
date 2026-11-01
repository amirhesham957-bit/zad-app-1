/// Pantry amounts with fractions (ZAD_PLAN ٣.٨): half a kilo of rice is 0.5,
/// not 1. The server keeps three decimals (`zad_inventory.quantity`
/// numeric(12,3), migration 20261020110000); so does this.
library;

import 'package:zad/shared/inventory/domain/receipt_intake.dart';

/// Reads what the customer typed: `0.5`, `٠٫٥`, `1,5`, `نص`, `ربع`, `1 ونص`.
/// Null for nothing readable or nothing above zero.
double? parseQuantity(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return null;
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  for (var i = 0; i < arabic.length; i++) {
    s = s.replaceAll(arabic[i], '$i');
  }
  s = s.replaceAll('٫', '.').replaceAll(',', '.').replaceAll('،', '.');
  // Words for the halves and quarters people actually say. Matching data,
  // not display text: it stays Arabic.
  const words = <String, double>{
    'ربع': 0.25,
    'تلت': 1 / 3,
    'ثلث': 1 / 3,
    'نص': 0.5,
    'نصف': 0.5,
    'تلتين': 2 / 3,
    'تلت ارباع': 0.75,
    'ثلاثة ارباع': 0.75,
    // What formatQuantity writes, so an edit field it filled reads back.
    '½': 0.5,
    '¼': 0.25,
    '¾': 0.75,
  };
  final m = RegExp(r'^(\d+(?:\.\d+)?)?\s*(?:و\s*)?(.*)$').firstMatch(s);
  final whole = double.tryParse(m?.group(1) ?? '') ?? 0;
  final rest = (m?.group(2) ?? '').replaceAll('أ', 'ا').trim();
  double? part;
  if (rest.isEmpty) {
    part = 0;
  } else {
    part = words[rest];
  }
  if (part == null) return null;
  final q = whole + part;
  if (q <= 0) return null;
  return roundQuantity(q);
}

/// Three decimals, like the server.
double roundQuantity(num q) => (q * 1000).round() / 1000;

/// For display: `2`, `½`, `1½`, `¼`, `0.3`.
String formatQuantity(num q) {
  final r = roundQuantity(q);
  final whole = r.truncate();
  final frac = roundQuantity(r - whole);
  if (frac == 0) return '$whole';
  final glyph = switch (frac) {
    0.5 => '½',
    0.25 => '¼',
    0.75 => '¾',
    _ => null,
  };
  if (glyph != null) return whole == 0 ? glyph : '$whole$glyph';
  final s = r.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '');
  return s.endsWith('.') ? s.substring(0, s.length - 1) : s;
}

/// What is left of one piece, in the words the check-in asked with («كتير /
/// نصه / قليل», `CHECKIN_LEVELS` in the bot). «0.2 قطعة» read as nonsense on
/// the owner's pantry (2026-11-01); it was their own «قليل». Null when the
/// amount is not a part of one counted piece, so weights and whole counts keep
/// their numbers.
enum PieceLeft {
  /// «قليل»: up to about a quarter.
  little,

  /// «نصه»: about half.
  half,

  /// «كتير»: most of it.
  most,
}

/// The [PieceLeft] for [quantity] of [unit], or null.
PieceLeft? pieceLeft(num quantity, String? unit) {
  if (unitKey(unit) != 'piece') return null;
  if (quantity <= 0 || quantity >= 1) return null;
  if (quantity <= 0.3) return PieceLeft.little;
  if (quantity <= 0.6) return PieceLeft.half;
  return PieceLeft.most;
}
