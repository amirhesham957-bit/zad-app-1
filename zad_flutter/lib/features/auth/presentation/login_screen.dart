/// The way in.
///
/// One screen for three jobs — signing in, signing up, asking for a reset link
/// — because they share every field they have and a person who came to do one
/// of them often turns out to need another.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/design/foundation/squircle.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/auth/application/auth_controller.dart';
import 'package:zad/features/auth/domain/auth_failure.dart';

/// Sign in, sign up, or ask for a reset link.
class LoginScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const new({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _name = TextEditingController();

  bool _obscured = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Close the keyboard first: the button is in the thumb zone and the
    // keyboard is what is covering the error the next frame may need to show.
    FocusScope.of(context).unfocus();
    // Not awaited. The tap's confirmation is feedback, not a precondition —
    // awaiting it puts a platform round trip in front of the customer's
    // sign-in, and in a widget test that channel has nobody to answer it, so
    // the request simply never left.
    unawaited(HapticFeedback.selectionClick());
    await ref
        .read(authControllerProvider.notifier)
        .submit(email: _email.text, password: _password.text, name: _name.text);
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(authControllerProvider);
    final mode = form.mode;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: ZadColors.canvas),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: ZadSpacing.xl,
                vertical: ZadSpacing.xxl,
              ),
              child: ConstrainedBox(
                // A login form stretched across a tablet is a login form nobody
                // can read the width of.
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const _Brand(),
                    const SizedBox(height: ZadSpacing.xxl),

                    Text(_title(mode), style: ZadType.titleLarge),
                    const SizedBox(height: ZadSpacing.xs),
                    Text(
                      _subtitle(mode),
                      style: ZadType.bodySmall.copyWith(
                        color: ZadColors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: ZadSpacing.xl),

                    if (mode == AuthMode.signUp) ...<Widget>[
                      TextField(
                        controller: _name,
                        textInputAction: TextInputAction.next,
                        autofillHints: const <String>[AutofillHints.name],
                        decoration: const InputDecoration(
                          labelText: 'اسمك',
                          hintText: 'اللي هنناديك بيه',
                        ),
                      ),
                      const SizedBox(height: ZadSpacing.md),
                    ],

                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      // The address is Latin even when the app is not.
                      textDirection: TextDirection.ltr,
                      autofillHints: const <String>[AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'الإيميل',
                        hintText: 'you@example.com',
                      ),
                    ),

                    if (mode != AuthMode.resetPassword) ...<Widget>[
                      const SizedBox(height: ZadSpacing.md),
                      TextField(
                        controller: _password,
                        obscureText: _obscured,
                        textInputAction: TextInputAction.done,
                        textDirection: TextDirection.ltr,
                        autofillHints: <String>[
                          if (mode == AuthMode.signUp)
                            AutofillHints.newPassword
                          else
                            AutofillHints.password,
                        ],
                        onSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'كلمة السر',
                          helperText: mode == AuthMode.signUp
                              ? '$kMinPasswordLength حروف على الأقل'
                              : null,
                          suffixIcon: IconButton(
                            // Material's default IconButton is 48dp, which is
                            // already over the 44dp floor. Do not shrink it.
                            onPressed: () =>
                                setState(() => _obscured = !_obscured),
                            icon: Icon(
                              _obscured
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            tooltip: _obscured ? 'اظهر كلمة السر' : 'اخفيها',
                          ),
                        ),
                      ),
                    ],

                    if (form.failure
                        case final AuthFailure failure) ...<Widget>[
                      const SizedBox(height: ZadSpacing.lg),
                      _Banner(
                        icon: Icons.warning,
                        text: failure.message,
                        tint: ZadColors.terracottaRust,
                      ),
                    ],

                    if (form.notice case final String notice) ...<Widget>[
                      const SizedBox(height: ZadSpacing.lg),
                      _Banner(
                        icon: Icons.mark_email_read,
                        text: notice,
                        tint: ZadColors.green600,
                      ),
                    ],

                    const SizedBox(height: ZadSpacing.xl),
                    // Bottom of the form, where the thumb already is.
                    FilledButton(
                      onPressed: form.submitting ? null : _submit,
                      child: form.submitting
                          // A spinner here is honest, unlike the one the add
                          // sheet does not have: this really is a network round
                          // trip and the customer really is waiting on it.
                          ? SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: ZadColors.surface,
                              ),
                            )
                          : Text(_action(mode)),
                    ),

                    const SizedBox(height: ZadSpacing.md),
                    _ModeSwitches(mode: mode),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _title(AuthMode mode) => switch (mode) {
    AuthMode.signIn => 'أهلاً بيك تاني',
    AuthMode.signUp => 'خلّينا نبدأ',
    AuthMode.resetPassword => 'نسيت كلمة السر؟',
  };

  static String _subtitle(AuthMode mode) => switch (mode) {
    AuthMode.signIn => 'ادخل عشان تلاقي فلوسك وحساباتك زي ما سِبتهم.',
    AuthMode.signUp => 'حساب واحد يكفي البيت كله.',
    AuthMode.resetPassword => 'اكتب إيميلك وهنبعتلك لينك تغيّر بيه كلمة السر.',
  };

  static String _action(AuthMode mode) => switch (mode) {
    AuthMode.signIn => 'ادخل',
    AuthMode.signUp => 'اعمل حساب',
    AuthMode.resetPassword => 'ابعت اللينك',
  };
}

