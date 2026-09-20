/// The login form's state machine.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/features/auth/data/auth_gateway.dart';
import 'package:zad/features/auth/domain/auth_failure.dart';

/// Which of the three things the one form is currently doing.
enum AuthMode {
  /// Signing in to an existing account.
  signIn,

  /// Creating one.
  signUp,

  /// Asking for a reset link.
  resetPassword,
}

/// What the form looks like right now.
@immutable
class AuthFormState {
  /// Creates a state.
  const new({
    this.mode = AuthMode.signIn,
    this.submitting = false,
    this.failure,
    this.notice,
  });

  /// What the form is for.
  final AuthMode mode;

  /// Whether a request is in flight. The button is disabled while it is.
  final bool submitting;

  /// The last failure, or null.
  final AuthFailure? failure;

  /// Something that went right and needs saying — a reset link sent, an
  /// account created that is waiting on a confirmation email.
  final String? notice;

  /// A copy with the given changes. [failure] and [notice] are cleared rather
  /// than carried over unless they are passed: an error from the previous
  /// attempt sitting under the button during the next one is a lie about what
  /// just happened.
  ///
  /// [submitting] is **not** in that group — it carries over — so every branch
  /// that finishes a request has to say `submitting: false` itself. The two
  /// that end in a notice rather than a new session both forgot to, and the
  /// button kept its spinner for good; that is what
  /// `login_screen_test.dart`'s reset case pins.
  AuthFormState copyWith({
    AuthMode? mode,
    bool? submitting,
    AuthFailure? failure,
    String? notice,
  }) => AuthFormState(
    mode: mode ?? this.mode,
    submitting: submitting ?? this.submitting,
    failure: failure,
    notice: notice,
  );
}

/// The shortest password this project accepts.
///
/// Measured, not assumed: a 1-character sign-up against this project answers
/// `422 {"error_code":"weak_password", "msg":"Password should be at least 6
/// characters."}` (2026-09-20). Checking it here turns a round trip and a
/// server error into an instant, local sentence.
const int kMinPasswordLength = 6;

/// Drives the login form.
class AuthController extends Notifier<AuthFormState> {
  @override
  AuthFormState build() => const AuthFormState();

  /// Switches between signing in, signing up and asking for a reset link,
  /// dropping whatever the previous mode had to say.
  void setMode(AuthMode mode) => state = AuthFormState(mode: mode);

  /// Runs the current mode.
  ///
  /// Never throws: everything it can go wrong with ends up in
  /// [AuthFormState.failure], which is what the form renders.
  Future<void> submit({
    required String email,
    required String password,
    required String name,
  }) async {
    if (state.submitting) return;

    final address = email.trim();
    final local = _validate(address: address, password: password);
    if (local != null) {
      state = state.copyWith(failure: local);
      return;
    }

    state = state.copyWith(submitting: true);
    final gateway = ref.read(authGatewayProvider);

    try {
      switch (state.mode) {
        case AuthMode.signIn:
          await gateway.signIn(email: address, password: password);
          // No state change on success on purpose. The session stream fires,
          // the gate swaps this whole screen out, and setting `submitting` back
          // to false would only un-disable a button on a widget that is being
          // disposed.
          return;

        case AuthMode.signUp:
          final outcome = await gateway.signUp(
            email: address,
            password: password,
            name: name,
          );
          if (!ref.mounted) return;
          if (outcome == SignUpOutcome.signedIn) return;
          state = state.copyWith(
            submitting: false,
            notice: 'بعتنا لينك تأكيد على $address. افتحه وارجع لنا.',
          );

        case AuthMode.resetPassword:
          await gateway.sendPasswordReset(address);
          if (!ref.mounted) return;
          state = state.copyWith(
            submitting: false,
            mode: AuthMode.signIn,
            notice: 'لو الإيميل ده مسجّل عندنا، هيوصله لينك لتغيير كلمة السر.',
          );
      }
    } on AuthFailure catch (failure) {
      if (!ref.mounted) return;
      state = state.copyWith(submitting: false, failure: failure);
    }
  }

  AuthFailure? _validate({required String address, required String password}) {
    if (!_looksLikeEmail(address)) {
      return const AuthFailure(AuthFailureKind.invalidEmail);
    }
    // A reset needs no password, and demanding one would be a form that
    // refuses to help the person who forgot theirs.
    if (state.mode == AuthMode.resetPassword) return null;
    if (password.length < kMinPasswordLength) {
      return const AuthFailure(AuthFailureKind.weakPassword);
    }
    return null;
  }

  /// Deliberately loose. The server is the authority on what a deliverable
  /// address is; this only catches the typo that is not worth a round trip —
  /// a missing `@`, a missing dot, trailing whitespace.
  static bool _looksLikeEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
}

/// The login form.
final authControllerProvider = NotifierProvider<AuthController, AuthFormState>(
  AuthController.new,
);
