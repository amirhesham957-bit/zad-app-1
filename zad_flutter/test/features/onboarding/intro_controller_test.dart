// The introduction is shown once per phone, not once per sign-in. The Kotlin
// app forgot it on every sign-out and walked a returning customer through the
// carousel again before they could reach the login form.

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/data/local/boxes.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/features/onboarding/application/intro_controller.dart';

void main() {
  late Directory dir;
  late ZadLocalStore store;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('zad_intro_test');
    Hive.init(dir.path);
    store = await ZadLocalStore.open();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  ProviderContainer fresh() => ProviderContainer(
    overrides: [localStoreProvider.overrideWithValue(store)],
  );

  test('a new phone has not seen it', () {
    final container = fresh();
    addTearDown(container.dispose);
    expect(container.read(introSeenProvider), isFalse);
  });

  test('once seen, it stays seen — through a sign-out', () async {
    final first = fresh();
    first.read(introSeenProvider.notifier).markSeen();
    expect(first.read(introSeenProvider), isTrue);
    first.dispose();
    // markSeen does not wait on the write; the next launch does.
    await pumpEventQueue();

    // What a sign-out does to the device.
    await store.clearCaches();

    final next = fresh();
    addTearDown(next.dispose);
    expect(next.read(introSeenProvider), isTrue);
  });

  test('clearing the caches leaves the device box alone', () async {
    await store.documents.put('budget_state', '{}');
    await store.device.put('intro_seen', 'true');

    await store.clearCaches();

    expect(store.documents.isEmpty, isTrue);
    expect(store.device.get('intro_seen'), 'true');
  });
}
