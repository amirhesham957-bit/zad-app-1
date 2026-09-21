// The token is queued like any write, refused tokens are dropped rather than
// retried, and a sign-out takes this phone off the account even with no
// network — the dead token is what guarantees it.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/data/sync/outbox.dart';
import 'package:zad/data/sync/outbox_entry.dart';
import 'package:zad/data/sync/sync_failure.dart';
import 'package:zad/features/alerts/data/push_platform.dart';
import 'package:zad/features/alerts/data/push_registrar.dart';
import 'package:zad/features/alerts/domain/push_alert.dart';

class _Remote implements PushTokenRemote {
  final List<String> registered = <String>[];
  final List<String> unregistered = <String>[];
  bool offline = false;
  Map<String, dynamic> answer = <String, dynamic>{'ok': true};

  @override
  Future<Map<String, dynamic>> register(String token) async {
    if (offline) throw const SocketException('offline');
    registered.add(token);
    return answer;
  }

  @override
  Future<void> unregister(String token) async {
    if (offline) throw const SocketException('offline');
    unregistered.add(token);
  }
}

class _Platform extends SilentPushPlatform {
  int deletes = 0;

  @override
  Future<void> deleteToken() async => deletes++;

  @override
  Future<void> show(PushAlert alert) async {}
}

const _t1 = 'token-one-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _t2 = 'token-two-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

void main() {
  late Directory dir;
  late Box<String> device;
  late Box<String> outboxBox;
  late _Remote remote;
  late _Platform platform;
  late Outbox outbox;
  late PushRegistrar registrar;
  var run = 0;

  setUp(() async {
    run++;
    dir = await Directory.systemTemp.createTemp('zad_push_test');
    Hive.init(dir.path);
    device = await Hive.openBox<String>('device$run');
    outboxBox = await Hive.openBox<String>('outbox$run');
    remote = _Remote();
    platform = _Platform();
    outbox = Outbox(
      box: outboxBox,
      send: (entry) => switch (entry.kind) {
        OutboxKind.registerPushToken => registrar.sendQueued(entry),
        _ => throw StateError('no sender for ${entry.kind}'),
      },
    );
    registrar = PushRegistrar(
      device: device,
      remote: () => remote,
      platform: platform,
      outbox: () => outbox,
    );
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  test('a token is queued, sent, and remembered', () async {
    await registrar.register(_t1);
    expect(registrar.lastToken, _t1);

    await outbox.flush();
    expect(remote.registered, <String>[_t1]);
    expect(outbox.entries(), isEmpty);
  });

  test(
    'a rotated token replaces the queued one; only the newest goes',
    () async {
      remote.offline = true;
      await registrar.register(_t1);
      await registrar.register(_t2);
      expect(outbox.entries(), hasLength(1));
      expect(outbox.entries().single.payload['token'], _t2);
    },
  );

  test('a token the server refuses is not retried', () async {
    remote.answer = <String, dynamic>{'ok': false, 'reason': 'invalid_token'};
    await registrar.register(_t1);

    final entry = outbox.entries().single;
    await expectLater(
      registrar.sendQueued(entry),
      throwsA(isA<ServerRefusal>()),
    );
  });

  test('sign-out: row deleted, token killed, nothing left queued', () async {
    await registrar.register(_t1);
    await outbox.flush();

    await registrar.unregister();

    expect(remote.unregistered, <String>[_t1]);
    expect(platform.deletes, 1);
    expect(registrar.lastToken, isNull);
  });

  test('sign-out with no network still kills the token', () async {
    remote.offline = true;
    await registrar.register(_t1);

    await registrar.unregister();

    // The row may still be on the server, but the token behind it is dead:
    // zad-brain's next push to it answers UNREGISTERED and deletes it.
    expect(platform.deletes, 1);
    expect(outbox.entries(), isEmpty, reason: 'nothing goes up for the next');
    expect(registrar.lastToken, isNull);
  });
}
