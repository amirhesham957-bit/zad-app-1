/// Asks for the new password when a reset link opens the app.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/design/components/zad_field_dialog.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/shared/auth/application/auth_controller.dart';
import 'package:zad/shared/auth/data/password_recovery.dart';
import 'package:zad/shared/auth/domain/auth_failure.dart';

/// Wraps [child] and, each time a reset link signs the app in, shows the
/// new-password dialog over whatever is on screen.
///
/// Sits under the app's Navigator (it is the home route's widget, around the
/// auth gate), so the dialog has a route to sit on whichever screen the gate
/// shows.
class PasswordRecoveryListener extends ConsumerStatefulWidget {
  /// Creates the listener.
  const new({required this.child, super.key});

  /// The app below.
  final Widget child;

  @override
  ConsumerState<PasswordRecoveryListener> createState() =>
      _PasswordRecoveryListenerState();
}

class _PasswordRecoveryListenerState
    extends ConsumerState<PasswordRecoveryListener> {
  StreamSubscription<void>? _sub;
  bool _asking = false;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(passwordRecoveryProvider).recoveries.listen((_) {
      if (_asking || !mounted) return;
      unawaited(_ask());
    });
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  Future<void> _ask() async {
    _asking = true;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = context.l10n;
    final changed = await showFieldDialog<bool>(
      context: context,
      initial: const <String>[''],
      builder: (context, fields) => _NewPasswordDialog(field: fields.first),
    );
    _asking = false;
    if (changed == true) {
      messenger?.showSnackBar(
        SnackBar(content: Text(l10n.authNewPasswordDone)),
      );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _NewPasswordDialog extends ConsumerStatefulWidget {
  const new({required this.field});

  final TextEditingController field;

  @override
  ConsumerState<_NewPasswordDialog> createState() => _NewPasswordDialogState();
}

class _NewPasswordDialogState extends ConsumerState<_NewPasswordDialog> {
  AuthFailure? _failure;
  bool _saving = false;

  Future<void> _save() async {
    final password = widget.field.text;
    if (password.length < kMinPasswordLength) {
      setState(
        () => _failure = const AuthFailure(AuthFailureKind.weakPassword),
      );
      return;
    }
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      await ref.read(passwordRecoveryProvider).setNewPassword(password);
      if (mounted) Navigator.of(context).pop(true);
    } on AuthFailure catch (failure) {
      if (mounted) {
        setState(() {
          _saving = false;
          _failure = failure;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final failure = _failure;
    return AlertDialog(
      title: Text(l10n.authNewPasswordTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l10n.authNewPasswordBody),
          const SizedBox(height: 8),
          TextField(
            controller: widget.field,
            obscureText: true,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n.authPassword,
              border: const OutlineInputBorder(),
            ),
          ),
          if (failure != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              failure.localized(l10n),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.commonClose),
        ),
        FilledButton(
          onPressed: _saving ? null : () => unawaited(_save()),
          child: Text(l10n.authNewPasswordSave),
        ),
      ],
    );
  }
}
