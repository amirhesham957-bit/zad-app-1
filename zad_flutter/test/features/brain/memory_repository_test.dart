// Every change to what زاد knows is believed only when the server reads back
// changed: a delete RLS quietly ignores, or a profile that did not stick, is
// said as not saved. And the brain's own profile fields survive the form.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/features/brain/data/memory_remote.dart';
import 'package:zad/features/brain/data/memory_repository.dart';
import 'package:zad/features/brain/domain/customer_profile.dart';

class _Remote implements MemoryRemote {
  final List<Map<String, dynamic>> notes = <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'n1',
      'scope': 'spending_pattern',
      'note': 'بيصرف أكتر يوم الخميس',
      'confidence': 0.8,
      'evidence_count': 3,
    },
    <String, dynamic>{
      'id': 'n2',
      'scope': 'general',
      'note': 'عنده بنتين',
      'confidence': 0.6,
      'evidence_count': 1,
    },
  ];

  /// The whole profile row, including columns the form does not own.
  Map<String, dynamic>? profile = <String, dynamic>{
    'preferred_name': 'أمير',
    'work_schedule': 'شيفت ليلي',
  };

  final List<Map<String, dynamic>> visits = <Map<String, dynamic>>[
    <String, dynamic>{
      'returned_at': '2026-09-20T18:00:00Z',
      'spent_total': 120,
      'merchants': <String>['كارفور'],
      'stores': <String>[],
    },
  ];

  bool offline = false;

  /// RLS answering a delete it refuses: 200, nothing changed.
  bool ignoresDeletes = false;

  /// A column the server rewrites on save (a trigger, a constraint default).
  bool rewritesCity = false;

  bool failBehavior = false;

  void _net() {
    if (offline) throw const SocketException('offline');
  }

  @override
  Future<List<Map<String, dynamic>>> fetchNotes({
    required String userId,
    required int limit,
  }) async {
    _net();
    return notes.map((n) => <String, dynamic>{...n}).toList();
  }

  @override
  Future<void> deleteNote(String id) async {
    _net();
    if (!ignoresDeletes) notes.removeWhere((n) => n['id'] == id);
  }

  @override
  Future<bool> noteExists(String id) async => notes.any((n) => n['id'] == id);

  @override
  Future<Map<String, dynamic>?> fetchProfile(String userId) async {
    _net();
    final p = profile;
    return p == null ? null : <String, dynamic>{...p};
  }

  @override
  Future<void> upsertProfile(
    String userId,
    Map<String, dynamic> columns,
  ) async {
    _net();
    // An upsert updates the columns it was given and leaves the rest.
    profile = <String, dynamic>{...?profile, ...columns};
    if (rewritesCity) profile!['city'] = 'القاهرة';
  }

  @override
  Future<Map<String, dynamic>?> fetchBehavior(String userId) async {
    _net();
    if (failBehavior) throw StateError('boom');
    return <String, dynamic>{'avg_weekly_spending': 700};
  }

  @override
  Future<List<Map<String, dynamic>>> fetchVisits({
    required String userId,
    required DateTime since,
  }) async {
    _net();
    return visits.map((v) => <String, dynamic>{...v}).toList();
  }

  @override
  Future<void> deleteVisits(String userId) async {
    _net();
    if (!ignoresDeletes) visits.clear();
  }

  @override
  Future<bool> anyVisits(String userId) async => visits.isNotEmpty;
}

void main() {
  late Directory dir;
  late Box<String> documents;
  late _Remote remote;
  late MemoryRepository repo;
  var run = 0;

  setUp(() async {
    run++;
    dir = await Directory.systemTemp.createTemp('zad_memory_test');
    Hive.init(dir.path);
    documents = await Hive.openBox<String>('documents$run');
    remote = _Remote();
    repo = MemoryRepository(
      cache: documents,
      remote: remote,
      signedInUserId: () => 'user-1',
      now: () => DateTime.utc(2026, 9, 21, 12),
    );
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  test('a refresh caches all four, so the screen opens on them', () async {
    await repo.refresh();
    remote.offline = true;

    final s = repo.cached();
    expect(s.notes.map((n) => n.id), <String>['n1', 'n2']);
    expect(s.profile?.preferredName, 'أمير');
    expect(s.habits.avgWeeklySpending, 700);
    expect(s.habits.outingsCount, 1);
  });

  test('one part failing fails the refresh and keeps the last whole', () async {
    await repo.refresh();
    remote
      ..failBehavior = true
      ..notes.clear();

    await expectLater(repo.refresh(), throwsA(isA<StateError>()));
    expect(repo.cached().notes, hasLength(2));
  });

  test('a forgotten note is gone from the server and the cache', () async {
    await repo.refresh();

    final failure = await repo.forget(repo.cached().notes.first);

    expect(failure, isNull);
    expect(remote.notes.map((n) => n['id']), <String>['n2']);
    expect(repo.cached().notes.map((n) => n.id), <String>['n2']);
  });

  test('a delete the server quietly ignored is not "forgotten"', () async {
    await repo.refresh();
    remote.ignoresDeletes = true;

    final failure = await repo.forget(repo.cached().notes.first);

    expect(failure, MemoryWriteFailure.notSaved);
    expect(repo.cached().notes, hasLength(2));
  });

  test('offline is said as offline, and nothing changes', () async {
    await repo.refresh();
    remote.offline = true;

    expect(
      await repo.forget(repo.cached().notes.first),
      MemoryWriteFailure.offline,
    );
    expect(repo.cached().notes, hasLength(2));
  });

  test("the profile saves, and the brain's own fields survive it", () async {
    await repo.refresh();

    final failure = await repo.saveProfile(
      const CustomerProfile(preferredName: 'أمير', gender: 'male', payDay: 25),
    );

    expect(failure, isNull);
    expect(remote.profile!['gender'], 'male');
    expect(remote.profile!['pay_day'], 25);
    expect(remote.profile!['work_schedule'], 'شيفت ليلي');
    expect(repo.cached().profile?.payDay, 25);
  });

  test('a profile that reads back different is not "saved"', () async {
    await repo.refresh();
    remote.rewritesCity = true;

    final failure = await repo.saveProfile(
      const CustomerProfile(preferredName: 'أمير', city: 'طنطا'),
    );

    expect(failure, MemoryWriteFailure.notSaved);
    expect(repo.cached().profile?.city, isNull);
  });

  test('outings are cleared only when none is left', () async {
    await repo.refresh();

    expect(await repo.clearOutings(), isNull);
    expect(repo.cached().habits.outingsCount, 0);

    remote
      ..visits.add(<String, dynamic>{
        'returned_at': '2026-09-21T09:00:00Z',
        'spent_total': 0,
        'merchants': <String>[],
        'stores': <String>[],
      })
      ..ignoresDeletes = true;
    await repo.refresh();
    expect(await repo.clearOutings(), MemoryWriteFailure.notSaved);
    expect(repo.cached().habits.outingsCount, 1);
  });
}
