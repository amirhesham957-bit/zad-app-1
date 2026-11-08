/// Coming back inside the 14 days after asking to delete the account: the
/// server still holds it, and the customer chooses to restore it or leave.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/shared/auth/application/session_controller.dart';

/// The server's half.
abstract interface class AccountDeletionRemote {
  /// When the account will be purged; null when no deletion is pending.
  Future<DateTime?> pendingPurge();

  /// Cancels the pending deletion.
  Future<bool> cancel();
}

class _SupabaseAccountDeletion implements AccountDeletionRemote {
  const new(this._ref);

  final Ref _ref;

  @override
  Future<DateTime?> pendingPurge() async {
    final raw = await _ref
        .read(supabaseClientProvider)
        .rpc<Object?>('zad_my_account_deletion');
    return raw is String ? DateTime.parse(raw) : null;
  }

  @override
  Future<bool> cancel() async {
    final raw = await _ref
        .read(supabaseClientProvider)
        .rpc<Object?>('zad_cancel_account_deletion');
    return raw == true;
  }
}

/// The account-deletion remote.
final accountDeletionProvider = Provider<AccountDeletionRemote>(
  _SupabaseAccountDeletion.new,
);

/// Whole days left, counting a part-day as a day and never less than one.
int daysUntilPurge(DateTime purgeAt, DateTime now) {
  final hours = purgeAt.difference(now).inHours;
  return hours <= 0 ? 1 : (hours / 24).ceil();
}

/// Asks to restore a pending deletion. An unanswered read asks nothing: a
/// customer with no network must not be stopped at the door.
Future<void> offerAccountRestore(BuildContext context, WidgetRef ref) async {
  final remote = ref.read(accountDeletionProvider);
  final DateTime? purgeAt;
  try {
    purgeAt = await remote.pendingPurge().timeout(const Duration(seconds: 5));
  } on Object {
    return;
  }
  if (purgeAt == null || !context.mounted) return;
  final days = daysUntilPurge(purgeAt, DateTime.now().toUtc());
  final restore = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (c) => AlertDialog(
      title: Text(c.l10n.accountRestoreTitle),
      content: Text(c.l10n.accountRestoreBody(days)),
      actions: <Widget>[
        TextButton(
          key: const ValueKey<String>('account-restore-leave'),
          onPressed: () => Navigator.of(c).pop(false),
          child: Text(c.l10n.accountRestoreLeave),
        ),
        FilledButton(
          key: const ValueKey<String>('account-restore-yes'),
          style: FilledButton.styleFrom(backgroundColor: ZadColors.green700),
          onPressed: () => Navigator.of(c).pop(true),
          child: Text(c.l10n.accountRestoreYes),
        ),
      ],
    ),
  );
  if (restore != true) {
    await ref.read(sessionControllerProvider.notifier).signOut();
    return;
  }
  var restored = false;
  try {
    restored = await remote.cancel();
  } on Object {
    restored = false;
  }
  if (restored || !context.mounted) return;
  ScaffoldMessenger.maybeOf(
    context,
  )?.showSnackBar(SnackBar(content: Text(context.l10n.accountRestoreFailed)));
}
