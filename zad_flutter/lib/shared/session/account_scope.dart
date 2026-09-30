/// What has to happen across the app when the signed-in account changes —
/// the one global trigger features share.
///
/// The session knows *when* an account ends; the app knows *what* holds that
/// account's data (every feature's controllers, the push token, the on-phone
/// reminders, the kids-mode PIN). `app/wiring/zad_wiring.dart` binds the
/// second to the first here, so the session never imports a feature to reset
/// it and a new feature with account data is registered in one place.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The account-change hooks.
abstract final class AccountScope {
  static void Function(Ref ref)? _forget;
  static Future<void> Function(Ref ref)? _beforeSignOut;
  static Future<void> Function(Ref ref)? _afterSignOut;

  /// Binds the hooks. Called again, it replaces them.
  static void bind({
    required void Function(Ref ref) forgetPreviousAccount,
    required Future<void> Function(Ref ref) beforeSignOut,
    required Future<void> Function(Ref ref) afterSignOut,
  }) {
    _forget = forgetPreviousAccount;
    _beforeSignOut = beforeSignOut;
    _afterSignOut = afterSignOut;
  }

  /// Drops every screen's in-memory copy of the last account's data.
  static void forgetPreviousAccount(Ref ref) => _forget?.call(ref);

  /// Runs while the session can still act as the account (its push token,
  /// its reminders).
  static Future<void> beforeSignOut(Ref ref) async {
    await _beforeSignOut?.call(ref);
  }

  /// Runs after the caches are cleared, whether or not the server was told.
  static Future<void> afterSignOut(Ref ref) async {
    await _afterSignOut?.call(ref);
  }
}
