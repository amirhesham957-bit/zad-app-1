// The headless engines read the app's saved session and never change it
// (ZAD_PLAN ١.٣): a background refresh rotated the token the app was holding,
// and the app's next refresh signed the customer out.

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/shared/auth/data/background_session.dart';

const _url = 'https://auuftqncrjsnyylolhbu.supabase.co';
const _saved = '{"access_token":"a","refresh_token":"r-1"}';

/// The app's storage, as the background sees it.
class _AppStorage extends LocalStorage {
  String? session = _saved;
  int writes = 0;
  int removals = 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async => session != null;

  @override
  Future<String?> accessToken() async => session;

  @override
  Future<void> persistSession(String persistSessionString) async {
    writes++;
    session = persistSessionString;
  }

  @override
  Future<void> removePersistedSession() async {
    removals++;
    session = null;
  }
}

void main() {
  test('uses the key supabase_flutter saves the app’s session under', () {
    expect(
      ReadOnlySessionStorage.sessionKeyFor(_url),
      'sb-auuftqncrjsnyylolhbu-auth-token',
    );
  });

  test('reads the session the app saved', () async {
    final app = _AppStorage();
    final storage = ReadOnlySessionStorage(_url, inner: app);
    await storage.initialize();
    expect(await storage.hasAccessToken(), isTrue);
    expect(await storage.accessToken(), _saved);
  });

  test('never overwrites it, never removes it', () async {
    final app = _AppStorage();
    final storage = ReadOnlySessionStorage(_url, inner: app);
    await storage.persistSession('{"access_token":"b","refresh_token":"r-2"}');
    await storage.removePersistedSession();
    expect(app.writes, 0);
    expect(app.removals, 0);
    expect(app.session, _saved);
  });

  test('the engines start with refresh off and this storage', () {
    final options = backgroundAuthOptions(_url);
    expect(options.autoRefreshToken, isFalse);
    expect(options.detectSessionInUri, isFalse);
    expect(options.localStorage, isA<ReadOnlySessionStorage>());
  });
}
