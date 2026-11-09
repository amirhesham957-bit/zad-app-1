// Category ceilings moved from one phone to the account (2026-11-09). What
// must hold: a change is queued, not lost; a queued change survives a read of
// the server; and a phone's old ceilings go up once, without undoing the
// account's.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/core/data/sync/outbox.dart';
import 'package:zad/core/data/sync/outbox_entry.dart';
import 'package:zad/shared/budget/data/category_budgets_remote.dart';
import 'package:zad/shared/budget/data/category_budgets_store.dart';

class _FakeRemote implements CategoryBudgetsRemote {
  final Map<String, double> rows = <String, double>{};

  @override
  Future<Map<String, double>> fetchAll({required String userId}) async =>
      <String, double>{...rows};

  @override
  Future<void> upsert({
    required String userId,
    required String category,
    required double amount,
  }) async => rows[category] = amount;

  @override
  Future<void> remove({
    required String userId,
    required String category,
  }) async => rows.remove(category);
}

void main() {
  late Directory dir;
  late Box<String> cache;
  late Outbox outbox;
  late _FakeRemote remote;
  late CategoryBudgetsStore store;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('category_budgets');
    Hive.init(dir.path);
    cache = await Hive.openBox<String>('documents');
    outbox = Outbox(
      box: await Hive.openBox<String>('outbox'),
      send: (_) async {},
    );
    remote = _FakeRemote();
    store = CategoryBudgetsStore(
      cache: cache,
      remote: () => remote,
      outbox: () => outbox,
      userId: () => 'u1',
    );
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  List<OutboxEntry> queued() => outbox.entries(includeDead: false);

  test('a change is cached at once and queued for the account', () async {
    await store.write('الترفيه', 300);
    expect(store.read(), <String, double>{'الترفيه': 300});
    expect(queued().single.id, 'category_budget:الترفيه');
    expect(remote.rows, isEmpty);
  });

  test('a second change replaces an unsent first', () async {
    await store.write('الترفيه', 300);
    await store.write('الترفيه', 500);
    expect(queued().single.payload['amount'], 500);
  });

  test('sending sets the row, and zero removes it', () async {
    await store.write('الترفيه', 300);
    await store.sendQueued(queued().single);
    expect(remote.rows, <String, double>{'الترفيه': 300});
    await store.write('الترفيه', 0);
    await store.sendQueued(queued().last);
    expect(remote.rows, isEmpty);
  });

  test('the server wins over the cache', () async {
    await cache.put('category_budgets_uploaded', '1');
    await cache.put('category_budgets', '{"قديم":10}');
    remote.rows['الأكل'] = 900;
    expect(await store.pull(), <String, double>{'الأكل': 900});
    expect(store.read(), <String, double>{'الأكل': 900});
  });

  test('a queued change survives a read of the server', () async {
    await cache.put('category_budgets_uploaded', '1');
    remote.rows['الترفيه'] = 100;
    remote.rows['الأكل'] = 900;
    await store.write('الترفيه', 300);
    await store.write('الأكل', 0);
    expect(await store.pull(), <String, double>{'الترفيه': 300});
  });

  test(
    'old ceilings on this phone go up once, without undoing the account',
    () async {
      await cache.put('category_budgets', '{"الترفيه":300,"الأكل":50}');
      remote.rows['الأكل'] = 900;
      expect(await store.pull(), <String, double>{
        'الأكل': 900,
        'الترفيه': 300,
      });
      expect(queued().map((e) => e.payload['category']), <String>['الترفيه']);
      for (final e in queued()) {
        await store.sendQueued(e);
        await outbox.discard(e.id);
      }
      await store.pull();
      expect(queued(), isEmpty);
    },
  );

  test('signed out reads the cache and asks nothing', () async {
    final out = CategoryBudgetsStore(
      cache: cache,
      remote: () => throw StateError('no call'),
      outbox: () => outbox,
      userId: () => null,
    );
    await cache.put('category_budgets', '{"الترفيه":300}');
    expect(await out.pull(), <String, double>{'الترفيه': 300});
  });
}
