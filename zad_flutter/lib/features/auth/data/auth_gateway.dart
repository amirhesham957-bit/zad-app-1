/// The session, and the four things that change it.
///
/// Everything here throws [AuthFailure] and nothing else: the classification
/// happens at this boundary so no caller above it ever has to know what
/// `AuthRetryableFetchException` is.
library;

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/features/auth/domain/auth_failure.dart';

/// What a successful sign-up left behind.
enum SignUpOutcome {
  /// A session. The app can go straight in.
  signedIn,

  /// No session: the project has email confirmation turned on and the account
  /// is waiting on a link.
  ///
  /// Confirmation is **off** on this project — all four existing accounts were
  /// confirmed in the same second they were created (measured 2026-09-20) — so
  /// this branch does not fire today. It exists because that setting lives in
  /// the dashboard, not in this repo: somebody can turn it on this afternoon,
  /// and the failure mode if this were not handled is a sign-up that appears to
  /// succeed and then drops the customer back on the login screen with no
  /// explanation.
  confirmationSent,
}

/// Signing in, out, up, and asking for a reset link.
abstract interface class AuthGateway {
  /// The signed-in account, or null. Synchronous.
  String? get currentUserId;

  /// Emits whenever the session changes, carrying the new account id or null.
  Stream<String?> get userIdChanges;

  /// Signs in with an email and password.
  Future<void> signIn({required String email, required String password});

  /// Creates an account.
  ///
  /// [name] is sent as user metadata rather than written to `zad_users`
  /// afterwards. That is deliberate and it is a fix, not a port: the trigger
  /// `on_auth_user_created_provision_zad_users` reads
  /// `raw_user_meta_data ->> 'name'` as it inserts the row, so the name is
  /// there before this call returns. The Kotlin client instead upserted
  /// `zad_users` *after* `signUp()`, which needs a session to already exist —
  /// and when email confirmation is on, it does not. Migration
  /// `20260815123711_provision_zad_users_row` exists because that left a live
  /// account with no `zad_users` row at all, and every later `UPDATE ... where
  /// id = ?` against it changed nothing while still answering 200.
  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
    required String name,
  });

  /// Sends a password reset link.
  Future<void> sendPasswordReset(String email);

  /// Ends the session.
  Future<void> signOut();
}

/// [AuthGateway] over Supabase.
class SupabaseAuthGateway implements AuthGateway {
  /// Wraps the Supabase client.
  const new(this._client);

  final SupabaseClient _client;

  @override
  String? get currentUserId => _client.auth.currentUser?.id;

  @override
  Stream<String?> get userIdChanges =>
      _client.auth.onAuthStateChange.map((state) => state.session?.user.id);

  @override
  Future<void> signIn({required String email, required String password}) =>
      _guard(
        () => _client.auth.signInWithPassword(email: email, password: password),
      );

  @override
  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    final trimmed = name.trim();
    final response = await _guard(
      () => _client.auth.signUp(
        email: email,
        password: password,
        data: trimmed.isEmpty ? null : <String, dynamic>{'name': trimmed},
      ),
    );

    return response.session == null
        ? SignUpOutcome.confirmationSent
        : SignUpOutcome.signedIn;
  }

  /// No `redirectTo`, matching the Kotlin client.
  ///
  /// A deep link would be better, and it is not invented here: the link has to
  /// be registered in the project's "Redirect URLs" and in the Android
  /// manifest's intent filter, and a `redirectTo` the dashboard does not allow
  /// is rejected outright. Adding it is its own piece of work, in both places
  /// at once.
  @override
  Future<void> sendPasswordReset(String email) =>
      _guard(() => _client.auth.resetPasswordForEmail(email));

  /// Ends the session.
  ///
  /// gotrue clears the stored session **before** it calls the server and
  /// notifies its subscribers there and then, so by the time this throws the
  /// device is already signed out. Whoever calls this must treat the local
  /// sign-out as having happened even on a failure — see
  /// `SessionController.signOut`, which clears the caches in a `finally` for
  /// exactly that reason.
  @override
  Future<void> signOut() => _guard(() => _client.auth.signOut());

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on Object catch (error) {
      throw classifyAuthFailure(error);
    }
  }
}
