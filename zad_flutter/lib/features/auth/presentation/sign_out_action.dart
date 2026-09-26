/// The way out.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/auth/application/session_controller.dart';
import 'package:zad/features/auth/domain/auth_failure.dart';

/// Signs out, after asking — and after saying what it would cost.
class SignOutAction extends ConsumerWidget {
  /// Creates the button.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => IconButton(
    icon: const Icon(Icons.exit_to_app),
    tooltip: 'اخرج من الحساب',
    onPressed: () => confirmAndSignOut(context, ref),
  );
}

/// The same thing as a row, for a list of settings.
///
/// Shares [confirmAndSignOut] with [SignOutAction] rather than restating the
/// dialog: the count of unsent writes and the warning built around it are the
/// substance here, and two copies of that would drift.
class SignOutTile extends ConsumerWidget {
  /// Creates the row.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListTile(
    leading: Icon(Icons.exit_to_app, color: ZadColors.terracottaRust),
    title: Text(
      'اخرج من الحساب',
      style: ZadType.titleSmall.copyWith(color: ZadColors.terracottaRust),
    ),
    onTap: () => confirmAndSignOut(context, ref),
  );
}

/// Asks, then signs out.
///
/// Public because two widgets offer it and the question it asks — what this
/// costs in unsent writes — is the part that must not be duplicated.
Future<void> confirmAndSignOut(BuildContext context, WidgetRef ref) async {
  final session = ref.read(sessionControllerProvider.notifier);
  final pending = session.pendingWriteCount;
  final unit = pending == 1 ? 'عملية' : 'عمليات';

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('تخرج من الحساب؟'),
      content: Text(
        pending == 0
            ? 'هنحتاج تدخل تاني عشان توصل لحساباتك.'
            // Said plainly, with the number, because these are rows the
            // customer was already told were saved. They stay on the device
            // — the outbox is not one of the caches a sign-out clears — but
            // they carry this account's id, so the next session's token
            // cannot send them and the server would refuse them outright.
            : 'فيه $pending $unit لسه ما اتبعتش للسيرفر. لو خرجت دلوقتي '
                  'مش هتتبعت. الأحسن تستنى لما النت يرجع.',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('استنى'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('اخرج'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  try {
    await session.signOut();
  } on AuthFailure catch (failure) {
    // The device is signed out regardless — gotrue drops the stored session
    // before it calls the server — so this is a note, not a failure the
    // customer has to do anything about.
    messenger.showSnackBar(SnackBar(content: Text(failure.message)));
  }
}
