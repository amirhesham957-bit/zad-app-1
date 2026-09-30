// A screen draws last time's rows at once: they are kept per screen and per
// account, and a missing store or a broken entry is simply nothing cached.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/core/data/local/screen_cache.dart';

void main() {
  late Directory dir;
  late Box<String> box;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('zad_screen_cache');
    Hive.init(dir.path);
    box = await Hive.openBox<String>('documents');
  });
  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  test('rows come back for the same screen and account only', () async {
    final cache = ScreenCache(box);
    await cache.write('appointments', 'u1', <Map<String, dynamic>>[
      <String, dynamic>{'id': 'a', 'title': 'دكتور'},
    ]);
    expect(cache.read('appointments', 'u1'), <Map<String, dynamic>>[
      <String, dynamic>{'id': 'a', 'title': 'دكتور'},
    ]);
    expect(cache.read('appointments', 'u2'), isNull);
    expect(cache.read('maintenance', 'u1'), isNull);
    expect(cache.read('appointments', null), isNull);
  });

  test('no store, or a broken entry, is nothing cached', () async {
    const none = ScreenCache(null);
    await none.write('x', 'u1', <Map<String, dynamic>>[]);
    expect(none.read('x', 'u1'), isNull);

    await box.put('screen:x:u1', '{not json');
    expect(ScreenCache(box).read('x', 'u1'), isNull);
  });
}
