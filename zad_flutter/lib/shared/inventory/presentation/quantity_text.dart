/// A pantry amount as the customer reads it.
library;

import 'package:flutter/widgets.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/shared/inventory/domain/quantity.dart';

/// «فاضل قليل» for a fifth of a counted piece, «2 كجم» for a weight: the words
/// the check-in asked with when the number is a part of one piece
/// ([pieceLeft]), the number and unit otherwise.
String quantityText(BuildContext context, num quantity, String? unit) {
  final l = context.l10n;
  return switch (pieceLeft(quantity, unit)) {
    PieceLeft.little => l.qtyLeftLittle,
    PieceLeft.half => l.qtyLeftHalf,
    PieceLeft.most => l.qtyLeftMost,
    null => '${formatQuantity(quantity)} ${unit ?? ''}'.trim(),
  };
}
