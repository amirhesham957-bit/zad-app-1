/// How the family screens write money and invite links.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:zad/shared/budget/application/budget_controller.dart';

/// An amount with the account's currency.
String familyMoney(double v, String currency) =>
    '${NumberFormat('#,##0.##', 'en').format(v)} $currency'.trim();

/// The account's currency symbol, or empty.
String familyCurrency(WidgetRef ref) => ref.watch(
  budgetControllerProvider.select((v) => v.snapshot?.currency ?? ''),
);

/// The invite deep link.
String inviteLink(String code) => 'zad://invite?code=$code';

/// Kotlin's `extractInviteCode`: a pasted link or message becomes its code.
String extractInviteCode(String raw) {
  final fromLink = RegExp(r'code=([A-Za-z0-9\-]+)').firstMatch(raw);
  if (fromLink != null) return fromLink.group(1)!.toUpperCase();
  final code = RegExp('ZAD-[A-Za-z0-9]+', caseSensitive: false).firstMatch(raw);
  return (code?.group(0) ?? raw.trim()).toUpperCase();
}
