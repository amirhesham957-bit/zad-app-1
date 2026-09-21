/// Keeps this device's push token on the signed-in account, and off it at
/// sign-out.
///
/// Registering is queued like any other write, so a token handed out while
/// the phone has no signal still reaches the server; it goes through
/// `zad_register_fcm_token`, which moves the token to the caller even when
/// another account left a row for it behind (`20260921170000`).
///
/// Unregistering is two things, because either can fail: the row is deleted
/// while the session is still valid, and the token itself is invalidated at
/// FCM. If the server cannot be reached, the dead token still stops the
/// previous account's alerts arriving on this phone — zad-brain's next push to
/// it gets UNREGISTERED and deletes the row itself.
library;

import 'dart:async';

import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/data/sync/outbox.dart';
import 'package:zad/data/sync/outbox_entry.dart';
import 'package:zad/data/sync/sync_failure.dart';
import 'package:zad/features/alerts/data/push_platform.dart';

/// The server side of the token.
abstract interface class PushTokenRemote {
  /// Registers [token] for the caller; the function's answer.
  Future<Map<String, dynamic>> register(String token);

  /// Deletes the caller's row for [token].
  Future<void> unregister(String token);
}

/// The real function and table.
class SupabasePushTokenRemote implements PushTokenRemote {
  /// Creates a remote over a Supabase client.
  const new(this._client);

  final SupabaseClient _client;

  @override
  Future<Map<String, dynamic>> register(String token) async {
    final result = await _client.rpc<dynamic>(
      'zad_register_fcm_token',
      params: <String, dynamic>{'p_token': token, 'p_platform': 'android'},
    );
    return Map<String, dynamic>.from(result as Map);
  }

  @override
  Future<void> unregister(String token) =>
      _client.from('zad_fcm_tokens').delete().eq('token', token);
}

/// Holds the token's registration.
class PushRegistrar {
  /// Creates a registrar.
  const new({
    required Box<String> device,
    required PushTokenRemote Function() remote,
    required PushPlatform platform,
    required Outbox Function() outbox,
  }) : _device = device,
       _remote = remote,
       _platform = platform,
       _outbox = outbox;

  final Box<String> _device;
  // Read lazily: a sign-out with no token on the device never needs the
  // server, and must not need a client to get there.
  final PushTokenRemote Function() _remote;
  final PushPlatform _platform;
  final Outbox Function() _outbox;

  /// The outbox id: one registration queued at a time.
  static const String outboxId = 'push_token';

  static const String _tokenKey = 'push_token';

  /// The token last handed to the server from this device.
  String? get lastToken => _device.get(_tokenKey);

  /// Queues [token] for the signed-in account.
  Future<void> register(String token) async {
    final t = token.trim();
    if (t.isEmpty) return;
    await _outbox().enqueue(
      id: outboxId,
      kind: OutboxKind.registerPushToken,
      payload: <String, dynamic>{'token': t},
    );
    await _device.put(_tokenKey, t);
  }

  /// Sends a queued registration.
  Future<void> sendQueued(OutboxEntry entry) async {
    final answer = await _remote().register(entry.payload['token'] as String);
    if (answer['ok'] != true) {
      // `invalid_token` is not going to become valid on a retry.
      throw ServerRefusal(
        'zad_register_fcm_token',
        (answer['reason'] as String?) ?? 'refused',
      );
    }
  }

  /// Takes this device off the account. Best effort on the server, certain on
  /// the device; never throws, because a sign-out must not be blocked by it.
  Future<void> unregister() async {
    final token = lastToken;
    // A registration still queued would otherwise go up under whoever signs
    // in next — right account, but only by luck.
    await _outbox().discard(outboxId);
    if (token != null) {
      try {
        await _remote().unregister(token).timeout(const Duration(seconds: 5));
      } on Object {
        // Offline or refused; the token is killed below either way.
      }
    }
    try {
      await _platform.deleteToken().timeout(const Duration(seconds: 5));
    } on Object {
      // Nothing more a phone can do.
    }
    await _device.delete(_tokenKey);
  }
}
