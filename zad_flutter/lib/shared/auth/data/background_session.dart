/// The account, as the headless engines see it: read, never refreshed, never
/// written (ZAD_PLAN ١.٣, 2026-10-19).
///
/// The bank listener and the street alerts each start their own engine and
/// their own Supabase client when an event arrives with the app in the
/// background. Both used to call `refreshSession()` on an expired token.
/// Supabase refresh tokens rotate, so the background spent the token the
/// app's engine — still alive in memory — was holding. On the next return to
/// the app, its auto-refresh sent the old token, the server answered
/// `refresh_token_already_used`, gotrue (2.27.2, `_doRefresh`) found its own
/// session expired, removed it and emitted `signedOut`, and supabase_flutter
/// deleted the persisted session: the customer was at the sign-in screen.
/// The owner's account showed 113 sign-in sessions between 2026-08-10 and
/// 2026-10-18, six of them on 2026-10-12, most living under an hour.
///
/// So a headless engine reads the session the app saved and nothing more:
/// no auto-refresh, no explicit refresh, and a storage that ignores writes
/// and removals. A token still valid is used; an expired one means the event
/// waits where it is (the native inbox, the geofence blob) for the app, which
/// owns the session, to run it on its next open.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads the app's saved session and never changes it.
class ReadOnlySessionStorage extends LocalStorage {
  /// Wraps the app's own storage, under the key supabase_flutter uses for
  /// [supabaseUrl] (`sb-<project ref>-auth-token`).
  new(String supabaseUrl, {LocalStorage? inner})
    : _inner =
          inner ??
          SharedPreferencesLocalStorage(
            persistSessionKey: sessionKeyFor(supabaseUrl),
          );

  final LocalStorage _inner;

  /// supabase_flutter's default key for a project's session.
  static String sessionKeyFor(String supabaseUrl) =>
      'sb-${Uri.parse(supabaseUrl).host.split('.').first}-auth-token';

  @override
  Future<void> initialize() => _inner.initialize();

  @override
  Future<bool> hasAccessToken() => _inner.hasAccessToken();

  @override
  Future<String?> accessToken() => _inner.accessToken();

  /// Ignored: only the app's engine may sign the account out.
  @override
  Future<void> removePersistedSession() async {}

  /// Ignored: only the app's engine may rotate the session.
  @override
  Future<void> persistSession(String persistSessionString) async {}
}

/// The auth options every headless engine starts Supabase with.
FlutterAuthClientOptions backgroundAuthOptions(String supabaseUrl) =>
    FlutterAuthClientOptions(
      // No deep links: there is no activity, and nothing to sign in to.
      detectSessionInUri: false,
      autoRefreshToken: false,
      localStorage: ReadOnlySessionStorage(supabaseUrl),
    );

/// The signed-in client if the saved session is still valid, else null — in
/// which case the caller leaves its work for the app.
SupabaseClient? usableBackgroundClient(SupabaseClient client) {
  final session = client.auth.currentSession;
  if (session == null || session.isExpired) return null;
  return client;
}
