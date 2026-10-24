/// The second half of «نسيت كلمة السر»: the link in the e-mail comes back here.
///
/// Until 2026-10-24 the reset e-mail was sent with no `redirectTo`, so its link
/// opened the project's Site URL and nothing on the phone could set a new
/// password (the owner's report: «فورجت باسورد مش شغال»). The link now opens
/// the app through [kPasswordResetRedirect]; supabase_flutter exchanges it for
/// a session and emits `passwordRecovery`, and the app asks for the new
/// password. The redirect has to be listed in the project's Auth → URL
/// Configuration → Redirect URLs as well, or the server refuses it.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/shared/auth/domain/auth_failure.dart';

/// Where the reset link sends the customer: this app, by its applicationId.
/// The manifest's intent filter claims the same scheme and host.
const String kPasswordResetRedirect =
    'com.aistudio.zad.wrtqvx://reset-password';

/// Recovery links arriving, and the new password going up.
abstract interface class PasswordRecoveryGateway {
  /// One event each time a reset link opened the app and signed it in.
  Stream<void> get recoveries;

  /// Sets the signed-in account's password. Throws [AuthFailure].
  Future<void> setNewPassword(String password);
}

/// [PasswordRecoveryGateway] over Supabase.
class SupabasePasswordRecovery implements PasswordRecoveryGateway {
  /// Wraps the Supabase client.
  const new(this._client);

  final SupabaseClient _client;

  @override
  Stream<void> get recoveries => _client.auth.onAuthStateChange
      .where((state) => state.event == AuthChangeEvent.passwordRecovery)
      .map((_) {});

  @override
  Future<void> setNewPassword(String password) async {
    try {
      await _client.auth.updateUser(UserAttributes(password: password));
    } on Object catch (error) {
      throw classifyAuthFailure(error);
    }
  }
}

/// The recovery gateway.
final passwordRecoveryProvider = Provider<PasswordRecoveryGateway>(
  (ref) => SupabasePasswordRecovery(ref.watch(supabaseClientProvider)),
);
