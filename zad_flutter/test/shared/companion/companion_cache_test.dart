import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/core/data/local/screen_cache.dart';
import 'package:zad/shared/auth/application/session_controller.dart';
import 'package:zad/shared/companion/application/companion_controller.dart';
import 'package:zad/shared/companion/data/companion_remote.dart';
import 'package:zad/shared/companion/domain/companion_status.dart';

import 'companion_fakes.dart';

/// A server that cannot be reached.
class _Offline extends FakeCompanionRemote {
  new() : super(statusJson());

  @override
  Future<CompanionStatus?> status() async => throw const SocketException('x');
}

void main() {
  late Directory dir;
  late Box<String> box;
  var run = 0;

  setUp(() async {
    run++;
    dir = await Directory.systemTemp.createTemp('zad_companion_cache');
    Hive.init(dir.path);
    box = await Hive.openBox<String>('docs$run');
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  ProviderContainer open(CompanionRemote remote) {
    final c = ProviderContainer(
      overrides: [
        screenCacheProvider.overrideWithValue(ScreenCache(box)),
        sessionControllerProvider.overrideWith(SignedIn.new),
        companionRemoteProvider.overrideWithValue(remote),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test(
    'offline after one good read: the character, not the classic orb',
    () async {
      final first = open(
        FakeCompanionRemote(statusJson(persona: 'basbous', stage: 2)),
      );
      await first.read(companionProvider.future);
      await Future<void>.delayed(Duration.zero);

      final later = open(_Offline());
      final look = (await later.read(companionProvider.future))?.look;
      expect(look?.persona.id, 'basbous');
      expect(look?.stage.index, 2);
      expect(later.read(companionLookProvider)?.persona.id, 'basbous');
    },
  );

  test('the cached draw first; the server answer replaces it, celebration '
      'and all', () async {
    final seen = FakeCompanionRemote(statusJson(persona: 'basbous', seeds: 10));
    await open(seen).read(companionProvider.future);
    await Future<void>.delayed(Duration.zero);

    final server = FakeCompanionRemote(
      statusJson(
        persona: 'basbous',
        seeds: 99,
        awayHours: 60,
        celebrate: <String, dynamic>{'from_level': 2, 'to_level': 3},
      ),
    );
    final c = open(server);
    final drawn = await c.read(companionProvider.future);
    expect(drawn?.seeds, 10);
    expect(
      drawn?.celebrate,
      isNull,
      reason: 'a cache never replays a celebration',
    );

    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    final fresh = c.read(companionProvider).value;
    expect(fresh?.seeds, 99);
    expect(fresh?.celebrate, isNotNull);
    expect(c.read(companionProvider.notifier).asleep, isTrue);
  });

  test('no cache and no server: the classic orb, as before', () async {
    expect(await open(_Offline()).read(companionProvider.future), isNull);
  });

  test('the cache form reads back to the same status', () {
    final s = CompanionStatus.fromJson(
      statusJson(persona: 'basbous', outfit: 'chef_hat', stage: 1),
    );
    final back = CompanionStatus.fromJson(s.toCacheJson());
    expect(back.persona, s.persona);
    expect(back.outfit, s.outfit);
    expect(back.background, s.background);
    expect(back.stage, s.stage);
    expect(back.seeds, s.seeds);
    expect(back.owned, s.owned);
    expect(back.missions.done, s.missions.done);
    expect(back.week?.days, s.week?.days);
    expect(back.nextStageLevel, s.nextStageLevel);
  });
}
