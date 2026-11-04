import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/features/bank/data/background_delivery.dart';
import 'package:zad/shared/bank/data/device_send_key.dart';

class _Vault implements DeviceKeyVault {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

void main() {
  late _Vault vault;
  late List<String> registered;
  late List<String> revoked;
  late DateTime now;
  var failRegister = false;
  var seed = 7;

  DeviceSendKey store() => DeviceSendKey(
    vault: vault,
    register: (hash) async {
      if (failRegister) throw Exception('offline');
      registered.add(hash);
    },
    revoke: (hash) async => revoked.add(hash),
    now: () => now,
    random: Random(seed++),
  );

  setUp(() {
    vault = _Vault();
    registered = <String>[];
    revoked = <String>[];
    now = DateTime.utc(2026, 11, 4, 18);
    failRegister = false;
  });

  test('the hash is SHA-256 hex, the same the server computes', () {
    // deviceKey_test.ts pins the same vector on the server side.
    expect(
      deviceKeyHash('abc'),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
  });

  test('a key is 43 base64url characters — the shape the server accepts', () {
    final key = newDeviceKey(Random(1));
    expect(key, hasLength(43));
    expect(RegExp(r'^[A-Za-z0-9_-]{40,128}$').hasMatch(key), isTrue);
    expect(newDeviceKey(Random(2)), isNot(key));
  });

  test(
    'registers once, only the hash leaves the phone, then rests a day',
    () async {
      expect(await store().ensureRegistered('user-a'), isTrue);
      final key = (await DeviceSendKey.stored(vault))!;
      expect(registered, <String>[deviceKeyHash(key)]);
      expect(registered.single, isNot(contains(key)));

      expect(await store().ensureRegistered('user-a'), isFalse);
      now = now.add(const Duration(hours: 25));
      expect(await store().ensureRegistered('user-a'), isTrue);
      // Same key, registered again: the call heals a pruned row.
      expect(await DeviceSendKey.stored(vault), key);
      expect(registered, hasLength(2));
    },
  );

  test(
    'another account on the phone gets a new key, never the old one',
    () async {
      await store().ensureRegistered('user-a');
      final first = await DeviceSendKey.stored(vault);
      await store().ensureRegistered('user-b');
      final second = await DeviceSendKey.stored(vault);
      expect(second, isNot(first));
      expect(registered.last, deviceKeyHash(second!));
    },
  );

  test('a refused registration is not remembered as registered', () async {
    failRegister = true;
    await expectLater(store().ensureRegistered('user-a'), throwsException);
    failRegister = false;
    expect(await store().ensureRegistered('user-a'), isTrue);
    expect(registered, hasLength(1));
  });

  test('sign-out revokes on the server and forgets on the phone', () async {
    await store().ensureRegistered('user-a');
    final key = (await DeviceSendKey.stored(vault))!;
    await store().forget();
    expect(revoked, <String>[deviceKeyHash(key)]);
    expect(await DeviceSendKey.stored(vault), isNull);
    expect(vault.values, isEmpty);
  });

  group('sendIngestWithDeviceKey', () {
    test('posts to zad-brain with the key header and the body as is', () async {
      late http.Request seen;
      final client = MockClient((r) async {
        seen = r;
        return http.Response('{"status":"proposed"}', 200);
      });
      await sendIngestWithDeviceKey(
        client: client,
        supabaseUrl: 'https://p.supabase.co',
        anonKey: 'anon',
        deviceKey: 'k' * 43,
        payload: <String, dynamic>{'action': 'notification_ingest'},
      );
      expect(
        seen.url.toString(),
        'https://p.supabase.co/functions/v1/zad-brain',
      );
      expect(seen.headers[kDeviceKeyHeader], 'k' * 43);
      expect(seen.headers['apikey'], 'anon');
      expect(jsonDecode(seen.body), <String, dynamic>{
        'action': 'notification_ingest',
      });
    });

    test(
      'a 401 (key unknown) keeps the message in the inbox; a 400 does not',
      () async {
        Future<Object> failure(int status) async {
          try {
            await sendIngestWithDeviceKey(
              client: MockClient((_) async => http.Response('', status)),
              supabaseUrl: 'https://p.supabase.co',
              anonKey: 'anon',
              deviceKey: 'k' * 43,
              payload: const <String, dynamic>{},
            );
          } on Object catch (e) {
            return e;
          }
          fail('expected a throw');
        }

        final unauthorized = await failure(401);
        expect(unauthorized, isA<FunctionException>());
        expect(isPermanentIngestFailure(unauthorized), isFalse);
        expect(isPermanentIngestFailure(await failure(400)), isTrue);
        expect(isPermanentIngestFailure(await failure(503)), isFalse);
      },
    );
  });
}
