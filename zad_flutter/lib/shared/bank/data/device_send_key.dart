/// The device's send key (ZAD_PLAN ٢.٧ب).
///
/// The headless engine the bank listener starts reads the app's session and
/// never refreshes it (`background_session.dart` says why: refreshing from the
/// background signed the customer out). So an hour after the last open, a
/// card payment waited on the phone until the app was opened again. On
/// 2026-11-04 the owner paid and transferred and nothing reached the server.
///
/// While the app holds a valid session it registers a random 256-bit key for
/// this device. Only the key's SHA-256 goes to the server
/// (`zad_register_device_key`), and zad-brain accepts the key for
/// `notification_ingest` and nothing else, with the account taken from the
/// key's row. The headless engine sends with it, so a payment reaches the
/// server within seconds with no session at all.
library;

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/core/data/providers.dart';

/// Where the raw key lives on the phone.
abstract interface class DeviceKeyVault {
  /// The value under [key], or null.
  Future<String?> read(String key);

  /// Stores [value] under [key].
  Future<void> write(String key, String value);

  /// Removes [key].
  Future<void> delete(String key);
}

/// The Android keystore, through `flutter_secure_storage`. Readable from the
/// headless engine: the plugin needs a context, not an activity.
class SecureDeviceKeyVault implements DeviceKeyVault {
  /// Creates the vault.
  const new();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// The header zad-brain reads the key from (`deviceKey.ts`).
const String kDeviceKeyHeader = 'x-zad-device-key';

/// How often a registered key is registered again. The call is idempotent;
/// repeating it heals a key the server pruned (five per account).
const Duration kDeviceKeyRefreshEvery = Duration(days: 1);

/// SHA-256 hex of [key] — what the server stores and looks up.
String deviceKeyHash(String key) => sha256.convert(utf8.encode(key)).toString();

/// 32 random bytes, base64url without padding (43 characters).
String newDeviceKey([Random? random]) {
  final r = random ?? Random.secure();
  final bytes = List<int>.generate(32, (_) => r.nextInt(256));
  return base64Url.encode(bytes).replaceAll('=', '');
}

/// Registers, reads and forgets this device's key.
class DeviceSendKey {
  /// Creates the store.
  new({
    required DeviceKeyVault vault,
    required Future<void> Function(String keyHash) register,
    required Future<void> Function(String keyHash) revoke,
    required DateTime Function() now,
    Random? random,
  }) : _vault = vault,
       _register = register,
       _revoke = revoke,
       _now = now,
       _random = random;

  final DeviceKeyVault _vault;
  final Future<void> Function(String) _register;
  final Future<void> Function(String) _revoke;
  final DateTime Function() _now;
  final Random? _random;

  static const String _keyName = 'zad_device_send_key';
  static const String _ownerName = 'zad_device_send_key_owner';
  static const String _atName = 'zad_device_send_key_registered_at';

  /// The raw key, if this device has one.
  static Future<String?> stored(DeviceKeyVault vault) async {
    final key = await vault.read(_keyName);
    return key == null || key.isEmpty ? null : key;
  }

  /// Makes sure [userId] has a registered key on this device.
  ///
  /// A key registered for another account is replaced, never reused: it
  /// would send this account's bank messages into that one. Nothing is
  /// stored as registered unless the server said yes. Returns whether a
  /// registration call was made.
  Future<bool> ensureRegistered(String userId) async {
    if (userId.isEmpty) return false;
    var key = await stored(_vault);
    final owner = await _vault.read(_ownerName);
    final at = DateTime.tryParse(await _vault.read(_atName) ?? '');
    final fresh = at != null && _now().difference(at) < kDeviceKeyRefreshEvery;
    if (key != null && owner == userId && fresh) return false;

    if (key == null || owner != userId) {
      key = newDeviceKey(_random);
      // Written first: a key registered and then lost would be a live key
      // nobody holds. One stored and not yet registered is merely unused.
      await _vault.write(_keyName, key);
      await _vault.delete(_ownerName);
      await _vault.delete(_atName);
    }
    await _register(deviceKeyHash(key));
    await _vault.write(_ownerName, userId);
    await _vault.write(_atName, _now().toUtc().toIso8601String());
    return true;
  }

  /// Sign-out: the server drops the key while the session can still ask, and
  /// the phone forgets it either way.
  Future<void> forget() async {
    final key = await stored(_vault);
    if (key == null) return;
    try {
      await _revoke(deviceKeyHash(key));
    } on Object {
      // Offline at sign-out: the key stays on the server, unheld, until the
      // five-per-account pruning drops it.
    }
    await _vault.delete(_keyName);
    await _vault.delete(_ownerName);
    await _vault.delete(_atName);
  }
}

/// Sends one `notification_ingest` body to zad-brain with the device key.
///
/// Throws [FunctionException] on anything but 2xx, so the background
/// delivery's own rule (`isPermanentIngestFailure`) decides what stays in the
/// inbox: a 401 (key unknown) keeps the message for the app's next open.
Future<Object?> sendIngestWithDeviceKey({
  required http.Client client,
  required String supabaseUrl,
  required String anonKey,
  required String deviceKey,
  required Map<String, dynamic> payload,
}) async {
  final response = await client
      .post(
        Uri.parse('$supabaseUrl/functions/v1/zad-brain'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'apikey': anonKey,
          'Authorization': 'Bearer $anonKey',
          kDeviceKeyHeader: deviceKey,
        },
        body: jsonEncode(payload),
      )
      .timeout(const Duration(seconds: 25));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw FunctionException(
      status: response.statusCode,
      details: response.body,
      reasonPhrase: response.reasonPhrase,
    );
  }
  return response.body;
}

/// This device's key, registered through the signed-in session.
final deviceSendKeyProvider = Provider<DeviceSendKey>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return DeviceSendKey(
    vault: const SecureDeviceKeyVault(),
    register: (hash) async {
      final result = await client.rpc<dynamic>(
        'zad_register_device_key',
        params: <String, dynamic>{'p_key_hash': hash},
      );
      if (result is Map && result['ok'] != true) {
        throw StateError('device key refused: ${result['reason']}');
      }
    },
    revoke: (hash) => client.rpc<dynamic>(
      'zad_revoke_device_key',
      params: <String, dynamic>{'p_key_hash': hash},
    ),
    now: ref.read(nowProvider),
  );
});
