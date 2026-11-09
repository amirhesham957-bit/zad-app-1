/// How the family screens write money and invite links.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:zad/core/env/zad_env.dart';
import 'package:zad/shared/budget/application/budget_controller.dart';
import 'package:zad/shared/family/domain/family.dart';

/// An amount with the account's currency.
String familyMoney(double v, String currency) =>
    '${NumberFormat('#,##0.##', 'en').format(v)} $currency'.trim();

/// The account's currency symbol, or empty.
String familyCurrency(WidgetRef ref) => ref.watch(
  budgetControllerProvider.select((v) => v.snapshot?.currency ?? ''),
);

// What `zad_create_family` and `zad_join_family` store when no alias is typed.
// l10n: data-begin
const Set<String> _serverDefaultAliases = <String>{
  'رب الأسرة',
  'فرد من العيلة',
};
// l10n: data-end

/// Who the family is named for: `family_groups` has no name, so its admin. The
/// server's default aliases name nobody, so they give null.
String? familyOwnerAlias(Family family) {
  for (final member in family.members) {
    final alias = member.alias.trim();
    if (member.role != FamilyRole.admin || alias.isEmpty) continue;
    if (_serverDefaultAliases.contains(alias)) continue;
    return alias;
  }
  return null;
}

/// The invite link: the bot's redirect, which opens the app on the join
/// dialog (`telegram.ts` `appLinkRedirect`).
String inviteLink(String code) =>
    '${ZadEnv.supabaseUrl}/functions/v1/zad-telegram-bot?open=invite&code=$code';

/// Kotlin's `extractInviteCode`: a pasted link or message becomes its code.
String extractInviteCode(String raw) {
  final fromLink = RegExp(r'code=([A-Za-z0-9\-]+)').firstMatch(raw);
  if (fromLink != null) return fromLink.group(1)!.toUpperCase();
  final code = RegExp('ZAD-[A-Za-z0-9]+', caseSensitive: false).firstMatch(raw);
  return (code?.group(0) ?? raw.trim()).toUpperCase();
}
