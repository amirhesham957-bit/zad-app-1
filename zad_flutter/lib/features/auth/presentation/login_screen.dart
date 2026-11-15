/// Kotlin's `LoginScreen` and `SignUpScreen` (`ui/screens/auth/`), on the
/// auth canvas, redone as the approved design: a dark hero with Zado who
/// watches the e-mail and covers his eyes at the password, and a white card
/// over it. Submitting goes through the existing auth controller.
///
/// The sign-up half is `sign_up_view.dart`; the terms are `consent_sheet.dart`.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/design/components/zad_auth_surfaces.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/auth/presentation/auth_form_parts.dart';
import 'package:zad/features/auth/presentation/auth_hero.dart';
import 'package:zad/features/auth/presentation/sign_up_view.dart';
import 'package:zad/shared/auth/application/auth_controller.dart';
import 'package:zad/shared/auth/data/auth_gateway.dart';
import 'package:zad/shared/auth/domain/auth_failure.dart';

/// The way in: Kotlin's two screens, one at a time.
class LoginScreen extends ConsumerWidget {
  /// Creates the screen.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(authControllerProvider.select((f) => f.mode));
    return Scaffold(
      body: ZadAuthBackground(
        child: mode == AuthMode.signUp
            ? const SignUpView()
            : const _SignInView(),
      ),
    );
  }
}

class _SignInView extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_SignInView> createState() => _SignInViewState();
}

class _SignInViewState extends ConsumerState<_SignInView> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  bool _visible = false;
  int _hop = 0;

  @override
  void initState() {
    super.initState();
    _emailFocus.addListener(_refresh);
    _passwordFocus.addListener(_refresh);
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  bool get _canSubmit =>
      _email.text.trim().isNotEmpty && _password.text.trim().isNotEmpty;

  Future<void> _forgot() =>
      showDialog<void>(context: context, builder: (_) => const _ResetDialog());

  void _submit() {
    if (!_canSubmit || ref.read(authControllerProvider).submitting) return;
    setState(() => _hop++);
    unawaited(
      ref
          .read(authControllerProvider.notifier)
          .submit(email: _email.text, password: _password.text, name: ''),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final form = ref.watch(authControllerProvider);
    final covering = _passwordFocus.hasFocus;
    final gaze = _emailFocus.hasFocus
        ? authGazeFor(_email.text.length)
        : Offset.zero;

    return AutofillGroup(
      child: AuthHeroShell(
        zado: AuthZado(gaze: gaze, cover: covering, hop: _hop),
        card: <Widget>[
          Text(
            l.authSignInTitle,
            style: ZadType.titleLarge.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            l.authSignInSubtitle,
            style: ZadType.bodySmall.copyWith(color: scheme.onSurfaceVariant),
          ),
          AuthField(
            label: l.authEmail,
            controller: _email,
            focusNode: _emailFocus,
            onChanged: _refresh,
            keyboard: TextInputType.emailAddress,
            hints: const <String>[AutofillHints.email],
            ltr: true,
          ),
          AuthField(
            label: l.authPassword,
            controller: _password,
            focusNode: _passwordFocus,
            onChanged: _refresh,
            obscure: !_visible,
            action: TextInputAction.done,
            hints: const <String>[AutofillHints.password],
            onSubmitted: _submit,
            suffix: PasswordToggle(
              visible: _visible,
              onPressed: () => setState(() => _visible = !_visible),
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
              onPressed: () => unawaited(_forgot()),
              child: Text(
                l.authForgotPassword,
                style: ZadType.labelLarge.copyWith(
                  color: ZadColors.forestEmerald,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (form.failure case final failure?) AuthErrorText(failure: failure),
          const SizedBox(height: ZadSpacing.sm),
          ZadPrimaryButton(
            text: l.authSignInButton,
            enabled: _canSubmit,
            loading: form.submitting,
            onPressed: _submit,
          ),
          Padding(
            padding: const EdgeInsets.only(top: ZadSpacing.sm),
            child: Text(
              covering ? l.authZadoNotLooking : l.authZadoWatching,
              textAlign: TextAlign.center,
              style: ZadType.labelMedium.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
        footer: AuthSwitchRow(
          question: l.authNoAccount,
          action: l.authSignUpNow,
          onPressed: () => ref
              .read(authControllerProvider.notifier)
              .setMode(AuthMode.signUp),
        ),
      ),
    );
  }
}

class _ResetDialog extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_ResetDialog> createState() => _ResetDialogState();
}

class _ResetDialogState extends ConsumerState<_ResetDialog> {
  final TextEditingController _email = TextEditingController();
  bool _sent = false;
  AuthFailure? _failure;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(context.l10n.authResetTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(context.l10n.authResetBody),
            const SizedBox(height: 8),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: context.l10n.authEmail,
                border: const OutlineInputBorder(),
              ),
            ),
            if (_failure case final failure?) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                failure.localized(context.l10n),
                style: TextStyle(color: scheme.error),
              ),
            ],
            if (_sent) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                context.l10n.authResetSent,
                style: TextStyle(
                  color: scheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.commonClose),
        ),
        FilledButton(
          onPressed: () async {
            try {
              await ref
                  .read(authGatewayProvider)
                  .sendPasswordReset(_email.text.trim());
              if (mounted) {
                setState(() {
                  _sent = true;
                  _failure = null;
                });
              }
            } on AuthFailure catch (failure) {
              // Said here: swallowing it left the customer waiting for an
              // e-mail that was never sent (ZAD_PLAN ٠.١٠).
              if (mounted) {
                setState(() {
                  _sent = false;
                  _failure = failure;
                });
              }
            }
          },
          child: Text(context.l10n.commonSend),
        ),
      ],
    );
  }
}