/// The wordmark.
class _Brand extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      ZadSquircleClip(
        radius: ZadRadii.hero,
        child: Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: const BoxDecoration(gradient: ZadColors.hero),
          child: const Icon(
            Icons.account_balance_wallet,
            color: ZadColors.mintGlow,
            size: 34,
          ),
        ),
      ),
      const SizedBox(height: ZadSpacing.lg),
      const Text('زاد', style: ZadType.displayMedium),
      const SizedBox(height: ZadSpacing.xs),
      Text(
        'فلوس البيت، واضحة',
        style: ZadType.labelMedium.copyWith(color: ZadColors.inkMuted),
      ),
    ],
  );
}

/// An error or a confirmation, in the same shape so the eye finds both in the
/// same place.
class _Banner extends StatelessWidget {
  const new({required this.icon, required this.text, required this.tint});

  final IconData icon;
  final String text;
  final Color tint;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(ZadSpacing.md),
    decoration: ShapeDecoration(
      color: tint.withValues(alpha: 0.08),
      shape: zadSquircle(
        ZadRadii.chip,
        side: BorderSide(color: tint.withValues(alpha: 0.24)),
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 18, color: tint),
        const SizedBox(width: ZadSpacing.sm),
        Expanded(
          child: Text(text, style: ZadType.bodySmall.copyWith(color: tint)),
        ),
      ],
    ),
  );
}

/// The links between the three modes.
class _ModeSwitches extends ConsumerWidget {
  const new({required this.mode});

  final AuthMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void go(AuthMode to) =>
        ref.read(authControllerProvider.notifier).setMode(to);

    return switch (mode) {
      AuthMode.signIn => Column(
        children: <Widget>[
          TextButton(
            onPressed: () => go(AuthMode.resetPassword),
            child: const Text('نسيت كلمة السر؟'),
          ),
          TextButton(
            onPressed: () => go(AuthMode.signUp),
            child: const Text('لسه معندكش حساب؟ اعمل واحد'),
          ),
        ],
      ),
      AuthMode.signUp => TextButton(
        onPressed: () => go(AuthMode.signIn),
        child: const Text('عندك حساب؟ ادخل بيه'),
      ),
      AuthMode.resetPassword => TextButton(
        onPressed: () => go(AuthMode.signIn),
        child: const Text('ارجع لتسجيل الدخول'),
      ),
    };
  }
}
